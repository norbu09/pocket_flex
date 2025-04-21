defmodule PocketFlex.AsyncFlowTest do
  use ExUnit.Case, async: false
  alias PocketFlex.AsyncFlow
  alias PocketFlex.Flow

  defmodule DummyNode do
    use PocketFlex.NodeMacros
    def exec(_), do: 42
    def post(_state, _prep, result), do: {:done, %{value: result}}
  end

  defmodule FailNode do
    use PocketFlex.NodeMacros
    def exec(_), do: raise("fail")
  end

  setup_all do
    # Ensure ETS is started for async flow tests
    try do
      :ets.delete(:pocket_flex_shared_state)
    rescue
      _ -> :ok
    end

    case PocketFlex.StateStorage.ETS.start_link(nil) do
      {:ok, _} ->
        :ok

      {:error, {:already_started, _}} ->
        :ok

      other ->
        IO.inspect(other, label: "ETS.start_link/1 unexpected result")
        :ok
    end

    :ok
  end

  test "run_async returns a Task that resolves to ok result" do
    flow = Flow.new() |> Flow.start(DummyNode)
    task = AsyncFlow.run_async(flow, %{})
    assert {:ok, %{value: 42}} = Task.await(task)
  end

  test "orchestrate_async handles execution errors" do
    flow = Flow.new() |> Flow.start(FailNode)
    {:error, _} = AsyncFlow.orchestrate_async(flow, %{}, flow_id: "test_flow")
  end
end
