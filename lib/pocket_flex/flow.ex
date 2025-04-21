defmodule PocketFlex.Flow do
  @moduledoc """
  Manages the execution of connected nodes.

  A flow maintains a graph of connected nodes and handles the execution
  of those nodes in sequence, passing data between them using a shared state.
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
  Runs the flow with the given shared state.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run(t(), map()) :: {:ok, map()} | {:error, term()}
  def run(flow, shared) do
    run_flow(flow, flow.start_node, shared, flow.params)
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

    case get_in(flow.connections, [current_node, action]) do
      nil ->
        if map_size(get_in(flow.connections, [current_node]) || %{}) > 0 do
          require Logger

          Logger.warning(
            "Flow ends: '#{action}' not found in #{inspect(Map.keys(get_in(flow.connections, [current_node])))}"
          )
        end

        nil

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
