defmodule PocketFlex.StateStorage.GenServer do
  @moduledoc """
  GenServer-based implementation of the StateStorage behavior.

  This module provides an implementation of the StateStorage behavior
  using GenServer processes for storing state.
  """

  @behaviour PocketFlex.StateStorage
  require Logger

  @doc """
  Initializes a new state server for a flow.

  ## Parameters
    - flow_id: A unique identifier for the flow
    - initial_state: The initial state to store
    
  ## Returns
    The flow_id
  """
  @impl PocketFlex.StateStorage
  @spec init(binary(), map()) :: binary()
  def init(flow_id, initial_state) do
    case Registry.lookup(PocketFlex.StateRegistry, flow_id) do
      [] ->
        # Start a new state server under the supervisor
        {:ok, _pid} =
          DynamicSupervisor.start_child(
            PocketFlex.StateSupervisor,
            {PocketFlex.StateStorage.GenServer.Server, {flow_id, initial_state}}
          )

      [{_pid, _}] ->
        # Update existing server
        update_state(flow_id, initial_state)
    end

    flow_id
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
    case lookup(flow_id) do
      {:ok, pid} -> GenServer.call(pid, :get_state)
      {:error, _} -> %{}
    end
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
    case lookup(flow_id) do
      {:ok, pid} ->
        GenServer.call(pid, {:update_state, new_state})

      {:error, _} ->
        # Start a new server if it doesn't exist
        init(flow_id, new_state)
        new_state
    end
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
    case lookup(flow_id) do
      {:ok, pid} ->
        GenServer.call(pid, {:merge_state, state_updates})

      {:error, _} ->
        # Start a new server if it doesn't exist
        init(flow_id, state_updates)
        state_updates
    end
  end

  @doc """
  Cleans up the state for a flow.

  ## Parameters
    - flow_id: The flow identifier
  """
  @impl PocketFlex.StateStorage
  @spec cleanup(binary()) :: :ok
  def cleanup(flow_id) do
    case lookup(flow_id) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(PocketFlex.StateSupervisor, pid)

      {:error, _} ->
        :ok
    end
  end

  # Helper function to look up a state server
  defp lookup(flow_id) do
    case Registry.lookup(PocketFlex.StateRegistry, flow_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  # GenServer implementation for state storage
  defmodule Server do
    @moduledoc """
    GenServer implementation for state storage.
    """

    use GenServer

    @doc """
    Starts a new state server.

    ## Parameters
      - args: A tuple containing {flow_id, initial_state}
      
    ## Returns
      A tuple containing:
      - :ok and the server pid, or
      - :error and an error reason
    """
    @spec start_link({binary(), map()}) :: GenServer.on_start()
    def start_link({flow_id, initial_state}) do
      GenServer.start_link(__MODULE__, initial_state, name: via_tuple(flow_id))
    end

    # Server callbacks

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

    # Helper function to create a via tuple for the registry
    defp via_tuple(flow_id) do
      {:via, Registry, {PocketFlex.StateRegistry, flow_id}}
    end
  end
end
