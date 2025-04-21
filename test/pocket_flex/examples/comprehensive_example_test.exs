defmodule PocketFlex.Examples.ComprehensiveExampleTest do
  use ExUnit.Case, async: true

  alias PocketFlex.Examples.ComprehensiveExample
  alias PocketFlex.Flow

  @input "hello world"

  describe "basic flow and run_example/2" do
    test "create_basic_flow returns a Flow struct" do
      flow = ComprehensiveExample.create_basic_flow()
      assert %Flow{} = flow
    end

    test "run_example processes input correctly" do
      flow = ComprehensiveExample.create_basic_flow()
      {:ok, state} = ComprehensiveExample.run_example(flow, @input)
      assert state["validated_input"] == @input
      assert is_list(state["transformed_data"])
      assert length(state["transformed_data"]) > 0
      assert is_list(state["processed_data"])
      assert Map.has_key?(state, "completed_at")
    end
  end

  describe "run_all_examples/1" do
    test "runs all example flows and returns results" do
      results = ComprehensiveExample.run_all_examples(@input)
      assert is_map(results)

      for key <- [:basic, :conditional, :on, :branch, :helper] do
        assert {:ok, _} = Map.fetch!(results, key)
      end
    end
  end
end
