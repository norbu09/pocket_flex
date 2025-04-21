defmodule PocketFlex.BatchNode do
  @moduledoc """
  Behavior module for batch processing nodes.

  Extends the basic Node behavior with support for processing
  multiple items in a batch.
  """

  @callback exec_item(item :: any()) :: any()

  defmacro __using__(_opts) do
    quote do
      @behaviour PocketFlex.Node
      @behaviour PocketFlex.BatchNode

      # Default implementations for Node callbacks
      @impl PocketFlex.Node
      def prep(shared), do: shared

      @impl PocketFlex.Node
      def exec(items) when is_list(items) do
        Enum.map(items, &exec_item/1)
      end

      def exec(item), do: exec_item(item)

      @impl PocketFlex.Node
      def post(shared, _prep_res, exec_res), do: {"default", shared}

      # Allow overriding
      defoverridable prep: 1, exec: 1, post: 3
    end
  end
end

defmodule PocketFlex.ParallelBatchNode do
  @moduledoc """
  Behavior module for parallel batch processing nodes.

  Extends the BatchNode behavior with support for processing
  multiple items in parallel.
  """

  @callback exec_item(item :: any()) :: any()

  defmacro __using__(_opts) do
    quote do
      @behaviour PocketFlex.Node
      @behaviour PocketFlex.ParallelBatchNode

      # Default implementations for Node callbacks
      @impl PocketFlex.Node
      def prep(shared), do: shared

      @impl PocketFlex.Node
      def exec(items) when is_list(items) do
        items
        |> Enum.map(fn item ->
          Task.async(fn -> exec_item(item) end)
        end)
        |> Task.await_many(:infinity)
      end

      def exec(item), do: exec_item(item)

      @impl PocketFlex.Node
      def post(shared, _prep_res, exec_res), do: {"default", shared}

      # Allow overriding
      defoverridable prep: 1, exec: 1, post: 3
    end
  end
end
