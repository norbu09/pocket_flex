defmodule PocketFlex.Node do
  @moduledoc """
  Behavior module defining the interface for PocketFlex nodes.

  A node is a processing unit that can:
  - Prepare data from the shared state (`prep/1`)
  - Execute logic on that data (`exec/1`)
  - Post-process the results and update the shared state (`post/3`)

  ## Conventions

  - All node and flow operations must use tuple-based error handling: `{:ok, ...}` or `{:error, ...}`.
  - Actions returned from `post/3` must always be atoms (e.g., `:default`, `:success`, `:error`).
  - Never overwrite the shared state with a raw value in `post/3`—always return `{action_atom, updated_state}`.
  - Prefer using the macros in `PocketFlex.NodeMacros` for default implementations.

  ## Best Practices

  - Use pattern matching in function heads.
  - Document all public functions and modules.
  - See the guides for migration and error handling details.
  """

  @doc """
  Prepares data from the shared state for execution.

  ## Parameters
    - shared: A map containing the shared state
    
  ## Returns
    Any data needed for the exec function
  """
  @callback prep(shared :: map()) :: any()

  @doc """
  Executes the node's main logic.

  ## Parameters
    - prep_result: The result from the prep function
    
  ## Returns
    The result of the execution
  """
  @callback exec(prep_result :: any()) :: any()

  @doc """
  Post-processes the execution result and updates the shared state.

  ## Parameters
    - shared: The shared state map
    - prep_result: The result from the prep function
    - exec_result: The result from the exec function
    
  ## Returns
    A tuple containing:
    - The action key for the next node (or nil to end the flow)
    - The updated shared state map
  """
  @callback post(shared :: map(), prep_result :: any(), exec_result :: any()) ::
              {String.t() | nil, map()}

  @doc """
  Handles exceptions during execution.

  ## Parameters
    - prep_result: The result from the prep function
    - exception: The exception that was raised
    
  ## Returns
    A fallback result to use instead of the failed execution
  """
  @callback exec_fallback(prep_result :: any(), exception :: Exception.t()) :: any()

  @doc """
  Returns the maximum number of retry attempts for the exec function.

  ## Returns
    A non-negative integer
  """
  @callback max_retries() :: non_neg_integer()

  @doc """
  Returns the wait time in milliseconds between retry attempts.

  ## Returns
    A non-negative integer
  """
  @callback wait_time() :: non_neg_integer()

  @optional_callbacks [exec_fallback: 2, max_retries: 0, wait_time: 0]
end
