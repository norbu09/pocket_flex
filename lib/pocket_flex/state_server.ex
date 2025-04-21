defmodule PocketFlex.StateServer do
  @moduledoc """
  GenServer for managing shared state between nodes in a flow.

  This module provides a stateful server for creating, updating, and retrieving
  shared state for flows, ensuring proper state management in concurrent
  and asynchronous operations.
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Starts a new state server for a flow.

  ## Parameters
    - flow_id: A unique identifier for the flow
    - initial_state: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the server pid, or
    - :error and an error reason
  """
  @spec start_link(binary(), map()) :: GenServer.on_start()
  def start_link(flow_id, initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(flow_id))
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
    case lookup(flow_id) do
      {:ok, pid} -> GenServer.call(pid, :get_state)
      {:error, _} -> %{}
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
    case lookup(flow_id) do
      {:ok, pid} -> GenServer.call(pid, {:update_state, new_state})
      {:error, _} -> new_state
    end
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
    case lookup(flow_id) do
      {:ok, pid} -> GenServer.call(pid, {:merge_state, state_updates})
      {:error, _} -> state_updates
    end
  end

  @doc """
  Stops the state server for a flow.

  ## Parameters
    - flow_id: The flow identifier
  """
  @spec stop(binary()) :: :ok
  def stop(flow_id) do
    case lookup(flow_id) do
      {:ok, pid} -> GenServer.stop(pid)
      {:error, _} -> :ok
    end
  end

  # Server Callbacks

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:update_state, new_state}, _from, _state) do
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:merge_state, state_updates}, _from, state) do
    updated_state = Map.merge(state, state_updates)
    {:reply, updated_state, updated_state}
  end

  # Helper functions

  defp via_tuple(flow_id) do
    {:via, Registry, {PocketFlex.StateRegistry, flow_id}}
  end

  defp lookup(flow_id) do
    case Registry.lookup(PocketFlex.StateRegistry, flow_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end
end
