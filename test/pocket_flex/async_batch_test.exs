defmodule PocketFlex.AsyncBatchTest do
  use ExUnit.Case
  require Logger

  # Define test nodes
  defmodule TestAsyncBatchNode do
    use PocketFlex.AsyncBatchNode

    @impl true
    def prep(shared) do
      # Return a list of items to process
      shared["items"] || []
    end

    @impl true
    def exec_item_async(item) do
      task =
        Task.async(fn ->
          # Simulate processing with a small delay
          Process.sleep(50)
          item * 2
        end)

      {:ok, task}
    end

    @impl true
    def post(shared, _prep_res, results) do
      # Store the results in the shared state
      updated_shared = Map.put(shared, "results", results)
      {:default, updated_shared}
    end
  end

  defmodule TestAsyncParallelBatchNode do
    use PocketFlex.AsyncParallelBatchNode

    @impl true
    def prep(shared) do
      # Return a list of items to process
      shared["items"] || []
    end

    @impl true
    def exec_item_async(item) do
      task =
        Task.async(fn ->
          # Simulate processing with a small delay
          Process.sleep(50)
          item * 3
        end)

      {:ok, task}
    end

    @impl true
    def post(shared, _prep_res, results) do
      # Store the results in the shared state
      updated_shared = Map.put(shared, "results", results)
      {:default, updated_shared}
    end
  end

  defmodule ResultAggregatorNode do
    use PocketFlex.NodeMacros

    @impl true
    def exec(shared) do
      # Get the results from the shared state
      results = shared["results"] || []

      # Sum the results
      Enum.sum(results)
    end

    @impl true
    def post(shared, _prep_res, sum) do
      # Store the sum in the shared state
      updated_shared = Map.put(shared, "sum", sum)
      {:default, updated_shared}
    end
  end

  describe "AsyncBatchNode" do
    test "processes items sequentially but asynchronously" do
      # Create a flow
      flow =
        PocketFlex.Flow.new()
        |> PocketFlex.Flow.add_node(TestAsyncBatchNode)
        |> PocketFlex.Flow.add_node(ResultAggregatorNode)
        |> PocketFlex.Flow.connect(TestAsyncBatchNode, ResultAggregatorNode)
        |> PocketFlex.Flow.start(TestAsyncBatchNode)

      # Initial shared state with items to process
      shared = %{"items" => [1, 2, 3, 4, 5]}

      # Run the flow directly
      {:ok, final_shared} = PocketFlex.Flow.run(flow, shared)

      # Check the results
      assert is_list(final_shared["results"])
      assert Enum.sort(final_shared["results"]) == [2, 4, 6, 8, 10]
      assert final_shared["sum"] == 30
    end
  end

  describe "AsyncParallelBatchNode" do
    test "processes items in parallel and asynchronously" do
      # Create a flow
      flow =
        PocketFlex.Flow.new()
        |> PocketFlex.Flow.add_node(TestAsyncParallelBatchNode)
        |> PocketFlex.Flow.add_node(ResultAggregatorNode)
        |> PocketFlex.Flow.connect(TestAsyncParallelBatchNode, ResultAggregatorNode)
        |> PocketFlex.Flow.start(TestAsyncParallelBatchNode)

      # Initial shared state with items to process
      shared = %{"items" => [1, 2, 3, 4, 5]}

      # Run the flow directly
      {:ok, final_shared} = PocketFlex.Flow.run(flow, shared)

      # Check the results
      assert is_list(final_shared["results"])
      assert Enum.sort(final_shared["results"]) == [3, 6, 9, 12, 15]
      assert final_shared["sum"] == 45
    end
  end

  describe "AsyncBatchFlow example" do
    test "runs the async batch example" do
      urls = ["https://example.com/1", "https://example.com/2", "https://example.com/3"]

      {:ok, results} = PocketFlex.Examples.AsyncBatchExample.run(urls)

      assert results.total_urls == 3
      assert results.total_word_count > 0
      assert results.average_word_count > 0
    end

    test "runs the async parallel batch example" do
      urls = ["https://example.com/1", "https://example.com/2", "https://example.com/3"]

      {:ok, results} = PocketFlex.Examples.AsyncBatchExample.run_parallel(urls)

      assert results.total_urls == 3
      assert results.total_word_count > 0
      assert results.average_word_count > 0
    end
  end
end
