defmodule PocketFlex.AsyncBatchFlow do
  @moduledoc """
  Manages the asynchronous execution of batch processing flows.

  Extends the basic BatchFlow module with support for asynchronous
  execution using Elixir processes with a functional approach.
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
    A Task that will resolve to:
    - {:ok, final_shared_state}
    - {:error, reason}
  """
  @spec run_async_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async_batch(flow, state) do
    # Generate a unique flow ID for this execution
    flow_id = "async_batch_#{:erlang.unique_integer([:positive])}"

    # Initialize state storage with the initial state
    PocketFlex.StateStorage.update_state(flow_id, state)

    Task.async(fn ->
      try do
        # Get batch items from prep
        items = flow.start_node.prep(state)

        case items do
          nil ->
            result = {:ok, state}
            PocketFlex.StateStorage.cleanup(flow_id)
            result

          [] ->
            result = {:ok, state}
            PocketFlex.StateStorage.cleanup(flow_id)
            result

          items when is_list(items) ->
            # Process each item sequentially but asynchronously
            process_items_sequentially(flow, flow_id, items)

            # Get the latest state after processing items
            current_state = PocketFlex.StateStorage.get_state(flow_id)

            # Continue the flow with the remaining nodes (after the start node)
            case continue_flow(flow, flow.start_node, :default, current_state) do
              {:ok, final_state} ->
                # Clean up the state
                final_result = {:ok, final_state}
                PocketFlex.StateStorage.cleanup(flow_id)
                final_result

              error ->
                PocketFlex.StateStorage.cleanup(flow_id)
                error
            end

          _ ->
            result = {:error, "Batch prep must return a list"}
            PocketFlex.StateStorage.cleanup(flow_id)
            result
        end
      rescue
        e ->
          Logger.error("Error in async batch flow: #{inspect(e)}")
          PocketFlex.StateStorage.cleanup(flow_id)
          {:error, e}
      end
    end)
  end

  # Process items sequentially
  defp process_items_sequentially(flow, flow_id, items) do
    # Process each item sequentially
    Enum.each(items, fn item ->
      # Get the latest shared state from storage
      current_state = PocketFlex.StateStorage.get_state(flow_id)

      # Create a new state map with the current batch item
      item_state = Map.put(current_state, "current_batch_item", item)

      # Run the start node with this item
      case run_node(flow.start_node, item_state) do
        {:ok, _action, updated_state} ->
          # Update the shared state in storage
          PocketFlex.StateStorage.update_state(flow_id, updated_state)

        {:error, reason} ->
          Logger.error("Error processing item: #{inspect(reason)}")
      end
    end)
  end

  # Run a single node
  defp run_node(node, state) do
    try do
      # Prepare data
      prep_result = node.prep(state)

      # Execute
      exec_result = node.exec(prep_result)

      # Post-process
      {action, updated_state} = node.post(state, prep_result, exec_result)

      {:ok, action, updated_state}
    rescue
      e ->
        Logger.error("Error running node: #{inspect(e)}")
        {:error, e}
    end
  end

  # Continue the flow with the remaining nodes
  defp continue_flow(flow, current_node, action, state) do
    # Find the next node based on the action
    next_node = get_next_node(flow, current_node, action)

    # If there's no next node, return the current state
    if next_node == nil do
      {:ok, state}
    else
      # Run the next node
      case run_node(next_node, state) do
        {:ok, next_action, updated_state} ->
          # Continue the flow with the next node
          continue_flow(flow, next_node, next_action, updated_state)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Get the next node based on the current node and action
  defp get_next_node(flow, current_node, action) do
    # Get the connections for the current node
    connections = Map.get(flow.connections, current_node, %{})

    # Get the next node for the given action or the default action
    next_node =
      cond do
        Map.has_key?(connections, action) -> Map.get(connections, action)
        Map.has_key?(connections, :default) -> Map.get(connections, :default)
        true -> nil
      end

    next_node
  end
end

