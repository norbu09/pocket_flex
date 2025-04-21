defmodule PocketFlex.StateStorage do
  @moduledoc """
  Behavior for state storage implementations.

  This module defines the behavior that all state storage implementations
  must follow. It provides a common interface for initializing, getting,
  updating, and cleaning up state.
  """

  @doc """
  Initializes a new state for a flow.

  ## Parameters
    - flow_id: A unique identifier for the flow
    - initial_state: The initial state to store
    
  ## Returns
    The flow_id
  """
  @callback init(flow_id :: binary(), initial_state :: map()) :: binary()

  @doc """
  Gets the current state for a flow.

  ## Parameters
    - flow_id: The flow identifier
    
  ## Returns
    The current state
  """
  @callback get_state(flow_id :: binary()) :: map()

  @doc """
  Updates the state for a flow.

  ## Parameters
    - flow_id: The flow identifier
    - new_state: The new state
    
  ## Returns
    The updated state
  """
  @callback update_state(flow_id :: binary(), new_state :: map()) :: map()

  @doc """
  Updates the state for a flow by merging with the current state.

  ## Parameters
    - flow_id: The flow identifier
    - state_updates: The state updates to merge
    
  ## Returns
    The updated state
  """
  @callback merge_state(flow_id :: binary(), state_updates :: map()) :: map()

  @doc """
  Cleans up the state for a flow.

  ## Parameters
    - flow_id: The flow identifier
  """
  @callback cleanup(flow_id :: binary()) :: :ok

  @doc """
  Gets the configured state storage module.

  ## Returns
    The configured state storage module
  """
  def get_storage_module do
    Application.get_env(:pocket_flex, :state_storage, PocketFlex.StateStorage.ETS)
  end

  @doc """
  Initializes a new state for a flow using the configured storage.

  ## Parameters
    - flow_id: A unique identifier for the flow
    - initial_state: The initial state to store
    
  ## Returns
    The flow_id
  """
  def init(flow_id, initial_state) do
    get_storage_module().init(flow_id, initial_state)
  end

  @doc """
  Gets the current state for a flow using the configured storage.

  ## Parameters
    - flow_id: The flow identifier
    
  ## Returns
    The current state
  """
  def get_state(flow_id) do
    get_storage_module().get_state(flow_id)
  end

  @doc """
  Updates the state for a flow using the configured storage.

  ## Parameters
    - flow_id: The flow identifier
    - new_state: The new state
    
  ## Returns
    The updated state
  """
  def update_state(flow_id, new_state) do
    get_storage_module().update_state(flow_id, new_state)
  end

  @doc """
  Updates the state for a flow by merging with the current state using the configured storage.

  ## Parameters
    - flow_id: The flow identifier
    - state_updates: The state updates to merge
    
  ## Returns
    The updated state
  """
  def merge_state(flow_id, state_updates) do
    get_storage_module().merge_state(flow_id, state_updates)
  end

  @doc """
  Cleans up the state for a flow using the configured storage.

  ## Parameters
    - flow_id: The flow identifier
  """
  def cleanup(flow_id) do
    get_storage_module().cleanup(flow_id)
  end
end
