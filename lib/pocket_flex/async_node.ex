defmodule PocketFlex.AsyncNode do
  @moduledoc """
  Behavior module for asynchronous nodes in PocketFlex.

  Extends the basic Node behavior with asynchronous versions of
  the callbacks for concurrent execution.

  ## Conventions

  - All callbacks must use tuple-based error handling: `{:ok, ...}` or `{:error, ...}`
  - Actions must always be atoms (e.g., `:default`, `:success`, `:error`)
  - Never overwrite the shared state with a raw value
  - Prefer using the provided macros for default implementations

  ## Best Practices

  - Override only the callbacks you need
  - Use pattern matching in function heads
  - Document all public functions and modules
  - See the guides for error handling and migration notes
  """

  @callback prep_async(shared :: map()) :: {:ok, any()}
  @callback exec_async(prep_result :: any()) :: {:ok, Task.t() | any()}
  @callback post_async(shared :: map(), prep_result :: any(), exec_result :: any()) ::
              {:ok, {atom() | nil, map()}}

  defmacro __using__(_opts) do
    quote do
      @behaviour PocketFlex.Node
      @behaviour PocketFlex.AsyncNode

      # Default implementations for Node callbacks
      @impl PocketFlex.Node
      def prep(shared) do
        {:ok, result} = prep_async(shared)
        result
      end

      @impl PocketFlex.Node
      def exec(prep_result) do
        {:ok, result} = exec_async(prep_result)

        if is_struct(result, Task) do
          Task.await(result)
        else
          result
        end
      end

      @impl PocketFlex.Node
      def post(shared, prep_result, exec_result) do
        {:ok, result} = post_async(shared, prep_result, exec_result)
        result
      end

      # Default implementations for AsyncNode callbacks
      @impl PocketFlex.AsyncNode
      def prep_async(_shared), do: {:ok, nil}

      @impl PocketFlex.AsyncNode
      def exec_async(prep_result) do
        # This is the default implementation that should be overridden
        task = Task.async(fn -> prep_result end)
        {:ok, task}
      end

      @impl PocketFlex.AsyncNode
      def post_async(shared, _prep_res, exec_res), do: {:ok, {:default, shared}}

      # Allow overriding
      defoverridable prep: 1,
                     exec: 1,
                     post: 3,
                     prep_async: 1,
                     exec_async: 1,
                     post_async: 3
    end
  end
end
