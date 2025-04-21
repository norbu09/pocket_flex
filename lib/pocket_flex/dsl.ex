defmodule PocketFlex.DSL do
  @moduledoc """
  Provides a domain-specific language for connecting nodes.
  
  This module defines operators and functions that make it
  easier to create and connect nodes in a flow.
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
  """
  def left >>> right when is_atom(left) and is_atom(right) do
    {left, right, "default"}
  end
  
  # Pattern matching function for connecting nodes with a specific action
  def {left, action} >>> right when is_atom(left) and is_binary(action) and is_atom(right) do
    {left, right, action}
  end
  
  @doc """
  Applies a list of connections to a flow.
  
  ## Parameters
    - flow: The flow to update
    - connections: A list of connection tuples
    
  ## Returns
    The updated flow
  """
  def apply_connections(flow, connections) when is_list(connections) do
    Enum.reduce(connections, flow, fn {from, to, action}, acc ->
      PocketFlex.Flow.connect(acc, from, to, action)
    end)
  end
end
