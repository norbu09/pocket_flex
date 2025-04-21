defmodule PocketFlex.StateManager do
  @moduledoc """
  Manages shared state between nodes in a flow using ETS tables.

  This module provides functions for creating, updating, and retrieving
  shared state for flows, ensuring proper state management in concurrent
  and asynchronous operations.
  """

  require Logger

  @doc """
  Initializes a new state table for a flow.

  ## Parameters
    - flow_id: A unique identifier for the flow
    - initial_state: The initial shared state
    
  ## Returns
    The flow_id
  """
  @spec init(binary(), map()) :: binary()
  def init(flow_id, initial_state) do
    # Create a new ETS table for this flow
    table_name = table_name(flow_id)

    # Create the table if it doesn't exist
    if :ets.info(table_name) == :undefined do
      :ets.new(table_name, [:set, :public, :named_table])
    end

    # Store the initial state
    :ets.insert(table_name, {:shared_state, initial_state})

    flow_id
  end

  @doc """
  Gets the current shared state for a flow.

  ## Parameters
    - flow_id: The flow identifier
    
  ## Returns
    The current shared state
  """
  @spec get_state(binary()) :: map()
  def get_state(flow_id) do
    table_name = table_name(flow_id)

    case :ets.lookup(table_name, :shared_state) do
      [{:shared_state, state}] -> state
      [] -> %{}
    end
  end

  @doc """
  Updates the shared state for a flow.

  ## Parameters
    - flow_id: The flow identifier
    - new_state: The new shared state
    
  ## Returns
    The updated shared state
  """
  @spec update_state(binary(), map()) :: map()
  def update_state(flow_id, new_state) do
    table_name = table_name(flow_id)

    :ets.insert(table_name, {:shared_state, new_state})
    new_state
  end

  @doc """
  Updates the shared state for a flow by merging with the current state.

  ## Parameters
    - flow_id: The flow identifier
    - state_updates: The state updates to merge
    
  ## Returns
    The updated shared state
  """
  @spec merge_state(binary(), map()) :: map()
  def merge_state(flow_id, state_updates) do
    current_state = get_state(flow_id)
    updated_state = Map.merge(current_state, state_updates)
    update_state(flow_id, updated_state)
  end

  @doc """
  Cleans up the state table for a flow.

  ## Parameters
    - flow_id: The flow identifier
  """
  @spec cleanup(binary()) :: :ok
  def cleanup(flow_id) do
    table_name = table_name(flow_id)

    if :ets.info(table_name) != :undefined do
      :ets.delete(table_name)
    end

    :ok
  end

  # Generates a table name from a flow_id
  defp table_name(flow_id) do
    :"pocket_flex_state_#{flow_id}"
  end
end
