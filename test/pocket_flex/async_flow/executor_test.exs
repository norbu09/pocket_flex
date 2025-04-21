defmodule PocketFlex.AsyncFlow.ExecutorTest do
  use ExUnit.Case, async: false
  require Logger

  alias PocketFlex.AsyncFlow.Executor

  setup do
    flow_id = "test_flow_#{:erlang.unique_integer([:positive])}"
    {:ok, %{flow_id: flow_id}}
  end

  defmodule SyncNode do
    use PocketFlex.NodeMacros

    def prep(state), do: Map.get(state, :input, "default")
    def exec(data), do: String.upcase(data)
    def post(state, _prep_res, exec_res), do: {:success, Map.put(state, :result, exec_res)}
  end

  defmodule AsyncNode do
    use PocketFlex.AsyncNode

    def prep_async(state) do
      {:ok, Map.get(state, :input, "default")}
    end

    def exec_async(data) do
      task = Task.async(fn -> String.upcase(data) end)
      {:ok, task}
    end

    def post_async(state, _prep_res, exec_res) do
      {:ok, {:success, Map.put(state, :result, exec_res)}}
    end
  end

  defmodule DirectAsyncNode do
    use PocketFlex.AsyncNode

    def prep_async(state) do
      {:ok, Map.get(state, :input, "default")}
    end

    def exec_async(data) do
      {:ok, String.upcase(data)}
    end

    def post_async(state, _prep_res, exec_res) do
      {:ok, {:success, Map.put(state, :result, exec_res)}}
    end
  end

  defmodule FailingPrepAsyncNode do
    def prep_async(_state) do
      {:error, "Prep failed"}
    end

    def exec_async(_data), do: {:ok, "won't run"}
    def post_async(state, _, _), do: {:ok, {:success, state}}
  end

  defmodule FailingExecAsyncNode do
    use PocketFlex.AsyncNode

    def prep_async(state), do: {:ok, state}
    def exec_async(_prep_result), do: {:error, "Exec failed"}

    def post_async(state, _, _),
      do: {:error, %{context: :async_node_execution, error: "Post failed"}}
  end

  defmodule FailingPostAsyncNode do
    use PocketFlex.AsyncNode

    def prep_async(state), do: {:ok, state}
    def exec_async(prep_result), do: {:ok, prep_result}

    def post_async(_state, _prep_res, _exec_res),
      do: {:error, %{context: :async_node_execution, error: "Post failed"}}
  end

  describe "execute_node function" do
    test "executes a synchronous node correctly", %{flow_id: flow_id} do
      state = %{input: "test"}
      result = Executor.execute_node(SyncNode, state, flow_id)
      assert match?({:ok, :success, %{result: "TEST"}}, result)
    end

    test "executes an asynchronous node with task correctly", %{flow_id: flow_id} do
      state = %{input: "test"}
      result = Executor.execute_node(AsyncNode, state, flow_id)
      assert match?({:ok, :success, %{result: "TEST"}}, result)
    end

    test "executes an asynchronous node with direct result correctly", %{flow_id: flow_id} do
      state = %{input: "test"}
      result = Executor.execute_node(DirectAsyncNode, state, flow_id)
      assert match?({:ok, :success, %{result: "TEST"}}, result)
    end

    test "handles prep_async errors correctly", %{flow_id: flow_id} do
      state = %{input: "test"}
      result = Executor.execute_node(FailingPrepAsyncNode, state, flow_id)

      case result do
        {:error, %{context: :async_node_execution, error: err}} ->
          assert is_binary(err) or match?(%RuntimeError{}, err) or
                   (is_map(err) and Map.has_key?(err, :context) and Map.has_key?(err, :error))

        _ ->
          flunk("Unexpected error result: #{inspect(result)}")
      end
    end

    test "handles exec_async errors correctly", %{flow_id: flow_id} do
      state = %{input: "test"}
      result = Executor.execute_node(FailingExecAsyncNode, state, flow_id)

      case result do
        {:error, %{context: :async_node_execution, error: err}} ->
          assert is_binary(err) or match?(%RuntimeError{}, err) or
                   (is_map(err) and Map.has_key?(err, :context) and Map.has_key?(err, :error))

        _ ->
          flunk("Unexpected error result: #{inspect(result)}")
      end
    end

    test "handles post_async errors correctly", %{flow_id: flow_id} do
      state = %{input: "test"}
      result = Executor.execute_node(FailingPostAsyncNode, state, flow_id)

      case result do
        {:error, %{context: :async_node_execution, error: err}} ->
          assert is_binary(err) or match?(%RuntimeError{}, err) or
                   (is_map(err) and Map.has_key?(err, :context) and Map.has_key?(err, :error))

        _ ->
          flunk("Unexpected error result: #{inspect(result)}")
      end
    end
  end

  describe "get_exec_result function" do
    test "awaits a task and returns its result" do
      task = Task.async(fn -> "task result" end)
      result = Executor.get_exec_result(task)
      assert result == "task result"
    end

    test "returns non-task values directly" do
      assert Executor.get_exec_result("direct result") == "direct result"
      assert Executor.get_exec_result(123) == 123
      assert Executor.get_exec_result(%{key: "value"}) == %{key: "value"}
    end
  end

  describe "error handling" do
    test "handle_node_error creates an error report", %{flow_id: flow_id} do
      error = %RuntimeError{message: "Test error"}
      result = Executor.handle_node_error(error, SyncNode, flow_id)

      assert match?(
               {:error, %{context: :node_execution, error: %RuntimeError{message: "Test error"}}},
               result
             )
    end

    test "handle_flow_error creates an error report", %{flow_id: flow_id} do
      error = %RuntimeError{message: "Test error"}
      result = Executor.handle_flow_error(error, flow_id)

      assert match?(
               {:error,
                %{context: :flow_orchestration, error: %RuntimeError{message: "Test error"}}},
               result
             )
    end
  end
end
