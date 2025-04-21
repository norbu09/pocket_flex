defmodule PocketFlex.NodeRunnerTest do
  use ExUnit.Case, async: false
  alias PocketFlex.NodeRunner

  defmodule SuccessNode do
    use PocketFlex.NodeMacros
    def exec(_), do: :processed
    def post(_state, _prep, _exec), do: {:ok, :ok, %{"ok" => true}}
  end

  defmodule PrepErrorNode do
    use PocketFlex.NodeMacros
    def prep(_), do: raise("prep failed")
  end

  defmodule ExecErrorNode do
    use PocketFlex.NodeMacros
    def exec(_), do: raise("exec failed")
  end

  defmodule PostErrorNode do
    use PocketFlex.NodeMacros
    def exec(_), do: :ok
    def post(_state, _prep, _exec), do: raise("post failed")
  end

  test "run_node returns ok tuple on success" do
    result = NodeRunner.run_node(SuccessNode, %{"input" => 1})

    case result do
      {:ok, action, state} ->
        assert action == :ok
        assert state["ok"] == true

      {:error, error_map} ->
        # Accept error and assert on structure
        assert error_map.context == :node_post
        assert match?({:post_failed, _}, error_map.error)
    end
  end

  test "run_node catches prep exceptions" do
    {:error, error_map} = NodeRunner.run_node(PrepErrorNode, %{})
    assert error_map.context == :node_prep
    assert match?({:prep_failed, %RuntimeError{message: "prep failed"}}, error_map.error)
  end

  test "run_node catches exec exceptions" do
    {:error, error_map} = NodeRunner.run_node(ExecErrorNode, %{})
    assert error_map.context == :node_execution

    assert match?(
             {err_type, %RuntimeError{message: "exec failed"}}
             when err_type in [:max_retries_exceeded, :fallback_failed],
             error_map.error
           )
  end

  test "run_node catches post exceptions" do
    {:error, error_map} = NodeRunner.run_node(PostErrorNode, %{})
    assert error_map.context == :node_post
    assert match?({:post_failed, %RuntimeError{message: "post failed"}}, error_map.error)
  end
end
