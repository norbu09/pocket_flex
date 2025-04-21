defmodule PocketFlex.StateStorage.ETS do
  @moduledoc """
  ETS-based implementation of the StateStorage behavior using a single shared table.

  This module provides an implementation of the StateStorage behavior
  using a single Erlang Term Storage (ETS) table for storing all flow states.
  Each flow's state is stored as a separate entry in the table, indexed by flow_id.
  """

  @behaviour PocketFlex.StateStorage
  use GenServer
  require Logger

  @table_name :pocket_flex_shared_state

  # Client API

  def start_link(_params) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Gets the current state for a flow.

  ## Parameters
    - flow_id: The flow identifier
    
  ## Returns
    The current state
  """
  @impl PocketFlex.StateStorage
  @spec get_state(binary()) :: map()
  def get_state(flow_id) do
    GenServer.call(__MODULE__, {:get_state, flow_id})
  end

  @doc """
  Updates the state for a flow.

  ## Parameters
    - flow_id: The flow identifier
    - new_state: The new state
    
  ## Returns
    The updated state
  """
  @impl PocketFlex.StateStorage
  @spec update_state(binary(), map()) :: map()
  def update_state(flow_id, new_state) do
    GenServer.call(__MODULE__, {:update_state, flow_id, new_state})
  end

  @doc """
  Updates the state for a flow by merging with the current state.

  ## Parameters
    - flow_id: The flow identifier
    - state_updates: The state updates to merge
    
  ## Returns
    The updated state
  """
  @impl PocketFlex.StateStorage
  @spec merge_state(binary(), map()) :: map()
  def merge_state(flow_id, state_updates) do
    GenServer.call(__MODULE__, {:merge_state, flow_id, state_updates})
  end

  @doc """
  Cleans up the state for a flow.

  ## Parameters
    - flow_id: The flow identifier
  """
  @impl PocketFlex.StateStorage
  @spec cleanup(binary()) :: :ok
  def cleanup(flow_id) do
    GenServer.call(__MODULE__, {:cleanup, flow_id})
  end

  # Server Callbacks

  @impl true
  def init(_params) do
    # Ensure the table exists
    if :ets.info(@table_name) == :undefined do
      :ets.new(@table_name, [:set, :public, :named_table])
    end
    
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get_state, flow_id}, _from, state) do
    result = case :ets.lookup(@table_name, flow_id) do
      [{^flow_id, flow_state}] -> flow_state
      [] -> %{}
    end
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:update_state, flow_id, new_state}, _from, state) do
    :ets.insert(@table_name, {flow_id, new_state})
    {:reply, new_state, state}
  end

  @impl true
  def handle_call({:merge_state, flow_id, state_updates}, _from, state) do
    current_state = case :ets.lookup(@table_name, flow_id) do
      [{^flow_id, flow_state}] -> flow_state
      [] -> %{}
    end
    
    updated_state = Map.merge(current_state, state_updates)
    :ets.insert(@table_name, {flow_id, updated_state})
    
    {:reply, updated_state, state}
  end

  @impl true
  def handle_call({:cleanup, flow_id}, _from, state) do
    :ets.delete(@table_name, flow_id)
    {:reply, :ok, state}
  end
end
