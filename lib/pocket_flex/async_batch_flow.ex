defmodule PocketFlex.AsyncBatchFlow do
  @moduledoc """
  Manages the asynchronous execution of batch processing flows.

  This module provides functionality for running flows asynchronously with batch processing
  capabilities. It extends the basic Flow module with support for processing lists of items
  sequentially but asynchronously.

  ## State Management

  AsyncBatchFlow uses the PocketFlex.StateStorage system to maintain state across
  asynchronous operations. Each flow execution gets a unique flow_id, and its state
  is stored in the shared state storage.

  ## Flow Execution Model

  The execution model follows these steps:

  1. Generate a unique flow_id for the execution
  2. Initialize the state storage with the initial state
  3. Process each item in the batch sequentially but asynchronously
  4. Continue the flow with any remaining nodes after the batch processing
  5. Return the final state and clean up the state storage

  ## Usage Example

  ```elixir
  # Create a flow with batch processing nodes
  flow =
    PocketFlex.Flow.new()
    |> PocketFlex.Flow.add_node(MyBatchNode)
    |> PocketFlex.Flow.add_node(ResultProcessorNode)
    |> PocketFlex.Flow.connect(MyBatchNode, ResultProcessorNode)
    |> PocketFlex.Flow.start(MyBatchNode)

  # Initial state
  initial_state = %{"items" => [1, 2, 3, 4, 5]}

  # Run the flow asynchronously
  task = PocketFlex.AsyncBatchFlow.run_async_batch(flow, initial_state)

  # Wait for the result
  {:ok, final_state} = Task.await(task)
  ```

  ## Batch Node Requirements

  The start node of the flow should implement the `PocketFlex.AsyncBatchNode` behavior,
  which provides the necessary callbacks for batch processing.
  """

  require Logger

  @doc """
  Runs the batch flow asynchronously with the given shared state.

  The batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow sequentially but asynchronously.

  ## Parameters
    - flow: The flow to run
    - state: The initial shared state
    
  ## Returns
    A Task that will resolve to either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec run_async_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async_batch(flow, state) do
    # Generate a unique flow ID for this execution
    flow_id = "async_batch_#{:erlang.unique_integer([:positive])}"

    # Initialize state storage with the initial state
    case PocketFlex.StateStorage.update_state(flow_id, state) do
      {:error, reason} ->
        # Return a failed task if state storage initialization fails
        Task.async(fn -> 
          Logger.error("Failed to initialize state storage for flow_id #{flow_id}: #{inspect(reason)}")
          {:error, :state_storage_initialization_failed} 
        end)
      
      _ ->
        Task.async(fn -> 
          execute_batch_flow(flow, flow_id, state)
        end)
    end
  end

  defp execute_batch_flow(flow, flow_id, state) do
    # Validate the flow structure
    if flow.start_node == nil do
      PocketFlex.StateStorage.cleanup(flow_id)
      {:error, :missing_start_node}
    else
      # Get batch items from prep
      case prepare_batch_items(flow.start_node, state) do
        {:ok, nil} ->
          PocketFlex.StateStorage.cleanup(flow_id)
          {:ok, state}
          
        {:ok, []} ->
          PocketFlex.StateStorage.cleanup(flow_id)
          {:ok, state}
          
        {:ok, items} when is_list(items) ->
          # Process each item sequentially but asynchronously
          process_items_sequentially(flow, flow_id, items)

          # Get the latest state after processing items
          current_state = PocketFlex.StateStorage.get_state(flow_id)

          # Continue the flow with the remaining nodes (after the start node)
          result = continue_flow(flow, flow.start_node, :default, current_state)
          PocketFlex.StateStorage.cleanup(flow_id)
          result
          
        {:ok, invalid_items} ->
          Logger.error("Batch prep must return a list, got: #{inspect(invalid_items)}")
          PocketFlex.StateStorage.cleanup(flow_id)
          {:error, :invalid_batch_items}
          
        {:error, reason} ->
          Logger.error("Error in start node prep: #{inspect(reason)}")
          PocketFlex.StateStorage.cleanup(flow_id)
          {:error, reason}
      end
    end
  rescue
    error ->
      Logger.error("Unexpected error in async batch flow: #{inspect(error)}")
      PocketFlex.StateStorage.cleanup(flow_id)
      {:error, {:unexpected_error, error}}
  end

  defp prepare_batch_items(node, state) do
    try do
      {:ok, node.prep(state)}
    rescue
      error -> {:error, {:prep_failed, error}}
    end
  end

  # Process each item sequentially
  defp process_items_sequentially(flow, flow_id, items) do
    Enum.each(items, fn item ->
      # Get the latest shared state from storage
      current_state = PocketFlex.StateStorage.get_state(flow_id)
      
      # Create a new state map with the current batch item
      item_state = Map.put(current_state, "current_batch_item", item)

      # Run the start node with this item
      process_single_item(flow, flow_id, item, item_state)
    end)
  end

  # Process a single item and update state
  defp process_single_item(flow, flow_id, item, item_state) do
    case run_node(flow.start_node, item_state) do
      {:ok, _action, updated_state} ->
        update_item_state(flow_id, item, updated_state)

      {:error, reason} ->
        Logger.error("Error processing item #{inspect(item)}: #{inspect(reason)}")
    end
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

  # Run a single node
  defp run_node(node, state) do
    node_prep(node, state)
    |> run_node_with_prep_result(node, state)
  end

  defp run_node_with_prep_result({:error, reason}, _node, _state), do: {:error, reason}
  defp run_node_with_prep_result({:ok, prep_result}, node, state) do
    case node_exec(node, prep_result) do
      {:error, reason} -> 
        {:error, reason}
      {:ok, exec_result} -> 
        case node_post(node, state, prep_result, exec_result) do
          {:error, reason} -> 
            {:error, reason}
          {:ok, action, updated_state} -> 
            {:ok, action, updated_state}
        end
    end
  end

  defp node_prep(node, state) do
    try do
      {:ok, node.prep(state)}
    rescue
      error -> 
        Logger.error("Error in node prep: #{inspect(error)}")
        {:error, :prep_failed}
    end
  end

  defp node_exec(node, prep_result) do
    try do
      {:ok, node.exec(prep_result)}
    rescue
      error -> 
        Logger.error("Error in node exec: #{inspect(error)}")
        {:error, :exec_failed}
    end
  end

  defp node_post(node, state, prep_result, exec_result) do
    try do
      {action, updated_state} = node.post(state, prep_result, exec_result)
      {:ok, action, updated_state}
    rescue
      error -> 
        Logger.error("Error in node post: #{inspect(error)}")
        {:error, :post_failed}
    end
  end

  # Continue the flow with the remaining nodes
  defp continue_flow(flow, current_node, action, state) do
    # Find the next node based on the action
    case get_next_node(flow, current_node, action) do
      {:ok, nil} ->
        # No next node, return the current state
        {:ok, state}
        
      {:ok, next_node} ->
        # Run the next node
        case run_node(next_node, state) do
          {:ok, next_action, updated_state} ->
            # Continue the flow with the next node
            continue_flow(flow, next_node, next_action, updated_state)

          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Error continuing flow: #{inspect(error)}")
      {:error, :flow_continuation_failed}
  end

  # Get the next node based on the current node and action
  defp get_next_node(flow, current_node, action) do
    try do
      # Get the connections for the current node
      connections = Map.get(flow.connections, current_node, %{})

      # Get the next node for the given action or the default action
      next_node =
        cond do
          Map.has_key?(connections, action) -> Map.get(connections, action)
          Map.has_key?(connections, :default) -> Map.get(connections, :default)
          true -> nil
        end

      {:ok, next_node}
    rescue
      error ->
        Logger.error("Error getting next node: #{inspect(error)}")
        {:error, :next_node_lookup_failed}
    end
  end
end

defmodule PocketFlex.AsyncParallelBatchFlow do
  @moduledoc """
  Manages the parallel asynchronous execution of batch processing flows.

  This module extends the AsyncBatchFlow with support for processing multiple items
  in parallel. It uses Elixir's Task module to run multiple items concurrently.

  ## State Management

  AsyncParallelBatchFlow uses the PocketFlex.StateStorage system to maintain state across
  asynchronous operations. Each flow execution gets a unique flow_id, and its state
  is stored in the shared state storage.

  The key difference from AsyncBatchFlow is that state updates from parallel item
  processing are merged rather than replaced, allowing concurrent updates.

  ## Flow Execution Model

  The execution model follows these steps:

  1. Generate a unique flow_id for the execution
  2. Initialize the state storage with the initial state
  3. Process all items in the batch in parallel using Tasks
  4. Merge the results of each item processing into the shared state
  5. Continue the flow with any remaining nodes after the batch processing
  6. Return the final state and clean up the state storage

  ## Usage Example

  ```elixir
  # Create a flow with batch processing nodes
  flow =
    PocketFlex.Flow.new()
    |> PocketFlex.Flow.add_node(MyParallelBatchNode)
    |> PocketFlex.Flow.add_node(ResultProcessorNode)
    |> PocketFlex.Flow.connect(MyParallelBatchNode, ResultProcessorNode)
    |> PocketFlex.Flow.start(MyParallelBatchNode)

  # Initial state
  initial_state = %{"items" => [1, 2, 3, 4, 5]}

  # Run the flow asynchronously with parallel processing
  task = PocketFlex.AsyncParallelBatchFlow.run_async_parallel_batch(flow, initial_state)

  # Wait for the result
  {:ok, final_state} = Task.await(task)
  ```

  ## Batch Node Requirements

  The start node of the flow should implement the `PocketFlex.AsyncParallelBatchNode` behavior,
  which provides the necessary callbacks for parallel batch processing.
  """

  require Logger

  @doc """
  Runs the batch flow asynchronously with the given shared state, processing items in parallel.

  The batch flow expects the start node's prep function to return a list of items.
  Each item will be processed through the flow in parallel and asynchronously.

  ## Parameters
    - flow: The flow to run
    - state: The initial shared state
    
  ## Returns
    A Task that will resolve to either:
      * `{:ok, final_state}` - Success with the final state
      * `{:error, reason}` - Error with the reason
  """
  @spec run_async_parallel_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async_parallel_batch(flow, state) do
    # Generate a unique flow ID for this execution
    flow_id = "async_parallel_batch_#{:erlang.unique_integer([:positive])}"

    # Initialize state storage with the initial state
    case PocketFlex.StateStorage.update_state(flow_id, state) do
      {:error, reason} ->
        # Return a failed task if state storage initialization fails
        Task.async(fn -> 
          Logger.error("Failed to initialize state storage for flow_id #{flow_id}: #{inspect(reason)}")
          {:error, :state_storage_initialization_failed} 
        end)
      
      _ ->
        Task.async(fn -> 
          execute_parallel_batch_flow(flow, flow_id, state)
        end)
    end
  end

  defp execute_parallel_batch_flow(flow, flow_id, state) do
    # Validate the flow structure
    if flow.start_node == nil do
      PocketFlex.StateStorage.cleanup(flow_id)
      {:error, :missing_start_node}
    else
      # Get batch items from prep
      case prepare_batch_items(flow.start_node, state) do
        {:ok, nil} ->
          PocketFlex.StateStorage.cleanup(flow_id)
          {:ok, state}
          
        {:ok, []} ->
          PocketFlex.StateStorage.cleanup(flow_id)
          {:ok, state}
          
        {:ok, items} when is_list(items) ->
          # Process items in parallel
          process_items_in_parallel(flow, flow_id, items)

          # Get the latest state after processing items
          current_state = PocketFlex.StateStorage.get_state(flow_id)

          # Continue the flow with the remaining nodes (after the start node)
          result = continue_flow(flow, flow.start_node, :default, current_state)
          PocketFlex.StateStorage.cleanup(flow_id)
          result
          
        {:ok, invalid_items} ->
          Logger.error("Batch prep must return a list, got: #{inspect(invalid_items)}")
          PocketFlex.StateStorage.cleanup(flow_id)
          {:error, :invalid_batch_items}
          
        {:error, reason} ->
          Logger.error("Error in start node prep: #{inspect(reason)}")
          PocketFlex.StateStorage.cleanup(flow_id)
          {:error, reason}
      end
    end
  rescue
    error ->
      Logger.error("Unexpected error in async parallel batch flow: #{inspect(error)}")
      PocketFlex.StateStorage.cleanup(flow_id)
      {:error, {:unexpected_error, error}}
  end

  defp prepare_batch_items(node, state) do
    try do
      {:ok, node.prep(state)}
    rescue
      error -> {:error, {:prep_failed, error}}
    end
  end

  # Process items in parallel
  defp process_items_in_parallel(flow, flow_id, items) do
    # Create tasks for each item
    tasks =
      Enum.map(items, fn item ->
        Task.async(fn ->
          process_single_item(flow, flow_id, item)
        end)
      end)

    # Wait for all tasks to complete with a timeout
    case Task.yield_many(tasks, 60_000) do
      incomplete when incomplete != [] ->
        # Some tasks didn't complete within the timeout
        Logger.warning("Some parallel tasks timed out")
        
        # Shut down the remaining tasks
        Enum.each(incomplete, fn {task, _} -> Task.shutdown(task, :brutal_kill) end)
        
      _ ->
        :ok
    end
  end

  defp process_single_item(flow, flow_id, item) do
    # Get the latest shared state from storage
    current_state = PocketFlex.StateStorage.get_state(flow_id)

    # Create a new shared map with the current batch item
    item_state = Map.put(current_state, "current_batch_item", item)

    # Run the start node with this item
    case run_node(flow.start_node, item_state) do
      {:ok, _action, updated_state} ->
        # Update the shared state in storage by merging
        case PocketFlex.StateStorage.merge_state(flow_id, updated_state) do
          {:error, reason} ->
            Logger.error("Failed to merge state for item #{inspect(item)}: #{inspect(reason)}")
            {:error, :state_merge_failed}
          merged_state ->
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

  # Run a single node
  defp run_node(node, state) do
    node_prep(node, state)
    |> run_node_with_prep_result(node, state)
  end

  defp run_node_with_prep_result({:error, reason}, _node, _state), do: {:error, reason}
  defp run_node_with_prep_result({:ok, prep_result}, node, state) do
    case node_exec(node, prep_result) do
      {:error, reason} -> 
        {:error, reason}
      {:ok, exec_result} -> 
        case node_post(node, state, prep_result, exec_result) do
          {:error, reason} -> 
            {:error, reason}
          {:ok, action, updated_state} -> 
            {:ok, action, updated_state}
        end
    end
  end

  defp node_prep(node, state) do
    try do
      {:ok, node.prep(state)}
    rescue
      error -> 
        Logger.error("Error in node prep: #{inspect(error)}")
        {:error, :prep_failed}
    end
  end

  defp node_exec(node, prep_result) do
    try do
      {:ok, node.exec(prep_result)}
    rescue
      error -> 
        Logger.error("Error in node exec: #{inspect(error)}")
        {:error, :exec_failed}
    end
  end

  defp node_post(node, state, prep_result, exec_result) do
    try do
      {action, updated_state} = node.post(state, prep_result, exec_result)
      {:ok, action, updated_state}
    rescue
      error -> 
        Logger.error("Error in node post: #{inspect(error)}")
        {:error, :post_failed}
    end
  end

  # Continue the flow with the remaining nodes
  defp continue_flow(flow, current_node, action, state) do
    # Find the next node based on the action
    case get_next_node(flow, current_node, action) do
      {:ok, nil} ->
        # No next node, return the current state
        {:ok, state}
        
      {:ok, next_node} ->
        # Run the next node
        case run_node(next_node, state) do
          {:ok, next_action, updated_state} ->
            # Continue the flow with the next node
            continue_flow(flow, next_node, next_action, updated_state)

          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Error continuing flow: #{inspect(error)}")
      {:error, :flow_continuation_failed}
  end

  # Get the next node based on the current node and action
  defp get_next_node(flow, current_node, action) do
    try do
      # Get the connections for the current node
      connections = Map.get(flow.connections, current_node, %{})

      # Get the next node for the given action or the default action
      next_node =
        cond do
          Map.has_key?(connections, action) -> Map.get(connections, action)
          Map.has_key?(connections, :default) -> Map.get(connections, :default)
          true -> nil
        end

      {:ok, next_node}
    rescue
      error ->
        Logger.error("Error getting next node: #{inspect(error)}")
        {:error, :next_node_lookup_failed}
    end
  end
end
