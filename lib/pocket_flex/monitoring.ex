defmodule PocketFlex.Monitoring do
  @moduledoc """
  Provides monitoring capabilities for PocketFlex flows.

  This module handles tracking and reporting on flow execution, including:
  - Starting monitoring for a flow
  - Updating monitoring state during execution
  - Recording errors that occur during flow execution
  - Completing monitoring when a flow finishes
  - Retrieving monitoring information
  - Cleaning up monitoring data

  ## Telemetry Integration

  This module is designed to be extended with telemetry integration in the future.
  Each monitoring function will emit telemetry events that can be consumed by
  telemetry handlers.
  """

  require Logger

  @doc """
  Starts monitoring a flow execution.

  ## Parameters
    - flow_id: The ID of the flow to monitor
    - flow: The flow being executed
    - initial_state: The initial state of the flow

  ## Returns
    - `:ok`
  """
  @spec start_monitoring(String.t(), PocketFlex.Flow.t(), map()) :: :ok
  def start_monitoring(flow_id, flow, initial_state) do
    metadata = %{
      flow_id: flow_id,
      flow_name: Map.get(flow.params, :name, "unnamed_flow"),
      start_time: DateTime.utc_now(),
      node_count: map_size(flow.nodes),
      start_node: flow.start_node
    }

    Logger.metadata(flow_id: flow_id)
    
    Logger.info("Starting flow execution", metadata: metadata)
    
    # Store monitoring data
    PocketFlex.StateStorage.update_state(
      "monitor_#{flow_id}",
      %{
        metadata: metadata,
        status: :running,
        current_node: flow.start_node,
        execution_path: [],
        errors: [],
        start_time: DateTime.utc_now(),
        initial_state: initial_state
      }
    )
    
    # Future telemetry integration point
    # :telemetry.execute(
    #   [:pocket_flex, :flow, :start],
    #   %{system_time: System.system_time()},
    #   metadata
    # )
    
    :ok
  end

  @doc """
  Updates monitoring information for a flow execution.

  ## Parameters
    - flow_id: The ID of the flow being monitored
    - current_node: The current node being executed
    - status: The current status of the flow
    - metadata: Additional metadata to store

  ## Returns
    - `:ok`
  """
  @spec update_monitoring(String.t(), module(), atom(), map()) :: :ok
  def update_monitoring(flow_id, current_node, status, metadata \\ %{}) do
    monitor_id = "monitor_#{flow_id}"
    
    case PocketFlex.StateStorage.get_state(monitor_id) do
      %{} = monitor_state ->
        execution_path = [current_node | Map.get(monitor_state, :execution_path, [])]
        
        updated_state = monitor_state
          |> Map.put(:current_node, current_node)
          |> Map.put(:status, status)
          |> Map.put(:execution_path, execution_path)
          |> Map.put(:last_updated, DateTime.utc_now())
          |> Map.update(:metadata, metadata, &Map.merge(&1, metadata))
        
        PocketFlex.StateStorage.update_state(monitor_id, updated_state)
        
        # Future telemetry integration point
        # :telemetry.execute(
        #   [:pocket_flex, :flow, :update],
        #   %{system_time: System.system_time()},
        #   %{flow_id: flow_id, current_node: current_node, status: status}
        # )
        
      _ ->
        Logger.warning("Attempted to update monitoring for unknown flow: #{flow_id}")
    end
    
    :ok
  end

  @doc """
  Records an error in the flow monitoring.

  ## Parameters
    - flow_id: The ID of the flow being monitored
    - error: The error that occurred
    - node: The node where the error occurred
    - metadata: Additional metadata about the error

  ## Returns
    - `:ok`
  """
  @spec record_error(String.t(), term(), module(), map()) :: :ok
  def record_error(flow_id, error, node, metadata \\ %{}) do
    monitor_id = "monitor_#{flow_id}"
    
    error_entry = %{
      error: error,
      node: node,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
    
    case PocketFlex.StateStorage.get_state(monitor_id) do
      %{} = monitor_state ->
        errors = [error_entry | Map.get(monitor_state, :errors, [])]
        
        updated_state = monitor_state
          |> Map.put(:errors, errors)
          |> Map.put(:last_error, error_entry)
          |> Map.put(:status, :error)
        
        PocketFlex.StateStorage.update_state(monitor_id, updated_state)
        
        # Future telemetry integration point
        # :telemetry.execute(
        #   [:pocket_flex, :flow, :error],
        #   %{system_time: System.system_time()},
        #   %{flow_id: flow_id, error: error, node: node}
        # )
        
      _ ->
        Logger.warning("Attempted to record error for unknown flow: #{flow_id}")
    end
    
    :ok
  end

  @doc """
  Completes monitoring for a flow execution.

  ## Parameters
    - flow_id: The ID of the flow being monitored
    - status: The final status of the flow
    - result: The result of the flow execution

  ## Returns
    - `:ok`
  """
  @spec complete_monitoring(String.t(), atom(), map()) :: :ok
  def complete_monitoring(flow_id, status, result) do
    monitor_id = "monitor_#{flow_id}"
    
    case PocketFlex.StateStorage.get_state(monitor_id) do
      %{} = monitor_state ->
        start_time = Map.get(monitor_state, :start_time, DateTime.utc_now())
        end_time = DateTime.utc_now()
        duration = DateTime.diff(end_time, start_time, :millisecond)
        
        updated_state = monitor_state
          |> Map.put(:status, status)
          |> Map.put(:end_time, end_time)
          |> Map.put(:duration_ms, duration)
          |> Map.put(:result, result)
        
        PocketFlex.StateStorage.update_state(monitor_id, updated_state)
        
        metadata = %{
          flow_id: flow_id, 
          status: status,
          duration_ms: duration,
          error_count: length(Map.get(monitor_state, :errors, []))
        }
        
        Logger.info("Flow execution completed", metadata: metadata)
        
        # Future telemetry integration point
        # :telemetry.execute(
        #   [:pocket_flex, :flow, :complete],
        #   %{system_time: System.system_time(), duration: duration},
        #   metadata
        # )
        
      _ ->
        Logger.warning("Attempted to complete monitoring for unknown flow: #{flow_id}")
    end
    
    :ok
  end

  @doc """
  Gets monitoring information for a flow.

  ## Parameters
    - flow_id: The ID of the flow to get monitoring information for

  ## Returns
    - The monitoring state if found
    - An empty map if not found
  """
  @spec get_monitoring(String.t()) :: map()
  def get_monitoring(flow_id) do
    monitor_id = "monitor_#{flow_id}"
    PocketFlex.StateStorage.get_state(monitor_id)
  end

  @doc """
  Cleans up monitoring data for a flow.

  ## Parameters
    - flow_id: The ID of the flow to clean up monitoring data for

  ## Returns
    - `:ok`
  """
  @spec cleanup_monitoring(String.t()) :: :ok
  def cleanup_monitoring(flow_id) do
    monitor_id = "monitor_#{flow_id}"
    PocketFlex.StateStorage.cleanup(monitor_id)
    :ok
  end
end
