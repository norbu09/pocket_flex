defmodule PocketFlex.Flow do
  @moduledoc """
  Defines and manages flows of connected nodes in PocketFlex.

  This module provides the core structure and execution logic for flows,
  including state management, node execution, and error handling.

  ## Conventions

  - All flow operations must use tuple-based error handling: `{:ok, ...}` or `{:error, ...}`
  - Actions must always be atoms (e.g., `:default`, `:success`, `:error`)
  - Never overwrite the shared state with a raw value

  ## Best Practices

  - Use pattern matching in function heads
  - Document all public functions and modules
  - Use with statements for clean sequential operations that may fail
  - See the guides for flow design, error handling, and migration notes
  """

  defstruct [:start_node, :last_connection, nodes: %{}, connections: %{}, params: %{}]

  @type t :: %__MODULE__{
          start_node: module(),
          last_connection: {module(), module(), atom()} | nil,
          nodes: %{optional(module()) => struct()},
          connections: %{optional(module()) => %{optional(atom()) => module()}},
          params: map()
        }

  @doc """
  Creates a new flow.

  ## Returns
    A new flow struct
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Adds a node to the flow.

  ## Parameters
    - flow: The flow to add the node to
    - node: The node module to add
    
  ## Returns
    The updated flow
  """
  @spec add_node(t(), module()) :: t()
  def add_node(flow, node) do
    %{flow | nodes: Map.put(flow.nodes, node, %{})}
  end

  @doc """
  Connects two nodes in the flow.

  ## Parameters
    - flow: The flow to update
    - from: The source node module
    - to: The target node module
    - action: The action key for this connection (default: :default)
    
  ## Returns
    The updated flow
  """
  @spec connect(t(), module(), module(), atom()) :: t()
  def connect(flow, from, to, action \\ :default) do
    connections =
      Map.update(
        flow.connections,
        from,
        %{action => to},
        &Map.put(&1, action, to)
      )

    %{flow | connections: connections, last_connection: {from, to, action}}
  end

  @doc """
  Sets the starting node for the flow.

  ## Parameters
    - flow: The flow to update
    - node: The node module to set as the start node
    
  ## Returns
    The updated flow
  """
  @spec start(t(), module()) :: t()
  def start(flow, node) do
    %{flow | start_node: node}
  end

  @doc """
  Executes the flow with the given shared state.

  ## Parameters
    - flow: The flow to execute
    - shared: The initial shared state
    
  ## Returns
    - `{:ok, final_state}` on success
    - `{:error, reason}` on failure

  ## Example

      iex> PocketFlex.Flow.run(flow, %{})
      {:ok, %{}}
  """
  @spec run(t(), map()) :: {:ok, map()} | {:error, term()}
  def run(flow, shared) do
    flow_id = Map.get(shared, :flow_id, "flow_#{System.unique_integer([:positive])}")
    PocketFlex.Telemetry.span([:pocket_flex, :flow], %{flow_id: flow_id, flow_name: Map.get(flow, :name), initial_state: shared}, fn ->
      run_flow(flow, flow.start_node, shared, flow.params)
    end)
    |> case do
      {:ok, {:ok, final_state}} -> {:ok, final_state}
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Runs the flow starting from a specific node with the given shared state.

  ## Parameters
    - flow: The flow to run
    - node: The node to start from
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run_from_node(t(), module(), map()) :: {:ok, map()} | {:error, term()}
  def run_from_node(flow, node, shared) do
    run_flow(flow, node, shared, flow.params)
  end

  @doc """
  Gets the next node in the flow based on the current node and action.

  ## Parameters
    - flow: The flow to check
    - current_node: The current node module
    - action: The action key to follow
    
  ## Returns
    The next node module or nil if no connection exists for the action
  """
  @spec get_next_node(t(), module(), atom()) :: module() | nil
  def get_next_node(flow, current_node, action) do
    action = action || :default

    # Convert string action to atom if needed for backward compatibility
    action = if is_binary(action), do: String.to_atom(action), else: action

    # Get connections for the current node
    node_conns = get_in(flow.connections, [current_node]) || %{}

    # Try specific action, fallback to default if not found
    case Map.get(node_conns, action) do
      nil ->
        case Map.get(node_conns, :default) do
          nil ->
            if map_size(node_conns) > 0 do
              require Logger

              Logger.warning(
                "Flow ends: '#{action}' not found in #{inspect(Map.keys(node_conns))}"
              )
            end

            nil

          next_node ->
            next_node
        end

      next_node ->
        next_node
    end
  end

  @doc false
  defp run_flow(_flow, nil, shared, _params), do: {:ok, shared}

  defp run_flow(flow, current_node, shared, params) do
    # Set node params if the node supports it
    current_node =
      if function_exported?(current_node, :set_params, 1) do
        current_node.set_params(params)
        current_node
      else
        current_node
      end

    case PocketFlex.NodeRunner.run_node(current_node, shared) do
      {:ok, action, updated_shared} ->
        # Find next node
        next_node = get_next_node(flow, current_node, action)

        # Continue flow
        run_flow(flow, next_node, updated_shared, params)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
