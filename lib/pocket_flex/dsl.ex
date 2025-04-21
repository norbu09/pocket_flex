defmodule PocketFlex.DSL do
  @moduledoc """
  Provides a domain-specific language for connecting nodes.

  This module defines operators and functions that make it
  easier to create and connect nodes in a flow.

  ## Examples

  ```elixir
  # Basic connection with default action
  flow = NodeA >>> NodeB

  # Connection with specific action
  flow = NodeA ~> :success ~> NodeB

  # Conditional connections
  flow = NodeA
         |> on(:success, NodeB)
         |> on(:error, ErrorHandlerNode)
         
  # Chaining connections
  flow = NodeA >>> NodeB >>> NodeC

  # Branching connections
  flow = NodeA
         |> branch(:success, NodeB)
         |> branch(:error, ErrorHandlerNode)
  ```
  """

  defmacro __using__(_opts) do
    quote do
      import PocketFlex.DSL
      alias PocketFlex.{Flow, Node}
    end
  end

  @doc """
  Connects two nodes with a default action.

  ## Parameters
    - left: The source node module
    - right: The target node module
    
  ## Returns
    A tuple representing the connection
    
  ## Examples

  ```elixir
  flow = NodeA >>> NodeB
  ```
  """
  def left >>> right when is_atom(left) and is_atom(right) do
    {left, right, :default}
  end

  @doc """
  Connects two nodes with a specific action.

  ## Parameters
    - left: The source node module
    - action: The action key for this connection (atom)
    - right: The target node module
    
  ## Returns
    A tuple representing the connection
    
  ## Examples

  ```elixir
  flow = NodeA ~> :success ~> NodeB
  ```
  """
  def left ~> action when is_atom(left) and is_atom(action) do
    {left, action}
  end

  def {left, action} ~> right when is_atom(left) and is_atom(action) and is_atom(right) do
    {left, right, action}
  end

  @doc """
  Creates a conditional connection between nodes.

  ## Parameters
    - node: The source node module
    - action: The action key for this connection (atom)
    - target: The target node module
    
  ## Returns
    A tuple representing the connection
    
  ## Examples

  ```elixir
  flow = NodeA |> on(:success, NodeB)
  ```
  """
  def on(node, action, target) when is_atom(node) and is_atom(action) and is_atom(target) do
    {node, target, action}
  end

  @doc """
  Creates a branching connection between nodes.

  ## Parameters
    - flow: The flow to update or a node module
    - action: The action key for this connection (atom)
    - target: The target node module
    
  ## Returns
    The updated flow or a connection tuple
    
  ## Examples

  ```elixir
  flow = NodeA |> branch(:success, NodeB)
  ```
  """
  def branch(flow, action, target) when is_atom(flow) and is_atom(action) and is_atom(target) do
    {flow, target, action}
  end

  def branch(flow, action, target)
      when is_struct(flow, PocketFlex.Flow) and is_atom(action) and is_atom(target) do
    {from, _to, _act} = flow.last_connection || {nil, nil, nil}

    if from do
      PocketFlex.Flow.connect(flow, from, target, action)
    else
      flow
    end
  end

  @doc """
  Applies a list of connections to a flow.

  ## Parameters
    - flow: The flow to update
    - connections: A list of connection tuples
    
  ## Returns
    The updated flow
    
  ## Examples

  ```elixir
  flow = PocketFlex.Flow.new()
  connections = [
    NodeA >>> NodeB,
    NodeA ~> :success ~> NodeC,
    NodeA ~> :error ~> ErrorHandlerNode
  ]
  flow = apply_connections(flow, connections)
  ```
  """
  def apply_connections(flow, connections) when is_list(connections) do
    Enum.reduce(connections, flow, fn
      {from, to, action}, acc when is_atom(from) and is_atom(to) and is_atom(action) ->
        PocketFlex.Flow.connect(acc, from, to, action)

      other, _acc ->
        raise ArgumentError, "Invalid connection: #{inspect(other)}"
    end)
  end

  @doc """
  Creates a linear flow from a list of nodes.

  ## Parameters
    - nodes: A list of node modules
    
  ## Returns
    A list of connection tuples
    
  ## Examples

  ```elixir
  flow = PocketFlex.Flow.new()
  connections = linear_flow([NodeA, NodeB, NodeC])
  flow = apply_connections(flow, connections)
  ```
  """
  def linear_flow(nodes) when is_list(nodes) and length(nodes) > 1 do
    nodes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [from, to] -> {from, to, :default} end)
  end

  @doc """
  Creates a flow with error handling branches.

  ## Parameters
    - main_path: A list of node modules for the main path
    - error_handler: The error handler node module
    
  ## Returns
    A list of connection tuples
    
  ## Examples

  ```elixir
  flow = PocketFlex.Flow.new()
  connections = with_error_handling([NodeA, NodeB, NodeC], ErrorHandlerNode)
  flow = apply_connections(flow, connections)
  ```
  """
  def with_error_handling(main_path, error_handler)
      when is_list(main_path) and is_atom(error_handler) do
    main_connections = linear_flow(main_path)

    error_connections =
      main_path
      |> Enum.map(fn node -> {node, error_handler, :error} end)

    main_connections ++ error_connections
  end
end
