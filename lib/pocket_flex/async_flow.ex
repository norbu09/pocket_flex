defmodule PocketFlex.AsyncFlow do
  @moduledoc """
  Manages the asynchronous execution of connected nodes.

  Extends the basic Flow module with support for asynchronous
  execution using Elixir processes.
  """

  require Logger

  @doc """
  Runs the flow asynchronously with the given shared state.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to:
    - {:ok, final_shared_state}
    - {:error, reason}
  """
  @spec run_async(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async(flow, shared) do
    Task.async(fn -> PocketFlex.Flow.run(flow, shared) end)
  end

  @doc """
  Orchestrates the asynchronous execution of a flow with async nodes.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec orchestrate_async(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  def orchestrate_async(flow, shared) do
    orchestrate_async_flow(flow, flow.start_node, shared, flow.params)
  end

  @doc false
  defp orchestrate_async_flow(_flow, nil, shared, _params), do: {:ok, shared}

  defp orchestrate_async_flow(flow, current_node, shared, params) do
    # Set node params if the node supports it
    current_node =
      if function_exported?(current_node, :set_params, 1) do
        current_node.set_params(params)
        current_node
      else
        current_node
      end

    try do
      # Run the node asynchronously if it's an AsyncNode, otherwise run it synchronously
      result =
        if function_exported?(current_node, :run_async, 1) do
          Logger.debug("Running async node: #{inspect(current_node)}")

          current_node.run_async(shared)
          |> Task.await(:infinity)
        else
          Logger.debug("Running sync node in async flow: #{inspect(current_node)}")
          PocketFlex.NodeRunner.run_node(current_node, shared)
        end

      case result do
        {:ok, action, updated_shared} ->
          # Find next node
          next_node = get_next_node(flow, current_node, action)

          # Continue flow
          orchestrate_async_flow(flow, next_node, updated_shared, params)

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error in async flow: #{inspect(e)}")
        {:error, e}
    end
  end

  # Helper function to get the next node in the flow
  defp get_next_node(flow, current_node, action) do
    action = action || "default"

    case get_in(flow.connections, [current_node, action]) do
      nil ->
        if map_size(get_in(flow.connections, [current_node]) || %{}) > 0 do
          Logger.warning(
            "Flow ends: '#{action}' not found in #{inspect(Map.keys(get_in(flow.connections, [current_node])))}"
          )
        end

        nil

      next_node ->
        next_node
    end
  end

  @doc """
  Creates a new async flow.

  ## Returns
    A new async flow struct
  """
  @spec new() :: PocketFlex.Flow.t()
  def new do
    PocketFlex.Flow.new()
  end

  @doc """
  Adds a node to the async flow.

  ## Parameters
    - flow: The flow to add the node to
    - node: The node module to add
    
  ## Returns
    The updated flow
  """
  @spec add_node(PocketFlex.Flow.t(), module()) :: PocketFlex.Flow.t()
  def add_node(flow, node) do
    PocketFlex.Flow.add_node(flow, node)
  end

  @doc """
  Connects two nodes in the async flow.

  ## Parameters
    - flow: The flow to update
    - from: The source node module
    - to: The target node module
    - action: The action key for this connection (default: "default")
    
  ## Returns
    The updated flow
  """
  @spec connect(PocketFlex.Flow.t(), module(), module(), String.t()) :: PocketFlex.Flow.t()
  def connect(flow, from, to, action \\ "default") do
    PocketFlex.Flow.connect(flow, from, to, action)
  end

  @doc """
  Sets the starting node for the async flow.

  ## Parameters
    - flow: The flow to update
    - node: The node module to set as the start node
    
  ## Returns
    The updated flow
  """
  @spec start(PocketFlex.Flow.t(), module()) :: PocketFlex.Flow.t()
  def start(flow, node) do
    PocketFlex.Flow.start(flow, node)
  end
end