defmodule PocketFlex.AsyncParallelBatchFlow do
  @moduledoc """
  Manages the parallel asynchronous execution of batch processing flows.

  Extends the AsyncBatchFlow module with support for processing
  multiple items in parallel using Elixir's Task module with a functional approach.
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
    A Task that will resolve to:
    - {:ok, final_shared_state}
    - {:error, reason}
  """
  @spec run_async_parallel_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async_parallel_batch(flow, state) do
    # Generate a unique flow ID for this execution
    flow_id = "async_parallel_batch_#{:erlang.unique_integer([:positive])}"

    # Initialize state storage with the initial state
    PocketFlex.StateStorage.update_state(flow_id, state)

    Task.async(fn ->
      try do
        # Get batch items from prep
        items = flow.start_node.prep(state)

        case items do
          nil ->
            result = {:ok, state}
            PocketFlex.StateStorage.cleanup(flow_id)
            result

          [] ->
            result = {:ok, state}
            PocketFlex.StateStorage.cleanup(flow_id)
            result

          items when is_list(items) ->
            # Process items in parallel
            process_items_in_parallel(flow, flow_id, items)

            # Get the latest state after processing items
            current_state = PocketFlex.StateStorage.get_state(flow_id)

            # Continue the flow with the remaining nodes (after the start node)
            case continue_flow(flow, flow.start_node, :default, current_state) do
              {:ok, final_state} ->
                # Clean up the state
                final_result = {:ok, final_state}
                PocketFlex.StateStorage.cleanup(flow_id)
                final_result

              error ->
                PocketFlex.StateStorage.cleanup(flow_id)
                error
            end

          _ ->
            result = {:error, "Batch prep must return a list"}
            PocketFlex.StateStorage.cleanup(flow_id)
            result
        end
      rescue
        e ->
          Logger.error("Error in async parallel batch flow: #{inspect(e)}")
          PocketFlex.StateStorage.cleanup(flow_id)
          {:error, e}
      end
    end)
  end

  # Process items in parallel
  defp process_items_in_parallel(flow, flow_id, items) do
    # Create tasks for each item
    tasks =
      Enum.map(items, fn item ->
        Task.async(fn ->
          # Get the latest shared state from storage
          current_state = PocketFlex.StateStorage.get_state(flow_id)

          # Create a new shared map with the current batch item
          item_state = Map.put(current_state, "current_batch_item", item)

          # Run the start node with this item
          case run_node(flow.start_node, item_state) do
            {:ok, _action, updated_state} ->
              # Update the shared state in storage by merging
              PocketFlex.StateStorage.merge_state(flow_id, updated_state)
              {:ok, updated_state}

            {:error, reason} ->
              Logger.error("Error processing item: #{inspect(reason)}")
              {:error, reason}
          end
        end)
      end)

    # Wait for all tasks to complete
    Task.await_many(tasks, :infinity)
  end

  # Run a single node
  defp run_node(node, state) do
    try do
      # Prepare data
      prep_result = node.prep(state)

      # Execute
      exec_result = node.exec(prep_result)

      # Post-process
      {action, updated_state} = node.post(state, prep_result, exec_result)

      {:ok, action, updated_state}
    rescue
      e ->
        Logger.error("Error running node: #{inspect(e)}")
        {:error, e}
    end
  end

  # Continue the flow with the remaining nodes
  defp continue_flow(flow, current_node, action, state) do
    # Find the next node based on the action
    next_node = get_next_node(flow, current_node, action)

    # If there's no next node, return the current state
    if next_node == nil do
      {:ok, state}
    else
      # Run the next node
      case run_node(next_node, state) do
        {:ok, next_action, updated_state} ->
          # Continue the flow with the next node
          continue_flow(flow, next_node, next_action, updated_state)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Get the next node based on the current node and action
  defp get_next_node(flow, current_node, action) do
    # Get the connections for the current node
    connections = Map.get(flow.connections, current_node, %{})

    # Get the next node for the given action or the default action
    next_node =
      cond do
        Map.has_key?(connections, action) -> Map.get(connections, action)
        Map.has_key?(connections, :default) -> Map.get(connections, :default)
        true -> nil
      end

    next_node
  end
end
