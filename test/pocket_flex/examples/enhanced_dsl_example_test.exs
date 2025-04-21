defmodule PocketFlex.Examples.EnhancedDSLExampleTest do
  use ExUnit.Case, async: true

  alias PocketFlex.Examples.EnhancedDSLExample
  alias PocketFlex.Flow

  @input "test input"

  describe "create_basic_flow and run_example/2" do
    test "create_basic_flow returns a Flow struct" do
      flow = EnhancedDSLExample.create_basic_flow()
      assert %Flow{} = flow
    end

    test "run_example processes input correctly" do
      flow = EnhancedDSLExample.create_basic_flow()
      {:ok, state} = EnhancedDSLExample.run_example(flow, @input)
      assert state["completed"] == true
    end
  end

  describe "create_conditional_flow" do
    test "processes valid input" do
      flow = EnhancedDSLExample.create_conditional_flow()
      {:ok, state} = EnhancedDSLExample.run_example(flow, @input)
      assert state["completed"] == true
    end

    test "handles invalid input" do
      flow = EnhancedDSLExample.create_conditional_flow()
      {:ok, state} = EnhancedDSLExample.run_example(flow, "")
      assert state["error_handled"] == true
    end
  end

  describe "create_flow_with_on" do
    test "processes valid input" do
      flow = EnhancedDSLExample.create_flow_with_on()
      {:ok, state} = EnhancedDSLExample.run_example(flow, @input)
      assert state["completed"] == true
    end

    test "handles invalid input" do
      flow = EnhancedDSLExample.create_flow_with_on()
      {:ok, state} = EnhancedDSLExample.run_example(flow, "")
      assert state["error_handled"] == true
    end
  end

  describe "create_flow_with_branch" do
    test "processes valid input" do
      flow = EnhancedDSLExample.create_flow_with_branch()
      {:ok, state} = EnhancedDSLExample.run_example(flow, @input)
      assert state["completed"] == true
    end

    test "handles invalid input" do
      flow = EnhancedDSLExample.create_flow_with_branch()
      {:ok, state} = EnhancedDSLExample.run_example(flow, "")
      assert state["error_handled"] == true
    end
  end

  describe "create_flow_with_helpers" do
    test "processes valid input" do
      flow = EnhancedDSLExample.create_flow_with_helpers()
      {:ok, state} = EnhancedDSLExample.run_example(flow, @input)
      assert state["completed"] == true
    end

    test "handles invalid input" do
      flow = EnhancedDSLExample.create_flow_with_helpers()
      {:ok, state} = EnhancedDSLExample.run_example(flow, "")
      assert state["error_handled"] == true
    end
  end

  describe "run_all_examples/1" do
    test "runs all example flows and returns results" do
      results = EnhancedDSLExample.run_all_examples(@input)
      assert is_map(results)

      for key <- [:basic, :conditional, :on, :branch, :helper] do
        assert {:ok, _} = Map.fetch!(results, key)
      end
    end
  end
end
