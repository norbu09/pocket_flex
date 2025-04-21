defmodule PocketFlex.AsyncFlow do
  @moduledoc """
  Manages the asynchronous execution of connected nodes.

  Extends the basic Flow module with support for asynchronous
  execution using Elixir processes.

  This module provides:
  - Running flows asynchronously with Task
  - Orchestrating flows with async nodes
  - Monitoring flow execution
  - Error handling for async operations

  For implementation details, see:
  - `PocketFlex.AsyncFlow.Executor` - Handles execution of individual nodes
  - `PocketFlex.AsyncFlow.Orchestrator` - Manages flow between nodes
  """

  require Logger
  alias PocketFlex.ErrorHandler
  alias PocketFlex.AsyncFlow.Orchestrator

  @doc """
  Runs the flow asynchronously with the given shared state.

  ## Parameters
    - flow: The flow to run
    - state: The initial shared state
    - opts: Optional parameters for flow execution
    
  ## Returns
    A Task that will resolve to either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec run_async(PocketFlex.Flow.t(), map(), keyword()) :: Task.t()
  def run_async(flow, state, opts \\ []) do
    Task.async(fn -> 
      flow_id = Keyword.get(opts, :flow_id, "async_flow_#{System.unique_integer([:positive])}")
      
      # Start monitoring for this flow
      ErrorHandler.start_monitoring(flow_id, flow, state)
      
      result = try do
        PocketFlex.Flow.run(flow, state)
      rescue
        error ->
          stacktrace = __STACKTRACE__
          ErrorHandler.report_error(error, :async_flow_execution, %{
            flow_id: flow_id,
            stacktrace: stacktrace
          })
      catch
        kind, error ->
          ErrorHandler.report_error(error, :caught_in_async_flow, %{
            flow_id: flow_id,
            kind: kind
          })
      end
      
      # Update monitoring based on result
      case result do
        {:ok, final_state} ->
          ErrorHandler.complete_monitoring(flow_id, :completed, %{
            end_time: DateTime.utc_now(),
            result: :success
          })
          {:ok, final_state}
        
        {:error, _reason} = error ->
          ErrorHandler.complete_monitoring(flow_id, :failed, %{
            end_time: DateTime.utc_now(),
            result: :error,
            error: error
          })
          error
          
        other ->
          error = ErrorHandler.report_error(
            "Unexpected result format from flow execution", 
            :invalid_flow_result, 
            %{flow_id: flow_id, result: other}
          )
          ErrorHandler.complete_monitoring(flow_id, :failed, %{
            end_time: DateTime.utc_now(),
            result: :error,
            error: error
          })
          error
      end
    end)
  end

  @doc """
  Orchestrates the asynchronous execution of a flow with async nodes.

  ## Parameters
    - flow: The flow to run
    - state: The initial shared state
    - opts: Optional parameters for flow execution
    
  ## Returns
    A tuple containing either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec orchestrate_async(PocketFlex.Flow.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def orchestrate_async(flow, state, opts \\ []) do
    flow_id = Keyword.get(opts, :flow_id, "async_orchestration_#{System.unique_integer([:positive])}")
    
    # Start monitoring for this flow
    ErrorHandler.start_monitoring(flow_id, flow, state)
    
    result = try do
      Orchestrator.orchestrate(flow, flow.start_node, state, flow.params, flow_id)
    rescue
      error ->
        stacktrace = __STACKTRACE__
        ErrorHandler.report_error(error, :async_flow_orchestration, %{
          flow_id: flow_id,
          stacktrace: stacktrace
        })
    catch
      kind, error ->
        ErrorHandler.report_error(error, :caught_in_orchestration, %{
          flow_id: flow_id,
          kind: kind
        })
    end
    
    # Update monitoring based on result
    case result do
      {:ok, _final_state} = success ->
        ErrorHandler.complete_monitoring(flow_id, :completed, %{
          end_time: DateTime.utc_now(),
          result: :success
        })
        success
      
      {:error, _reason} = error ->
        ErrorHandler.complete_monitoring(flow_id, :failed, %{
          end_time: DateTime.utc_now(),
          result: :error,
          error: error
        })
        error
    end
  end

  # Flow manipulation functions

  @doc """
  Adds a node to the flow.

  ## Parameters
    - flow: The flow to modify
    - node: The node to add
    
  ## Returns
    The updated flow
  """
  @spec add_node(PocketFlex.Flow.t(), module()) :: PocketFlex.Flow.t()
  defdelegate add_node(flow, node), to: PocketFlex.Flow

  @doc """
  Connects two nodes in the flow.

  ## Parameters
    - flow: The flow to modify
    - from: The source node
    - to: The target node
    - action: The action that triggers this connection (default: :default)
    
  ## Returns
    The updated flow
  """
  @spec connect(PocketFlex.Flow.t(), module(), module(), atom()) :: PocketFlex.Flow.t()
  defdelegate connect(flow, from, to, action \\ :default), to: PocketFlex.Flow

  @doc """
  Sets the start node of the flow.

  ## Parameters
    - flow: The flow to modify
    - node: The node to set as the start node
    
  ## Returns
    The updated flow
  """
  @spec start(PocketFlex.Flow.t(), module()) :: PocketFlex.Flow.t()
  defdelegate start(flow, node), to: PocketFlex.Flow
end
