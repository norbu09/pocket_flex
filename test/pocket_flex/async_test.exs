defmodule PocketFlex.AsyncTest do
  use ExUnit.Case
  require Logger

  describe "async node functionality" do
    defmodule AsyncTestNode do
      use PocketFlex.AsyncNode

      @impl PocketFlex.AsyncNode
      def prep_async(_shared) do
        {:ok, nil}
      end

      @impl PocketFlex.AsyncNode
      def exec_async(_prep_result) do
        task =
          Task.async(fn ->
            Process.sleep(100)
            "ASYNC RESULT"
          end)

        {:ok, task}
      end

      @impl PocketFlex.AsyncNode
      def post_async(shared, _prep_result, exec_result) do
        {:ok, {"default", Map.put(shared, "result", exec_result)}}
      end
    end

    test "async node executes asynchronously" do
      # Create a simple async node instance
      node = AsyncTestNode

      # Run the node asynchronously
      {:ok, task} = node.exec_async(nil)

      # Check that the task is running
      assert is_struct(task, Task)

      # Wait for the task to complete
      result = Task.await(task)

      # Check the result
      assert result == "ASYNC RESULT"
    end
  end

  describe "async flow execution" do
    defmodule AsyncFlowNode1 do
      use PocketFlex.AsyncNode

      @impl PocketFlex.AsyncNode
      def prep_async(shared) do
        {:ok, Map.get(shared, "input")}
      end

      @impl PocketFlex.AsyncNode
      def exec_async(prep_result) do
        task =
          Task.async(fn ->
            Process.sleep(100)
            String.upcase(prep_result)
          end)

        {:ok, task}
      end

      @impl PocketFlex.AsyncNode
      def post_async(shared, _prep_result, exec_result) do
        {:ok, {"default", Map.put(shared, "processed", exec_result)}}
      end
    end

    defmodule AsyncFlowNode2 do
      use PocketFlex.AsyncNode

      @impl PocketFlex.AsyncNode
      def prep_async(shared) do
        {:ok, Map.get(shared, "processed")}
      end

      @impl PocketFlex.AsyncNode
      def exec_async(prep_result) do
        task =
          Task.async(fn ->
            Process.sleep(100)
            "#{prep_result} processed"
          end)

        {:ok, task}
      end

      @impl PocketFlex.AsyncNode
      def post_async(shared, _prep_result, exec_result) do
        {:ok, {nil, Map.put(shared, "result", exec_result)}}
      end
    end

    test "async flow executes nodes in sequence" do
      # Create a flow for async execution
      flow =
        PocketFlex.Flow.new()
        |> PocketFlex.Flow.add_node(AsyncFlowNode1)
        |> PocketFlex.Flow.add_node(AsyncFlowNode2)
        |> PocketFlex.Flow.connect(AsyncFlowNode1, AsyncFlowNode2)
        |> PocketFlex.Flow.start(AsyncFlowNode1)

      # Run the async flow
      task = PocketFlex.run_async(flow, %{"input" => "hello"})

      # Wait for the task to complete
      {:ok, result} = Task.await(task)

      # Check the result
      assert result["processed"] == "HELLO"
      assert result["result"] == "HELLO processed"
    end

    test "async flow with timeout" do
      # Create a flow for async execution
      flow =
        PocketFlex.Flow.new()
        |> PocketFlex.Flow.add_node(AsyncFlowNode1)
        |> PocketFlex.Flow.add_node(AsyncFlowNode2)
        |> PocketFlex.Flow.connect(AsyncFlowNode1, AsyncFlowNode2)
        |> PocketFlex.Flow.start(AsyncFlowNode1)

      # Run the async flow
      task = PocketFlex.run_async(flow, %{"input" => "hello"})

      # Wait for the task to complete with a timeout
      {:ok, result} = Task.await(task, 5000)

      # Check the result
      assert result["processed"] == "HELLO"
      assert result["result"] == "HELLO processed"
    end
  end
end
