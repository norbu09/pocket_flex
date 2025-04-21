defmodule PocketFlex.AsyncBatchNode do
  @moduledoc """
  Behavior module for asynchronous batch processing nodes in PocketFlex.

  Combines the functionality of AsyncNode and BatchNode to support
  asynchronous processing of lists of items.

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

  @callback exec_item_async(item :: any()) :: {:ok, Task.t()} | {:ok, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour PocketFlex.Node
      @behaviour PocketFlex.AsyncNode
      @behaviour PocketFlex.AsyncBatchNode

      # Default implementations for Node callbacks
      @impl PocketFlex.Node
      @doc """
      Prepares the shared state for async batch execution.
      Returns the result of `prep_async/1` by default.
      """
      def prep(state) do
        {:ok, result} = prep_async(state)
        result
      end

      @impl PocketFlex.Node
      @doc """
      Executes the node for a list of items asynchronously, calling `exec_item_async/1` for each item.
      Waits for each task if the result is a Task struct.
      """
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

      @doc """
      Executes the node for a single item asynchronously.
      Waits for the task if the result is a Task struct.
      """
      def exec(item) do
        {:ok, result} = exec_item_async(item)

        if is_struct(result, Task) do
          Task.await(result)
        else
          result
        end
      end

      @impl PocketFlex.Node
      @doc """
      Post-processes the async batch execution result and updates the shared state.
      Returns the result of `post_async/3` by default.
      """
      def post(state, prep_result, exec_result) do
        {:ok, result} = post_async(state, prep_result, exec_result)
        result
      end

      # Default implementations for AsyncNode callbacks
      @impl PocketFlex.AsyncNode
      @doc """
      Asynchronously prepares the shared state. Returns `{:ok, nil}` by default.
      """
      def prep_async(_state), do: {:ok, nil}

      @impl PocketFlex.AsyncNode
      @doc """
      Executes a list of items asynchronously using Task. Override for custom behavior.
      """
      def exec_async(items) when is_list(items) do
        task =
          Task.async(fn ->
            process_items_async(items)
          end)

        {:ok, task}
      end

      def exec_async(item) do
        task =
          Task.async(fn ->
            process_item_async(item)
          end)

        {:ok, task}
      end

      defp process_items_async(items) do
        Enum.map(items, fn item ->
          process_item_async(item)
        end)
      end

      defp process_item_async(item) do
        {:ok, result} = exec_item_async(item)
        await_result_if_task(result)
      end

      defp await_result_if_task(result) do
        if is_struct(result, Task) do
          Task.await(result)
        else
          result
        end
      end

      @impl PocketFlex.AsyncNode
      @doc """
      Asynchronously post-processes the execution result and updates the shared state. Returns `{:ok, {:default, shared}}` by default.
      """
      def post_async(state, _prep_res, exec_res), do: {:ok, {:default, state}}

      # Default implementation for AsyncBatchNode callback
      @impl PocketFlex.AsyncBatchNode
      @doc """
      Executes an item asynchronously. Returns a Task struct or the result directly.
      """
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
      @doc """
      Prepares the shared state for async batch execution.
      Returns the result of `prep_async/1` by default.
      """
      def prep(state) do
        {:ok, result} = prep_async(state)
        result
      end

      @impl PocketFlex.Node
      @doc """
      Executes the node for a list of items asynchronously, calling `exec_item_async/1` for each item.
      Waits for each task if the result is a Task struct.
      """
      def exec(items) when is_list(items) do
        tasks = create_tasks_for_items(items)
        Task.await_many(tasks, :infinity)
      end

      @doc """
      Executes the node for a single item asynchronously.
      Waits for the task if the result is a Task struct.
      """
      def exec(item) do
        {:ok, result} = exec_item_async(item)
        await_result_if_task(result)
      end

      @impl PocketFlex.Node
      @doc """
      Post-processes the async batch execution result and updates the shared state.
      Returns the result of `post_async/3` by default.
      """
      def post(state, prep_result, exec_result) do
        {:ok, result} = post_async(state, prep_result, exec_result)
        result
      end

      # Default implementations for AsyncNode callbacks
      @impl PocketFlex.AsyncNode
      @doc """
      Asynchronously prepares the shared state. Returns `{:ok, nil}` by default.
      """
      def prep_async(_state), do: {:ok, nil}

      @impl PocketFlex.AsyncNode
      @doc """
      Executes a list of items asynchronously using Task. Override for custom behavior.
      """
      def exec_async(items) when is_list(items) do
        task =
          Task.async(fn ->
            process_items_in_parallel(items)
          end)

        {:ok, task}
      end

      def exec_async(item) do
        task =
          Task.async(fn ->
            process_item_async(item)
          end)

        {:ok, task}
      end

      defp process_items_in_parallel(items) do
        tasks = create_tasks_for_items(items)
        Task.await_many(tasks, :infinity)
      end

      defp create_tasks_for_items(items) do
        Enum.map(items, fn item ->
          {:ok, result} = exec_item_async(item)
          convert_to_task(result)
        end)
      end

      defp convert_to_task(result) do
        if is_struct(result, Task) do
          result
        else
          Task.async(fn -> result end)
        end
      end

      defp process_item_async(item) do
        {:ok, result} = exec_item_async(item)
        await_result_if_task(result)
      end

      defp await_result_if_task(result) do
        if is_struct(result, Task) do
          Task.await(result)
        else
          result
        end
      end

      @impl PocketFlex.AsyncNode
      @doc """
      Asynchronously post-processes the execution result and updates the shared state. Returns `{:ok, {:default, shared}}` by default.
      """
      def post_async(state, _prep_res, exec_res), do: {:ok, {:default, state}}

      # Default implementation for AsyncParallelBatchNode callback
      @impl PocketFlex.AsyncParallelBatchNode
      @doc """
      Executes an item asynchronously. Returns a Task struct or the result directly.
      """
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
