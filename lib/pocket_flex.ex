defmodule PocketFlex do
  @moduledoc """
  PocketFlex is an Elixir implementation of a flexible, node-based processing framework.

  It provides a system for creating flows of connected nodes, where each node 
  can process data and pass it to the next node in the flow.

  ## Core Features

  - **Flow-based processing**: Define flows of connected nodes for data processing
  - **Batch processing**: Process multiple items through a flow sequentially
  - **Parallel processing**: Process multiple items through a flow in parallel
  - **Asynchronous execution**: Run flows asynchronously with Task
  - **Error handling**: Comprehensive error handling and recovery mechanisms
  - **State management**: Flexible state storage for flow execution

  ## Documentation

  For more detailed information, visit the [hexdocs.pm documentation](https://hexdocs.pm/pocket_flex).
  """

  require Logger
  alias PocketFlex.ErrorHandler, as: ErrorHandler

  @doc """
  Runs a flow with the given shared state.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  defdelegate run(flow, shared), to: PocketFlex.Flow

  @doc """
  Runs a batch flow with the given shared state.

  The batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow sequentially.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run_batch(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  defdelegate run_batch(flow, shared), to: PocketFlex.BatchFlow

  @doc """
  Runs a parallel batch flow with the given shared state.

  The parallel batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow in parallel.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run_parallel_batch(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  defdelegate run_parallel_batch(flow, shared), to: PocketFlex.ParallelBatchFlow

  @doc """
  Runs a batch flow asynchronously with the given shared state.

  The batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow sequentially but asynchronously.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec run_async_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  defdelegate run_async_batch(flow, shared), to: PocketFlex.AsyncBatchFlow

  @doc """
  Runs a parallel batch flow asynchronously with the given shared state.

  The parallel batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow in parallel and asynchronously.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    - opts: Additional options for parallel execution
      - :max_concurrency - Maximum number of concurrent tasks (default: System.schedulers_online * 2)
      - :timeout - Timeout for each task in milliseconds (default: 30000)
    
  ## Returns
    A Task that will resolve to either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec run_async_parallel_batch(PocketFlex.Flow.t(), map(), keyword()) :: Task.t()
  defdelegate run_async_parallel_batch(flow, shared, opts \\ []),
    to: PocketFlex.AsyncParallelBatchFlow

  @doc """
  Runs a flow asynchronously with the given shared state.

  This function is for compatibility with AsyncNode modules.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec run_async(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async(flow, shared) do
    Task.async(fn ->
      flow_id = "async_flow_#{:erlang.unique_integer([:positive])}"

      try do
        # Start monitoring the flow execution
        ErrorHandler.start_monitoring(flow_id, flow, shared)

        # Initialize state storage with the shared state
        case PocketFlex.StateStorage.update_state(flow_id, shared) do
          {:ok, _} ->
            # Execute the flow using AsyncFlow orchestrator
            result = PocketFlex.AsyncFlow.orchestrate_async(flow, shared)

            # Complete monitoring with the final status
            case result do
              {:ok, final_state} ->
                ErrorHandler.complete_monitoring(flow_id, :completed, final_state)
                {:ok, final_state}

              {:error, reason} ->
                ErrorHandler.complete_monitoring(flow_id, :failed, %{reason: reason})
                {:error, reason}
            end

          {:error, reason} ->
            # Report the error
            error_info =
              ErrorHandler.report_error(reason, :state_initialization, %{flow_id: flow_id})

            # Complete monitoring with failed status
            ErrorHandler.complete_monitoring(flow_id, :failed, %{reason: reason})

            # Return the error
            {:error, error_info}

          shared_state when is_map(shared_state) ->
            # Execute the flow using AsyncFlow orchestrator with the shared state directly
            result = PocketFlex.AsyncFlow.orchestrate_async(flow, shared_state)

            # Complete monitoring with the final status
            case result do
              {:ok, final_state} ->
                ErrorHandler.complete_monitoring(flow_id, :completed, final_state)
                {:ok, final_state}

              {:error, reason} ->
                ErrorHandler.complete_monitoring(flow_id, :failed, %{reason: reason})
                {:error, reason}
            end
        end
      rescue
        error ->
          # Log the error
          error_info =
            ErrorHandler.report_error(error, :flow_orchestration, %{
              flow_id: flow_id,
              stacktrace: __STACKTRACE__
            })

          # Complete monitoring with error status
          ErrorHandler.complete_monitoring(flow_id, :crashed, %{error: error})

          # Return error
          {:error, error_info}
      after
        # Always clean up state storage
        PocketFlex.StateStorage.cleanup(flow_id)
      end
    end)
  end

  # Error Handling Functions

  @doc """
  Reports an error with context information.

  ## Parameters
    - error: The error that occurred
    - context: The context in which the error occurred (e.g., :node_execution, :flow_orchestration)
    - metadata: Additional metadata about the error
    
  ## Returns
    A map containing error information
  """
  @spec report_error(term(), atom(), map()) :: map()
  defdelegate report_error(error, context, metadata \\ %{}), to: ErrorHandler

  # Retry Functions

  @doc """
  Retries a function with configurable retry options.

  See `PocketFlex.Retry.retry/2` for details.
  """
  @spec retry(function(), keyword()) :: any() | {:error, term()}
  defdelegate retry(function, opts \\ []), to: PocketFlex.Retry

  @doc """
  Retries a function with exponential backoff.

  See `PocketFlex.Retry.with_backoff/2` for details.
  """
  @spec with_backoff(function(), keyword()) :: any() | {:error, term()}
  defdelegate with_backoff(function, opts \\ []), to: PocketFlex.Retry

  @doc """
  Retries a function with a circuit breaker pattern.

  See `PocketFlex.Retry.with_circuit_breaker/2` for details.
  """
  @spec with_circuit_breaker(function(), keyword()) :: any() | {:error, term()}
  defdelegate with_circuit_breaker(function, opts \\ []), to: PocketFlex.Retry
end
