defmodule PocketFlex.AsyncBatchNode do
  @moduledoc """
  Behavior module for asynchronous batch processing nodes.

  Combines the functionality of AsyncNode and BatchNode to support
  asynchronous processing of lists of items.
  """

  @callback exec_item_async(item :: any()) :: {:ok, Task.t()} | {:ok, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour PocketFlex.Node
      @behaviour PocketFlex.AsyncNode
      @behaviour PocketFlex.AsyncBatchNode

      # Default implementations for Node callbacks
      @impl PocketFlex.Node
      def prep(state) do
        {:ok, result} = prep_async(state)
        result
      end

      @impl PocketFlex.Node
      def exec(items) when is_list(items) do
        items
        |> Enum.map(fn item ->
          {:ok, result} = exec_item_async(item)

          if is_struct(result, Task) do
            Task.await(result)
          else
            result
          end
        end)
      end

      def exec(item) do
        {:ok, result} = exec_item_async(item)

        if is_struct(result, Task) do
          Task.await(result)
        else
          result
        end
      end

      @impl PocketFlex.Node
      def post(state, prep_result, exec_result) do
        {:ok, result} = post_async(state, prep_result, exec_result)
        result
      end

      # Default implementations for AsyncNode callbacks
      @impl PocketFlex.AsyncNode
      def prep_async(_state), do: {:ok, nil}

      @impl PocketFlex.AsyncNode
      def exec_async(items) when is_list(items) do
        task =
          Task.async(fn ->
            Enum.map(items, fn item ->
              {:ok, result} = exec_item_async(item)

              if is_struct(result, Task) do
                Task.await(result)
              else
                result
              end
            end)
          end)

        {:ok, task}
      end

      def exec_async(item) do
        task =
          Task.async(fn ->
            {:ok, result} = exec_item_async(item)

            if is_struct(result, Task) do
              Task.await(result)
            else
              result
            end
          end)

        {:ok, task}
      end

      @impl PocketFlex.AsyncNode
      def post_async(state, _prep_res, exec_res), do: {:ok, {:default, state}}

      # Default implementation for AsyncBatchNode callback
      @impl PocketFlex.AsyncBatchNode
      def exec_item_async(item) do
        task = Task.async(fn -> item end)
        {:ok, task}
      end

      # Allow overriding
      defoverridable prep: 1,
                     exec: 1,
                     post: 3,
                     prep_async: 1,
                     exec_async: 1,
                     post_async: 3,
                     exec_item_async: 1
    end
  end
end

defmodule PocketFlex.AsyncParallelBatchNode do
  @moduledoc """
  Behavior module for parallel asynchronous batch processing nodes.

  Extends the AsyncBatchNode behavior with support for processing
  multiple items in parallel using Elixir's Task module.
  """

  @callback exec_item_async(item :: any()) :: {:ok, Task.t()} | {:ok, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour PocketFlex.Node
      @behaviour PocketFlex.AsyncNode
      @behaviour PocketFlex.AsyncParallelBatchNode

      # Default implementations for Node callbacks
      @impl PocketFlex.Node
      def prep(state) do
        {:ok, result} = prep_async(state)
        result
      end

      @impl PocketFlex.Node
      def exec(items) when is_list(items) do
        tasks =
          Enum.map(items, fn item ->
            {:ok, result} = exec_item_async(item)

            if is_struct(result, Task) do
              result
            else
              Task.async(fn -> result end)
            end
          end)

        Task.await_many(tasks, :infinity)
      end

      def exec(item) do
        {:ok, result} = exec_item_async(item)

        if is_struct(result, Task) do
          Task.await(result)
        else
          result
        end
      end

      @impl PocketFlex.Node
      def post(state, prep_result, exec_result) do
        {:ok, result} = post_async(state, prep_result, exec_result)
        result
      end

      # Default implementations for AsyncNode callbacks
      @impl PocketFlex.AsyncNode
      def prep_async(_state), do: {:ok, nil}

      @impl PocketFlex.AsyncNode
      def exec_async(items) when is_list(items) do
        task =
          Task.async(fn ->
            tasks =
              Enum.map(items, fn item ->
                {:ok, result} = exec_item_async(item)

                if is_struct(result, Task) do
                  result
                else
                  Task.async(fn -> result end)
                end
              end)

            Task.await_many(tasks, :infinity)
          end)

        {:ok, task}
      end

      def exec_async(item) do
        task =
          Task.async(fn ->
            {:ok, result} = exec_item_async(item)

            if is_struct(result, Task) do
              Task.await(result)
            else
              result
            end
          end)

        {:ok, task}
      end

      @impl PocketFlex.AsyncNode
      def post_async(state, _prep_res, exec_res), do: {:ok, {:default, state}}

      # Default implementation for AsyncParallelBatchNode callback
      @impl PocketFlex.AsyncParallelBatchNode
      def exec_item_async(item) do
        task = Task.async(fn -> item end)
        {:ok, task}
      end

      # Allow overriding
      defoverridable prep: 1,
                     exec: 1,
                     post: 3,
                     prep_async: 1,
                     exec_async: 1,
                     post_async: 3,
                     exec_item_async: 1
    end
  end
end
