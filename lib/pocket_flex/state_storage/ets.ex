defmodule PocketFlex.StateStorage.ETS do
  @moduledoc """
  ETS-based implementation of the StateStorage behavior using a single shared table for PocketFlex.

  This module provides:
  - High-performance, concurrent state storage for all flows using ETS
  - Tuple-based error handling (`{:ok, ...}`/`{:error, ...}`) for all operations
  - Never overwrites shared state with a raw value; always updates the state map
  - Configuration of ETS table name via application config

  ## Best Practices

  - Use only serializable data in state (no PIDs, functions, or references)
  - Always call `cleanup/1` after flow completion
  - Document all public functions and modules
  - See the guides for error handling, configuration, and migration notes
  """

  @behaviour PocketFlex.StateStorage
  use GenServer
  require Logger

  @table_name Application.compile_env(:pocket_flex, __MODULE__,
                table_name: :pocket_flex_shared_state
              )[:table_name]

  # Client API

  def start_link(_params) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Gets the current state for a flow.

  ## Parameters
    - flow_id: The flow identifier
    
  ## Returns
    The current state (empty map if not found)
  """
  @impl PocketFlex.StateStorage
  @spec get_state(binary()) :: map()
  def get_state(flow_id) do
    case lookup_state(flow_id) do
      {:ok, state} -> state
      {:error, _reason} -> %{}
    end
  end

  @doc """
  Updates the state for a flow.

  Replaces any existing state with the new state.

  ## Parameters
    - flow_id: The flow identifier
    - new_state: The new state
    
  ## Returns
    The updated state or `{:error, reason}` on failure
  """
  @impl PocketFlex.StateStorage
  @spec update_state(binary(), map()) :: map() | {:error, term()}
  def update_state(flow_id, new_state) do
    GenServer.call(__MODULE__, {:update_state, flow_id, new_state})
  end

  @doc """
  Updates the state for a flow by merging with the current state.

  Retrieves the current state, merges it with the provided updates,
  and stores the result.

  ## Parameters
    - flow_id: The flow identifier
    - state_updates: The state updates to merge
    
  ## Returns
    The updated state or `{:error, reason}` on failure
  """
  @impl PocketFlex.StateStorage
  @spec merge_state(binary(), map()) :: map() | {:error, term()}
  def merge_state(flow_id, state_updates) do
    GenServer.call(__MODULE__, {:merge_state, flow_id, state_updates})
  end

  @doc """
  Cleans up the state for a flow.

  Removes the flow's state entry from the ETS table.

  ## Parameters
    - flow_id: The flow identifier
    
  ## Returns
    `:ok` on success, `{:error, reason}` on failure
  """
  @impl PocketFlex.StateStorage
  @spec cleanup(binary()) :: :ok | {:error, term()}
  def cleanup(flow_id) do
    GenServer.call(__MODULE__, {:cleanup, flow_id})
  end

  @doc """
  Clears all objects from the ETS table.
  Use only for test isolation.
  """
  def clear_table do
    GenServer.call(__MODULE__, :clear_table)
  end

  # Private functions for state access

  defp ensure_table_exists do
    if :ets.info(@table_name) == :undefined do
      Logger.info("ETS table #{@table_name} missing, creating now.")
      :ets.new(@table_name, [:set, :public, :named_table])
    end

    :ok
  end

  defp lookup_state(flow_id) do
    ensure_table_exists()

    case :ets.lookup(@table_name, flow_id) do
      [{^flow_id, state}] ->
        {:ok, state}

      [] ->
        {:ok, %{}}

      _ ->
        Logger.error("Error looking up state for flow_id #{flow_id}")
        {:error, :lookup_failed}
    end
  rescue
    error ->
      Logger.error("Exception looking up state for flow_id #{flow_id}: #{inspect(error)}")
      {:error, :lookup_failed}
  end

  defp insert_state(flow_id, state_data) do
    ensure_table_exists()

    try do
      :ets.insert(@table_name, {flow_id, state_data})
      :ok
    rescue
      error ->
        Logger.error("Failed to insert state for flow_id #{flow_id}: #{inspect(error)}")
        {:error, :insert_failed}
    end
  end

  defp delete_state(flow_id) do
    ensure_table_exists()

    try do
      :ets.delete(@table_name, flow_id)
      :ok
    rescue
      error ->
        Logger.error("Failed to delete state for flow_id #{flow_id}: #{inspect(error)}")
        {:error, :delete_failed}
    end
  end

  # Server Callbacks

  @impl true
  def init(_params) do
    # Ensure the table exists
    if :ets.info(@table_name) == :undefined do
      Logger.info("Creating ETS table #{@table_name} for state storage")

      case create_table() do
        {:ok, _table} -> {:ok, %{}}
        {:error, reason} -> {:stop, reason}
      end
    else
      Logger.info("Using existing ETS table #{@table_name} for state storage")
      {:ok, %{}}
    end
  end

  defp create_table do
    try do
      table = :ets.new(@table_name, [:set, :public, :named_table])
      {:ok, table}
    rescue
      error ->
        Logger.error("Failed to create ETS table: #{inspect(error)}")
        {:error, :table_creation_failed}
    end
  end

  @impl true
  def handle_call({:get_state, flow_id}, _from, state) do
    result = lookup_state(flow_id)

    case result do
      {:ok, flow_state} -> {:reply, flow_state, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:update_state, flow_id, new_state}, _from, state) do
    case insert_state(flow_id, new_state) do
      :ok ->
        Logger.debug("Updated state for flow_id #{flow_id}")
        {:reply, new_state, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:merge_state, flow_id, state_updates}, _from, state) do
    with {:ok, current_state} <- lookup_state(flow_id),
         updated_state = Map.merge(current_state, state_updates),
         :ok <- insert_state(flow_id, updated_state) do
      Logger.debug("Merged state for flow_id #{flow_id}")
      {:reply, updated_state, state}
    else
      {:error, reason} ->
        Logger.error("Failed to merge state for flow_id #{flow_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:cleanup, flow_id}, _from, state) do
    case delete_state(flow_id) do
      :ok ->
        Logger.debug("Cleaned up state for flow_id #{flow_id}")
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:clear_table, _from, state) do
    ensure_table_exists()

    try do
      :ets.delete_all_objects(@table_name)
      {:reply, :ok, state}
    rescue
      error ->
        Logger.warning("Failed to clear ETS table in handle_call: #{inspect(error)}")
        {:reply, :ok, state}
    end
  end
end
