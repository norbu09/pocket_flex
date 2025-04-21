defmodule PocketFlex.StateStorage do
  @moduledoc """
  Behavior for state storage implementations in PocketFlex.

  This module defines the required interface for any state storage backend.
  It ensures:
  - Tuple-based error handling (`{:ok, ...}`/`{:error, ...}`) for all operations
  - Never overwrite shared state with a raw value; always update the state map
  - Support for concurrent, efficient, and flexible storage

  ## Best Practices

  - Use only serializable data in state (no PIDs, functions, or references)
  - Always call `cleanup/1` after flow completion
  - Document all public functions and modules
  - See the guides for error handling, configuration, and migration notes

  ## Usage

  State storage is typically used by flow implementations to store and retrieve state:

  ```elixir
  # Get the current state for a flow
  state = PocketFlex.StateStorage.get_state(flow_id)

  # Update the state for a flow
  PocketFlex.StateStorage.update_state(flow_id, new_state)

  # Merge updates into the current state
  PocketFlex.StateStorage.merge_state(flow_id, state_updates)

  # Clean up the state when done
  PocketFlex.StateStorage.cleanup(flow_id)
  ```

  ## Implementing a Custom State Storage Backend

  To implement a custom state storage backend, create a module that implements
  the `PocketFlex.StateStorage` behavior and follows the conventions above.

  ```elixir
  defmodule MyApp.CustomStateStorage do
    @behaviour PocketFlex.StateStorage

    @impl true
    def get_state(flow_id) do
      # Implementation
    end

    @impl true
    def update_state(flow_id, new_state) do
      # Implementation
    end

    @impl true
    def merge_state(flow_id, state_updates) do
      # Implementation
    end

    @impl true
    def cleanup(flow_id) do
      # Implementation
    end
  end
  ```

  Then configure PocketFlex to use your custom storage backend:

  ```elixir
  # In your config/config.exs
  config :pocket_flex, :state_storage, MyApp.CustomStateStorage
  ```
  """

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
