defmodule PocketFlex.AsyncFlow.OrchestratorTest do
  use ExUnit.Case, async: false
  require Logger

  alias PocketFlex.AsyncFlow.Orchestrator

  # Define test nodes for the flow
  defmodule StartNode do
    use PocketFlex.NodeMacros

    def prep(state), do: state
    def exec(data), do: data

    def post(state, _prep_res, _exec_res) do
      # Return branch action if branch_action is set in the state
      action = Map.get(state, :branch_action, :success)
      {action, Map.put(state, :start_processed, true)}
    end
  end

  defmodule MiddleNode do
    use PocketFlex.NodeMacros

    def prep(state), do: state
    def exec(data), do: data
    def post(state, _prep_res, _exec_res), do: {:success, Map.put(state, :middle_processed, true)}
  end

  defmodule EndNode do
    use PocketFlex.NodeMacros

    def prep(state), do: state
    def exec(data), do: data
    def post(state, _prep_res, _exec_res), do: {:success, Map.put(state, :end_processed, true)}
  end

  defmodule BranchNode do
    use PocketFlex.NodeMacros

    def prep(state), do: state
    def exec(data), do: data

    def post(state, _prep_res, _exec_res) do
      # Connect to EndNode by returning success
      {:success, Map.put(state, :branch_processed, true)}
    end
  end

  setup do
    # Create a simple test flow
    flow =
      PocketFlex.Flow.new()
      |> PocketFlex.Flow.add_node(StartNode)
      |> PocketFlex.Flow.add_node(MiddleNode)
      |> PocketFlex.Flow.add_node(EndNode)
      |> PocketFlex.Flow.add_node(BranchNode)
      |> PocketFlex.Flow.connect(StartNode, MiddleNode, :success)
      |> PocketFlex.Flow.connect(MiddleNode, EndNode, :success)
      |> PocketFlex.Flow.connect(StartNode, BranchNode, :branch)
      |> PocketFlex.Flow.connect(BranchNode, EndNode, :success)
      |> PocketFlex.Flow.start(StartNode)

    # Generate a unique flow ID for this test
    flow_id = "test_flow_#{:erlang.unique_integer([:positive])}"

    # Return the context
    {:ok, %{flow: flow, flow_id: flow_id}}
  end

  describe "orchestrate function" do
    test "orchestrates a simple flow successfully", %{flow: flow, flow_id: flow_id} do
      # Initial state
      state = %{test: true}

      # Run the orchestrator
      {:ok, final_state} = Orchestrator.orchestrate(flow, flow.start_node, state, %{}, flow_id)

      # Verify all nodes were processed in order
      assert final_state.start_processed == true
      assert final_state.middle_processed == true
      assert final_state.end_processed == true
    end

    test "handles branching based on action", %{flow: flow, flow_id: flow_id} do
      # Initial state with branch action
      state = %{test: true, branch_action: :branch}

      # Run the orchestrator with a state that will cause branching
      {:ok, final_state} = Orchestrator.orchestrate(flow, StartNode, state, %{}, flow_id)

      # Verify the branch was taken
      assert final_state.start_processed == true
      assert Map.get(final_state, :branch_processed) == true
      # EndNode should be executed after BranchNode
      assert Map.get(final_state, :end_processed) == true
      # The MiddleNode should not be executed when branching
      assert Map.get(final_state, :middle_processed) == nil
    end

    test "handles nil node gracefully", %{flow_id: flow_id} do
      # Initial state
      state = %{test: true}

      # Run the orchestrator with nil node
      {:ok, final_state} = Orchestrator.orchestrate(nil, nil, state, %{}, flow_id)

      # Verify the state is returned unchanged
      assert final_state == state
    end

    test "get_next_node finds the correct next node", %{flow: flow} do
      # Test with specific action
      next_node = Orchestrator.get_next_node(flow, StartNode, :success)
      assert next_node == MiddleNode

      # Test with branch action
      next_node = Orchestrator.get_next_node(flow, StartNode, :branch)
      assert next_node == BranchNode

      # Test with default action (should not be found in this flow)
      next_node = Orchestrator.get_next_node(flow, StartNode, :default)
      assert next_node == nil

      # Test with non-existent action
      next_node = Orchestrator.get_next_node(flow, StartNode, :nonexistent)
      assert next_node == nil
    end
  end

  describe "error handling" do
    test "handles node errors gracefully", %{flow_id: flow_id} do
      # Define a failing node
      defmodule FailingNode do
        use PocketFlex.NodeMacros

        def prep(_state), do: raise("Simulated failure")
        def exec(data), do: data
        def post(state, _prep_res, _exec_res), do: {:success, state}
      end

      # Create a flow with the failing node
      failing_flow =
        PocketFlex.Flow.new()
        |> PocketFlex.Flow.add_node(FailingNode)
        |> PocketFlex.Flow.start(FailingNode)

      # Initial state
      state = %{test: true}

      # Run the orchestrator with the failing flow
      result =
        Orchestrator.orchestrate(failing_flow, failing_flow.start_node, state, %{}, flow_id)

      # Verify the error has the expected structure from ErrorHandler
      assert match?({:error, %{context: :node_prep, error: {:prep_failed, _}}}, result)
    end
  end
end
