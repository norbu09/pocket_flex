defmodule PocketFlex.BatchNode do
  @moduledoc """
  Behavior module for batch processing nodes in PocketFlex.

  Extends the basic Node behavior with support for processing
  multiple items in a batch.

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

  @callback exec_item(item :: any()) :: any()

  defmacro __using__(_opts) do
    quote do
      @behaviour PocketFlex.Node
      @behaviour PocketFlex.BatchNode

      # Default implementations for Node callbacks
      @impl PocketFlex.Node
      @doc """
      Prepares the shared state for batch execution.
      Returns the state as-is by default.
      """
      def prep(shared), do: shared

      @impl PocketFlex.Node
      @doc """
      Executes the node for a list of items, calling `exec_item/1` for each item.
      """
      def exec(items) when is_list(items) do
        Enum.map(items, &exec_item/1)
      end

      @doc """
      Executes the node for a single item.
      """
      def exec(item), do: exec_item(item)

      @impl PocketFlex.Node
      @doc """
      Post-processes the batch execution result and updates the shared state.
      Returns the default action and shared state by default.
      """
      def post(shared, _prep_res, exec_res), do: {"default", shared}

      # Allow overriding
      defoverridable prep: 1, exec: 1, post: 3
    end
  end
end

defmodule PocketFlex.ParallelBatchNode do
  @moduledoc """
  Behavior module for parallel batch processing nodes in PocketFlex.

  Extends the BatchNode behavior with support for processing
  multiple items in parallel.

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

  @callback exec_item(item :: any()) :: any()

  defmacro __using__(_opts) do
    quote do
      @behaviour PocketFlex.Node
      @behaviour PocketFlex.ParallelBatchNode

      # Default implementations for Node callbacks
      @impl PocketFlex.Node
      @doc """
      Prepares the shared state for batch execution.
      Returns the state as-is by default.
      """
      def prep(shared), do: shared

      @impl PocketFlex.Node
      @doc """
      Executes the node for a list of items in parallel, calling `exec_item/1` for each item.
      """
      def exec(items) when is_list(items) do
        items
        |> Enum.map(fn item ->
          Task.async(fn -> exec_item(item) end)
        end)
        |> Task.await_many(:infinity)
      end

      @doc """
      Executes the node for a single item.
      """
      def exec(item), do: exec_item(item)

      @impl PocketFlex.Node
      @doc """
      Post-processes the batch execution result and updates the shared state.
      Returns the default action and shared state by default.
      """
      def post(shared, _prep_res, exec_res), do: {"default", shared}

      # Allow overriding
      defoverridable prep: 1, exec: 1, post: 3
    end
  end
end
