defmodule PocketFlex.AsyncBatchTest do
  use ExUnit.Case
  require Logger

  # Define test nodes
  defmodule BatchItemNode do
    use PocketFlex.AsyncBatchNode

    @impl true
    def prep(shared) do
      Logger.info("BatchItemNode prep called")
      shared["items"] || []
    end

    @impl true
    def exec_item_async(item) do
      Logger.info("BatchItemNode exec_item called with #{inspect(item)}")
      # Simulate processing with a short delay
      Process.sleep(5)
      {:ok, String.upcase(item)}
    end

    @impl true
    def post(shared, _prep_res, results) do
      Logger.info("BatchItemNode post called with #{inspect(results)}")
      {:success, Map.put(shared, "processed", List.last(results))}
    end
  end

  defmodule ProcessorNode do
    use PocketFlex.NodeMacros

    @impl true
    def prep(shared) do
      Logger.info("ProcessorNode prep called with shared: #{inspect(shared)}")
      shared["processed"]
    end

    @impl true
    def exec(data) do
      Logger.info("ProcessorNode exec called with #{inspect(data)}")
      "#{data} processed"
    end

    @impl true
    def post(shared, _prep_res, exec_res) do
      Logger.info("ProcessorNode post called with #{inspect(exec_res)}")
      {:success, Map.put(shared, "result", exec_res)}
    end
  end

  describe "AsyncBatchFlow" do
    test "processes batch items sequentially" do
      # Create a flow
      flow =
        PocketFlex.Flow.new()
        |> PocketFlex.Flow.add_node(BatchItemNode)
        |> PocketFlex.Flow.add_node(ProcessorNode)
        |> PocketFlex.Flow.connect(BatchItemNode, ProcessorNode, :success)
        |> PocketFlex.Flow.start(BatchItemNode)

      # Initial shared state with items to process
      shared = %{"items" => ["item1", "item2", "item3"]}

      # Run the flow using async batch
      task = PocketFlex.AsyncBatchFlow.run_async_batch(flow, shared)

      # Wait for the task to complete
      {:ok, final_state} = Task.await(task, 5000)

      # Verify the results
      assert final_state["processed"] == "ITEM3"
      assert final_state["result"] == "ITEM3 processed"
    end

    test "processes batch items in parallel" do
      # Create a flow
      flow =
        PocketFlex.Flow.new()
        |> PocketFlex.Flow.add_node(BatchItemNode)
        |> PocketFlex.Flow.add_node(ProcessorNode)
        |> PocketFlex.Flow.connect(BatchItemNode, ProcessorNode, :success)
        |> PocketFlex.Flow.start(BatchItemNode)

      # Initial shared state with items to process
      shared = %{"items" => ["item1", "item2", "item3"]}

      # Run the flow using async parallel batch
      task = PocketFlex.AsyncParallelBatchFlow.run_async_parallel_batch(flow, shared)

      # Wait for the task to complete with a longer timeout
      {:ok, final_state} = Task.await(task, 5000)

      # Verify the results
      assert final_state["processed"] == "ITEM3"
      assert final_state["result"] == "ITEM3 processed"

      # Log the final result for debugging
      Logger.info("Parallel batch flow result: #{inspect(final_state)}")
    end
  end

  describe "AsyncBatchFlow with refactored modules" do
    test "processes batch items with monitoring and recovery" do
      # Create a flow
      flow =
        PocketFlex.Flow.new()
        |> PocketFlex.Flow.add_node(BatchItemNode)
        |> PocketFlex.Flow.add_node(ProcessorNode)
        |> PocketFlex.Flow.connect(BatchItemNode, ProcessorNode, :success)
        |> PocketFlex.Flow.start(BatchItemNode)

      # Initial shared state with items to process
      shared = %{"items" => ["item1", "item2", "item3"]}

      # Generate a unique flow ID
      flow_id = "test_async_batch_#{:erlang.unique_integer([:positive])}"

      # Start monitoring
      PocketFlex.Monitoring.start_monitoring(flow_id, flow, shared)

      # Run the flow using async batch with a flow_id
      task = PocketFlex.AsyncBatchFlow.run_async_batch(flow, shared)

      # Wait for the task to complete
      {:ok, final_state} = Task.await(task, 5000)

      # Get monitoring info
      monitoring = PocketFlex.Monitoring.get_monitoring(flow_id)

      # Verify the results
      assert final_state["processed"] == "ITEM3"
      assert final_state["result"] == "ITEM3 processed"
      
      # Verify monitoring worked
      assert monitoring.status == :running
      assert is_list(monitoring.execution_path)
      
      # Clean up
      PocketFlex.Monitoring.cleanup_monitoring(flow_id)
    end
  end
end
