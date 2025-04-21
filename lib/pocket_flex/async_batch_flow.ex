defmodule PocketFlex.AsyncBatchFlow do
  @moduledoc """
  Manages the asynchronous execution of batch processing flows in PocketFlex.

  This module provides:
  - Running flows asynchronously with batch processing capabilities
  - Tuple-based error handling (`{:ok, ...}`/`{:error, ...}`) for all operations
  - Atoms for all action keys (e.g., `:default`, `:success`, `:error`)
  - Never overwrites shared state with a raw value
  - Monitoring and state storage integration

  ## Best Practices

  - Use pattern matching in function heads
  - Document all public functions and modules
  - See the guides for error handling, monitoring, and migration notes
  """

  require Logger
  alias PocketFlex.ErrorHandler

  @doc """
  Runs a batch flow asynchronously with the given shared state.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec run_async_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async_batch(flow, shared) do
    Task.async(fn -> orchestrate_async_batch(flow, shared) end)
  end

  @doc """
  Orchestrates the asynchronous execution of a batch flow.

  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec orchestrate_async_batch(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  def orchestrate_async_batch(flow, shared) do
    # Generate a unique flow ID for this execution
    flow_id = "async_batch_#{:erlang.unique_integer([:positive])}"

    # Start monitoring the flow execution
    ErrorHandler.start_monitoring(flow_id, flow, shared)

    # Initialize state storage with the shared state
    with {:ok, _} <- PocketFlex.StateStorage.update_state(flow_id, shared),
         {:ok, final_state} <- execute_batch_flow(flow, flow_id, shared) do
      # Complete monitoring with success status
      ErrorHandler.complete_monitoring(flow_id, :completed, %{
        end_time: DateTime.utc_now(),
        result: :success
      })

      # Clean up state storage
      PocketFlex.StateStorage.cleanup(flow_id)

      # Return success
      {:ok, final_state}
    else
      {:error, reason} = error ->
        # Log the error
        Logger.error("Error in async batch flow: #{inspect(reason)}")

        # Complete monitoring with failed status
        ErrorHandler.complete_monitoring(flow_id, :failed, %{
          end_time: DateTime.utc_now(),
          result: :error,
          error: reason
        })

        # Clean up state storage
        PocketFlex.StateStorage.cleanup(flow_id)

        # Return the error
        error

      shared_state when is_map(shared_state) ->
        # Try to execute the batch flow with the shared state directly
        case execute_batch_flow(flow, flow_id, shared_state) do
          {:ok, final_state} ->
            # Complete monitoring with success status
            ErrorHandler.complete_monitoring(flow_id, :completed, %{
              end_time: DateTime.utc_now(),
              result: :success
            })

            # Clean up state storage
            PocketFlex.StateStorage.cleanup(flow_id)

            # Return success
            {:ok, final_state}

          {:error, reason} = error ->
            # Complete monitoring with failed status
            ErrorHandler.complete_monitoring(flow_id, :failed, %{
              end_time: DateTime.utc_now(),
              result: :error,
              error: reason
            })

            # Clean up state storage
            PocketFlex.StateStorage.cleanup(flow_id)

            # Return the error
            error
        end
    end
  end

  # Execute the batch flow with the start node
  defp execute_batch_flow(flow, flow_id, state) do
    # Check if the node is an AsyncBatchNode
    if function_exported?(flow.start_node, :exec_item_async, 1) do
      # This is an AsyncBatchNode, get the batch items from the node's prep function
      batch_items = flow.start_node.prep(state)

      # Process the batch items
      if is_list(batch_items) do
        process_batch_items(flow, flow_id, batch_items)
      else
        Logger.warning(
          "Batch prep did not return a list. Using the entire result as a single item."
        )

        process_batch_items(flow, flow_id, [batch_items])
      end

      # Check if it's a regular AsyncNode
    else
      if function_exported?(flow.start_node, :prep_async, 1) do
        # Get the batch items from the node's prep_async function
        case flow.start_node.prep_async(state) do
          {:ok, batch_items} ->
            if is_list(batch_items) do
              process_batch_items(flow, flow_id, batch_items)
            else
              Logger.warning(
                "Async node prep did not return a list. Using the entire result as a single item."
              )

              process_batch_items(flow, flow_id, [batch_items])
            end

          {:error, reason} ->
            {:error, reason}
        end
      else
        # For regular nodes, use the prepare_batch_items function
        case prepare_batch_items(flow.start_node, state) do
          {:ok, items} when is_list(items) ->
            process_batch_items(flow, flow_id, items)

          {:ok, %{} = items} when is_map(items) and map_size(items) > 0 ->
            Logger.warning(
              "Batch prep returned a map instead of a list. Using map values as items."
            )

            process_batch_items(flow, flow_id, Map.values(items))

          {:ok, items} ->
            Logger.warning(
              "Batch prep did not return a list of items. Using the entire result as a single item."
            )

            process_batch_items(flow, flow_id, [items])

          {:error, reason} ->
            {:error, reason}
        end
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
        {:error, %{context: :async_batch_batch_prep, error: error}}
    end
  end

  # Process batch items sequentially
  defp process_batch_items(flow, flow_id, items) do
    # Process each item in the batch
    results =
      Enum.map(items, fn item ->
        # Get the latest shared state from storage
        current_state = PocketFlex.StateStorage.get_state(flow_id)

        # Create a new shared map with the current batch item
        item_state = Map.put(current_state, "current_batch_item", item)

        # Process the item
        process_single_item(flow, flow_id, item, item_state)
      end)

    # Check if any items failed
    if Enum.any?(results, fn
         {:error, _} -> true
         _ -> false
       end) do
      # Get the first error
      first_error =
        Enum.find(results, fn
          {:error, _} -> true
          _ -> false
        end)

      # Return the error
      first_error
    else
      # Get the final state after processing all items
      final_state = PocketFlex.StateStorage.get_state(flow_id)

      # Return success
      {:ok, final_state}
    end
  end

  # Process a single item and update state
  defp process_single_item(flow, flow_id, item, item_state) do
    # Run the start node with this item
    case PocketFlex.NodeRunner.run_node(flow.start_node, item_state) do
      {:ok, action, updated_state} ->
        # Update the state for this item
        update_item_state(flow_id, item, updated_state)

        # Get the next node based on the action
        next_node = PocketFlex.Flow.get_next_node(flow, flow.start_node, action)

        # If there's a next node, continue the flow execution
        if next_node do
          # Get the latest state from storage
          current_state = PocketFlex.StateStorage.get_state(flow_id)

          # Run the next node with the current state
          case PocketFlex.Flow.run_from_node(flow, next_node, current_state) do
            {:ok, final_state} ->
              # Update the state storage with the final state
              PocketFlex.StateStorage.update_state(flow_id, final_state)
              {:ok, final_state}

            {:error, reason} = error ->
              Logger.error("Error continuing flow after batch processing: #{inspect(reason)}")
              error
          end
        else
          {:ok, updated_state}
        end

      {:error, reason} ->
        Logger.error("Error processing item #{inspect(item)}: #{inspect(reason)}")
        {:error, %{context: :async_batch_item_processing, error: reason}}
    end
  rescue
    error ->
      Logger.error("Unexpected error processing item #{inspect(item)}: #{inspect(error)}")
      {:error, %{context: :async_batch_item_processing, error: error}}
  end

  # Update the state for a processed item
  defp update_item_state(flow_id, item, updated_state) do
    case PocketFlex.StateStorage.update_state(flow_id, updated_state) do
      {:error, reason} ->
        Logger.error("Failed to update state for item #{inspect(item)}: #{inspect(reason)}")

      _ ->
        :ok
    end
  end
end
