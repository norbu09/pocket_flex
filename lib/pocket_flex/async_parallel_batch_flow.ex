defmodule PocketFlex.AsyncParallelBatchFlow do
  @moduledoc """
  Manages the parallel asynchronous execution of batch processing flows.

  This module extends the AsyncBatchFlow with support for processing multiple items
  in parallel. It uses Elixir's Task module to run multiple items concurrently.
  """

  require Logger
  alias PocketFlex.ErrorHandler

  @doc """
  Runs a parallel batch flow asynchronously with the given shared state.

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
  def run_async_parallel_batch(flow, shared, opts \\ []) do
    Task.async(fn -> orchestrate_async_parallel_batch(flow, shared, opts) end)
  end

  @doc """
  Orchestrates the parallel asynchronous execution of a batch flow.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    - opts: Additional options for parallel execution
    
  ## Returns
    A tuple containing either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec orchestrate_async_parallel_batch(PocketFlex.Flow.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def orchestrate_async_parallel_batch(flow, shared, opts \\ []) do
    # Generate a unique flow ID for this execution
    flow_id = "async_parallel_batch_#{:erlang.unique_integer([:positive])}"

    try do
      # Start monitoring the flow execution
      ErrorHandler.start_monitoring(flow_id, flow, shared)

      # Initialize state storage with the shared state
      case PocketFlex.StateStorage.update_state(flow_id, shared) do
        {:ok, _} ->
          # Execute the parallel batch flow
          result =
            try do
              execute_parallel_batch_flow(flow, flow_id, shared, opts)
            catch
              _kind, error ->
                Logger.error("Error in parallel batch flow execution: #{inspect(error)}")
                {:error, error}
            end

          # Complete monitoring with the final status
          case result do
            {:ok, final_state} ->
              ErrorHandler.complete_monitoring(flow_id, :completed, final_state)

            {:error, reason} ->
              ErrorHandler.complete_monitoring(flow_id, :failed, %{reason: reason})
          end

          # Clean up state storage
          PocketFlex.StateStorage.cleanup(flow_id)

          # Return the result
          result

        {:error, reason} ->
          error_info =
            ErrorHandler.report_error(reason, :state_initialization, %{flow_id: flow_id})

          ErrorHandler.complete_monitoring(flow_id, :failed, %{reason: reason})
          {:error, error_info}

        shared_state when is_map(shared_state) ->
          # Try to execute the batch flow with the shared state directly
          result =
            try do
              execute_parallel_batch_flow(flow, flow_id, shared_state, opts)
            catch
              _kind, error ->
                Logger.error("Error in parallel batch flow execution: #{inspect(error)}")
                {:error, error}
            end

          # Complete monitoring with the final status
          case result do
            {:ok, final_state} ->
              ErrorHandler.complete_monitoring(flow_id, :completed, final_state)

            {:error, reason} ->
              ErrorHandler.complete_monitoring(flow_id, :failed, %{reason: reason})
          end

          # Clean up state storage
          PocketFlex.StateStorage.cleanup(flow_id)

          # Return the result
          result
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

        # Clean up state storage
        PocketFlex.StateStorage.cleanup(flow_id)

        # Return error
        {:error, error_info}
    end
  end

  # Execute the parallel batch flow with the start node
  defp execute_parallel_batch_flow(flow, flow_id, state, opts) do
    # Get batch items from the state based on the node type
    batch_items = get_batch_items(flow.start_node, state)

    # Process the batch items
    if is_list(batch_items) do
      process_items_in_parallel(flow, flow_id, batch_items, opts)
    else
      Logger.warning("Batch prep did not return a list. Using the entire result as a single item.")
      process_items_in_parallel(flow, flow_id, [batch_items], opts)
    end
  end

  # Helper function to get batch items based on node type
  defp get_batch_items(node, state) do
    cond do
      # Check if the node is an AsyncBatchNode
      function_exported?(node, :exec_item_async, 1) ->
        node.prep(state)

      # Check if it's a regular AsyncNode
      function_exported?(node, :prep_async, 1) ->
        case node.prep_async(state) do
          {:ok, items} -> items
          {:error, _reason} -> []
          other -> other  # Handle unexpected return values
        end

      # For regular nodes
      true ->
        case prepare_batch_items(node, state) do
          {:ok, items} -> items
          {:error, _reason} -> []
          other -> other  # Handle unexpected return values
        end
    end
  end

  # Prepare the batch items from the start node
  defp prepare_batch_items(node, state) do
    try do
      # Check if the node is an AsyncNode
      if function_exported?(node, :prep_async, 1) do
        # Use the async prep function
        node.prep_async(state)
      else
        # Use the regular NodeRunner prep function
        PocketFlex.NodeRunner.node_prep(node, state)
      end
    rescue
      error ->
        Logger.error("Error in batch preparation: #{inspect(error)}")
        {:error, {:batch_prep_failed, error}}
    end
  end

  # Process items in parallel
  defp process_items_in_parallel(flow, flow_id, items, opts) do
    # Get concurrency options
    _max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online() * 2)
    timeout = Keyword.get(opts, :timeout, 30000)

    # Create tasks for each item
    tasks =
      items
      |> Enum.map(fn item ->
        Task.async(fn ->
          # Get the latest shared state from storage
          current_state = PocketFlex.StateStorage.get_state(flow_id)

          # Create a new shared map with the current batch item
          item_state = Map.put(current_state, "current_batch_item", item)

          # Process the item
          process_single_item(flow, flow_id, item, item_state)
        end)
      end)

    # Wait for all tasks to complete with timeout
    _task_results =
      try do
        Task.await_many(tasks, timeout)
      rescue
        e ->
          Logger.warning("Some parallel tasks timed out or failed: #{inspect(e)}")

          ErrorHandler.update_monitoring(flow_id, flow.start_node, :partial_timeout, %{
            timeout_ms: timeout,
            total_items: length(items)
          })

          # Collect results from completed tasks
          Enum.map(tasks, fn task ->
            try do
              Task.yield(task, 0) || {:error, :timeout}
            catch
              _, _ -> {:error, :task_failed}
            end
          end)
      end

    # Get the final state after processing all items
    final_state = PocketFlex.StateStorage.get_state(flow_id)
    Logger.info("Parallel batch flow result: #{inspect(final_state)}")

    # Check if there's a next node to process
    case Map.get(final_state, :_next_node) do
      nil ->
        # No next node, return the final state
        {:ok, final_state}
        
      next_node ->
        # Remove the _next_node key from the state
        clean_state = Map.delete(final_state, :_next_node)
        
        # Update the state storage with the clean state
        PocketFlex.StateStorage.update_state(flow_id, clean_state)
        
        # Continue the flow execution with the next node
        case PocketFlex.Flow.run_from_node(flow, next_node, clean_state) do
          {:ok, updated_final_state} ->
            # Update the state storage with the final state
            PocketFlex.StateStorage.update_state(flow_id, updated_final_state)
            {:ok, updated_final_state}
            
          {:error, reason} = error ->
            Logger.error("Error continuing flow after parallel batch processing: #{inspect(reason)}")
            error
        end
    end
  end

  # Process a single item and update state
  defp process_single_item(flow, flow_id, item, item_state) do
    # Run the start node with this item
    case PocketFlex.NodeRunner.run_node(flow.start_node, item_state, flow_id) do
      {:ok, action, updated_state} ->
        # Update the shared state in storage by merging
        case PocketFlex.StateStorage.merge_state(flow_id, updated_state) do
          {:error, reason} ->
            Logger.error("Failed to merge state for item #{inspect(item)}: #{inspect(reason)}")
            {:error, :state_merge_failed}

          merged_state ->
            # Get the next node based on the action
            next_node = PocketFlex.Flow.get_next_node(flow, flow.start_node, action)
            
            # Store the next node in the state for later processing
            if next_node do
              # Update the state with the next node information
              PocketFlex.StateStorage.update_state(flow_id, Map.put(merged_state, :_next_node, next_node))
            end
            
            {:ok, merged_state}
        end

      {:error, reason} ->
        Logger.error("Error processing item #{inspect(item)}: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Unexpected error processing item #{inspect(item)}: #{inspect(error)}")
      {:error, {:unexpected_error, error}}
  end
end
