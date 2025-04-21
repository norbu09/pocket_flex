defmodule PocketFlex.MonitoringTest do
  use ExUnit.Case
  require Logger

  alias PocketFlex.Monitoring

  # Define a simple test flow and nodes
  defmodule TestNode1 do
    use PocketFlex.NodeMacros

    def prep(state), do: state
    def exec(data), do: data
    def post(state, _prep_res, _exec_res), do: {:success, Map.put(state, :node1_processed, true)}
  end

  defmodule TestNode2 do
    use PocketFlex.NodeMacros

    def prep(state), do: state
    def exec(data), do: data
    def post(state, _prep_res, _exec_res), do: {:success, Map.put(state, :node2_processed, true)}
  end

  setup do
    # Create a simple test flow
    flow =
      PocketFlex.Flow.new()
      |> PocketFlex.Flow.add_node(TestNode1)
      |> PocketFlex.Flow.add_node(TestNode2)
      |> PocketFlex.Flow.connect(TestNode1, TestNode2, :success)
      |> PocketFlex.Flow.start(TestNode1)

    # Generate a unique flow ID for this test
    flow_id = "test_flow_#{:erlang.unique_integer([:positive])}"

    # Return the context
    %{flow: flow, flow_id: flow_id}
  end

  describe "flow monitoring" do
    test "start_monitoring initializes monitoring state", %{flow: flow, flow_id: flow_id} do
      initial_state = %{test: true}
      
      # Start monitoring
      :ok = Monitoring.start_monitoring(flow_id, flow, initial_state)
      
      # Get the monitoring state
      monitor_state = Monitoring.get_monitoring(flow_id)
      
      # Verify the monitoring state was initialized correctly
      assert monitor_state.status == :running
      assert monitor_state.current_node == flow.start_node
      assert monitor_state.execution_path == []
      assert monitor_state.errors == []
      assert monitor_state.metadata.flow_id == flow_id
      assert monitor_state.initial_state == initial_state
      
      # Clean up
      Monitoring.cleanup_monitoring(flow_id)
    end

    test "update_monitoring updates the monitoring state", %{flow: flow, flow_id: flow_id} do
      initial_state = %{test: true}
      
      # Start monitoring
      :ok = Monitoring.start_monitoring(flow_id, flow, initial_state)
      
      # Update monitoring with a new node and status
      :ok = Monitoring.update_monitoring(flow_id, TestNode2, :processing, %{custom: "metadata"})
      
      # Get the updated monitoring state
      monitor_state = Monitoring.get_monitoring(flow_id)
      
      # Verify the monitoring state was updated correctly
      assert monitor_state.status == :processing
      assert monitor_state.current_node == TestNode2
      assert monitor_state.execution_path == [TestNode2]
      assert Map.get(monitor_state.metadata, :custom) == "metadata"
      
      # Clean up
      Monitoring.cleanup_monitoring(flow_id)
    end

    test "record_error adds an error to the monitoring state", %{flow: flow, flow_id: flow_id} do
      initial_state = %{test: true}
      
      # Start monitoring
      :ok = Monitoring.start_monitoring(flow_id, flow, initial_state)
      
      # Record an error
      error = "Test error"
      :ok = Monitoring.record_error(flow_id, error, TestNode1)
      
      # Get the updated monitoring state
      monitor_state = Monitoring.get_monitoring(flow_id)
      
      # Verify the error was recorded correctly
      assert monitor_state.status == :error
      assert length(monitor_state.errors) == 1
      assert hd(monitor_state.errors).error == error
      assert hd(monitor_state.errors).node == TestNode1
      assert monitor_state.last_error.error == error
      
      # Clean up
      Monitoring.cleanup_monitoring(flow_id)
    end

    test "complete_monitoring finalizes the monitoring state", %{flow: flow, flow_id: flow_id} do
      initial_state = %{test: true}
      
      # Start monitoring
      :ok = Monitoring.start_monitoring(flow_id, flow, initial_state)
      
      # Complete monitoring
      result = %{final: true}
      :ok = Monitoring.complete_monitoring(flow_id, :completed, result)
      
      # Get the updated monitoring state
      monitor_state = Monitoring.get_monitoring(flow_id)
      
      # Verify the monitoring state was completed correctly
      assert monitor_state.status == :completed
      assert monitor_state.result == result
      assert monitor_state.end_time != nil
      assert monitor_state.duration_ms != nil
      
      # Clean up
      Monitoring.cleanup_monitoring(flow_id)
    end

    test "cleanup_monitoring removes the monitoring state", %{flow: flow, flow_id: flow_id} do
      initial_state = %{test: true}
      
      # Start monitoring
      :ok = Monitoring.start_monitoring(flow_id, flow, initial_state)
      
      # Verify the monitoring state exists
      assert Monitoring.get_monitoring(flow_id) != %{}
      
      # Clean up
      :ok = Monitoring.cleanup_monitoring(flow_id)
      
      # Verify the monitoring state was removed
      assert Monitoring.get_monitoring(flow_id) == %{}
    end
  end
end
