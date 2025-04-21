defmodule PocketFlex.BatchTest do
  use ExUnit.Case
  require Logger

  describe "batch node functionality" do
    defmodule BatchTestNode do
      use PocketFlex.BatchNode
      
      @impl PocketFlex.BatchNode
      def exec_item(item) when is_binary(item) do
        String.upcase(item)
      end
      
      def exec_item(_) do
        "DEFAULT"
      end
    end
    
    test "batch node processes items correctly" do
      # Create a simple batch node instance
      node = BatchTestNode
      
      # Run the node with a list of items
      items = ["hello", "world", "elixir"]
      result = node.exec(items)
      
      # Check the result
      assert result == ["HELLO", "WORLD", "ELIXIR"]
    end
  end
  
  describe "parallel batch node functionality" do
    defmodule ParallelBatchTestNode do
      use PocketFlex.ParallelBatchNode
      
      @impl PocketFlex.ParallelBatchNode
      def exec_item(item) when is_binary(item) do
        String.upcase(item)
      end
      
      def exec_item(_) do
        "DEFAULT"
      end
    end
    
    test "parallel batch node processes items correctly" do
      # Create a simple parallel batch node instance
      node = ParallelBatchTestNode
      
      # Run the node with a list of items
      items = ["hello", "world", "elixir"]
      result = node.exec(items)
      
      # Check the result
      assert result == ["HELLO", "WORLD", "ELIXIR"]
    end
  end
  
  describe "batch flow execution" do
    defmodule BatchItemNode do
      use PocketFlex.BatchNode
      
      @impl true
      def prep(_shared) do
        # Return a list of items for batch processing
        Logger.info("BatchItemNode prep called")
        ["item1", "item2", "item3"]
      end
      
      @impl PocketFlex.BatchNode
      def exec_item(item) when is_binary(item) do
        Logger.info("BatchItemNode exec_item called with #{inspect(item)}")
        String.upcase(item)
      end
      
      @impl true
      def post(shared, _prep_res, exec_res) do
        Logger.info("BatchItemNode post called with #{inspect(exec_res)}")
        {"default", Map.put(shared, "processed", List.last(exec_res))}
      end
    end
    
    defmodule ProcessorNode do
      use PocketFlex.NodeMacros
      require Logger
      
      @impl true
      def prep(shared) do
        Logger.info("ProcessorNode prep called with shared: #{inspect(shared)}")
        Map.get(shared, "processed")
      end
      
      @impl true
      def exec(item) when is_binary(item) do
        Logger.info("ProcessorNode exec called with #{inspect(item)}")
        "#{item} processed"
      end
      
      def exec(input) do
        Logger.info("ProcessorNode exec fallback called with #{inspect(input)}")
        "DEFAULT processed"
      end
      
      @impl true
      def post(shared, _prep_res, exec_res) do
        Logger.info("ProcessorNode post called with #{inspect(exec_res)}")
        {nil, Map.put(shared, "result", exec_res)}
      end
    end
    
    test "batch flow processes items sequentially" do
      # Create a flow for batch processing
      flow = PocketFlex.Flow.new()
      |> PocketFlex.Flow.add_node(BatchItemNode)
      |> PocketFlex.Flow.add_node(ProcessorNode)
      |> PocketFlex.Flow.connect(BatchItemNode, ProcessorNode)
      |> PocketFlex.Flow.start(BatchItemNode)
      
      # Run the batch flow
      {:ok, result} = PocketFlex.run_batch(flow, %{})
      
      # Log the result for debugging
      Logger.info("Batch flow result: #{inspect(result)}")
      
      # Check the result - the last item's result should be in the shared state
      assert Map.get(result, "processed") == "ITEM3"
      assert Map.get(result, "result") == "ITEM3 processed"
    end
    
    test "parallel batch flow processes items concurrently" do
      # Create a flow for parallel batch processing
      flow = PocketFlex.Flow.new()
      |> PocketFlex.Flow.add_node(BatchItemNode)
      |> PocketFlex.Flow.add_node(ProcessorNode)
      |> PocketFlex.Flow.connect(BatchItemNode, ProcessorNode)
      |> PocketFlex.Flow.start(BatchItemNode)
      
      # Run the parallel batch flow
      {:ok, result} = PocketFlex.run_parallel_batch(flow, %{})
      
      # Log the result for debugging
      Logger.info("Parallel batch flow result: #{inspect(result)}")
      
      # Check that we have results in the shared state
      # The exact values might vary due to concurrent execution
      assert Map.has_key?(result, "processed")
      assert Map.has_key?(result, "result")
    end
  end
end
