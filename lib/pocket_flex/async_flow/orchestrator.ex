defmodule PocketFlex.AsyncFlow.Orchestrator do
  @moduledoc """
  Orchestrates the execution of asynchronous flows in PocketFlex.

  This module manages the flow of execution between nodes in an asynchronous flow,
  handling state transitions, error recovery, and monitoring.

  ## Conventions

  - All node and flow operations must use tuple-based error handling: `{:ok, ...}` or `{:error, ...}`
  - Actions must always be atoms (e.g., `:default`, `:success`, `:error`)
  - Never overwrite the shared state with a raw value

  ## Best Practices

  - Use pattern matching in function heads
  - Document all public functions and modules
  - See the guides for error handling, monitoring, and migration notes
  """

  require Logger
  alias PocketFlex.ErrorHandler
  alias PocketFlex.AsyncFlow.Executor

  @doc """
  Orchestrates the asynchronous execution of a flow.

  ## Parameters
    - flow: The flow to orchestrate
    - current_node: The current node to execute
    - state: The current state
    - params: Flow parameters
    - flow_id: The ID of the flow being executed
    
  ## Returns
    A tuple containing either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec orchestrate(PocketFlex.Flow.t(), module() | nil, map(), map(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def orchestrate(_flow, nil, state, _params, _flow_id), do: {:ok, state}

  def orchestrate(flow, current_node, state, params, flow_id) do
    # Set node params if the node supports it
    current_node =
      if function_exported?(current_node, :set_params, 1) do
        current_node.set_params(params)
        current_node
      else
        current_node
      end

    # Update monitoring with current node
    ErrorHandler.update_monitoring(flow_id, current_node, :processing, %{
      timestamp: DateTime.utc_now()
    })

    # Execute the node
    result = Executor.execute_node(current_node, state, flow_id)

    case result do
      {:ok, action, updated_state} ->
        # Find next node
        next_node = get_next_node(flow, current_node, action)

        # Continue flow
        orchestrate(flow, next_node, updated_state, params, flow_id)

      {:error, _reason} = error ->
        error
    end
  rescue
    error ->
      Executor.handle_node_error(error, current_node, flow_id)
  end

  @doc """
  Gets the next node in the flow based on the current node and action.

  ## Parameters
    - flow: The flow
    - current_node: The current node
    - action: The action to follow
    
  ## Returns
    The next node or nil if there is no next node
  """
  @spec get_next_node(PocketFlex.Flow.t(), module(), atom()) :: module() | nil
  def get_next_node(flow, current_node, action) do
    # Look up the next node in the flow's connections
    case flow.connections do
      %{^current_node => %{^action => next_node}} ->
        next_node

      %{^current_node => %{:default => next_node}} ->
        next_node

      _ ->
        # If no specific connection is found, check for a default action
        case Map.get(flow.connections, current_node) do
          %{:default => next_node} -> next_node
          _ -> nil
        end
    end
  end
end
