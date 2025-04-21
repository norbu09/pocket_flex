defmodule PocketFlex.AsyncFlow.Executor do
  @moduledoc """
  Handles the execution of asynchronous nodes within a flow.

  This module provides functionality for executing individual nodes
  asynchronously and handling their results.
  """

  require Logger
  alias PocketFlex.ErrorHandler

  @doc """
  Executes a node asynchronously or synchronously based on its type.

  ## Parameters
    - current_node: The node to execute
    - state: The current state
    - flow_id: The ID of the flow being executed
    
  ## Returns
    A tuple containing:
    - :ok, the action, and the updated state, or
    - :error and a reason
  """
  @spec execute_node(module(), map(), String.t()) :: 
    {:ok, atom(), map()} | {:error, term()}
  def execute_node(current_node, state, flow_id) do
    # Run the node asynchronously if it's an AsyncNode, otherwise run it synchronously
    if function_exported?(current_node, :prep_async, 1) do
      Logger.debug("Running async node: #{inspect(current_node)}")
      
      # Execute the async node using the async callbacks with proper error handling
      with {:ok, prep_result} <- current_node.prep_async(state),
           {:ok, task_or_result} <- current_node.exec_async(prep_result),
           # If the result is a Task, await it
           exec_result <- get_exec_result(task_or_result),
           # Process the post callback
           {:ok, {action, updated_state}} <- current_node.post_async(state, prep_result, exec_result) do
        # Return the result in the format expected by the flow orchestrator
        {:ok, action, updated_state}
      else
        {:error, reason} ->
          ErrorHandler.report_error(reason, :async_node_execution, %{
            flow_id: flow_id,
            node: current_node
          })
        
        error ->
          ErrorHandler.report_error(error, :unexpected_async_node_error, %{
            flow_id: flow_id,
            node: current_node
          })
      end
    else
      Logger.debug("Running sync node in async flow: #{inspect(current_node)}")
      PocketFlex.NodeRunner.run_node(current_node, state)
    end
  end

  @doc """
  Gets the result from a Task or returns the result directly.

  ## Parameters
    - task_or_result: Either a Task or a direct result
    
  ## Returns
    The result
  """
  @spec get_exec_result(Task.t() | term()) :: term()
  def get_exec_result(%Task{} = task), do: Task.await(task)
  def get_exec_result(result), do: result

  @doc """
  Handles errors that occur during node execution.

  ## Parameters
    - error: The error that occurred
    - current_node: The node where the error occurred
    - flow_id: The ID of the flow being executed
    
  ## Returns
    An error tuple
  """
  @spec handle_node_error(term(), module(), String.t()) :: {:error, term()}
  def handle_node_error(error, current_node, flow_id) do
    stacktrace = Process.info(self(), :current_stacktrace)
    
    ErrorHandler.report_error(error, :node_execution, %{
      flow_id: flow_id,
      node: current_node,
      stacktrace: stacktrace
    })
  end

  @doc """
  Handles errors that occur during flow orchestration.

  ## Parameters
    - error: The error that occurred
    - flow_id: The ID of the flow being executed
    
  ## Returns
    An error tuple
  """
  @spec handle_flow_error(term(), String.t()) :: {:error, term()}
  def handle_flow_error(error, flow_id) do
    stacktrace = Process.info(self(), :current_stacktrace)
    
    ErrorHandler.report_error(error, :flow_orchestration, %{
      flow_id: flow_id,
      stacktrace: stacktrace
    })
  end
end
