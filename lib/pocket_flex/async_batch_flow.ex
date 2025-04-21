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
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to:
    - {:ok, final_shared_state}
    - {:error, reason}
  """
  @spec run_async_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async_batch(flow, shared) do
    # Generate a unique flow ID for this execution
    flow_id = "async_batch_#{:erlang.unique_integer([:positive])}"

    # Initialize state storage with the initial shared state
    PocketFlex.StateStorage.init(flow_id, shared)

    Task.async(fn ->
      try do
        # Get batch items from prep
        items = flow.start_node.prep(shared)

        case items do
          nil ->
            result = {:ok, shared}
            PocketFlex.StateStorage.cleanup(flow_id)
            result

          [] ->
            result = {:ok, shared}
            PocketFlex.StateStorage.cleanup(flow_id)
            result

          items when is_list(items) ->
            # Process each item sequentially but asynchronously
            result = process_items_sequentially(flow, flow_id, items)

            # Run any remaining nodes in the flow that aren't part of the batch processing
            case result do
              {:ok, _batch_shared} ->
                # Get all nodes that should be executed after the start node
                next_nodes = get_next_nodes(flow, flow.start_node)

                # Execute each node in sequence
                final_result = execute_remaining_nodes(flow, flow_id, next_nodes)
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
    # Process each item and accumulate the shared state
    Enum.reduce_while(items, {:ok, PocketFlex.StateStorage.get_state(flow_id)}, fn item,
                                                                                   {:ok,
                                                                                    _acc_shared} ->
      # Get the latest shared state from storage
      current_shared = PocketFlex.StateStorage.get_state(flow_id)

      # Create a new shared map with the current batch item
      item_shared = Map.put(current_shared, "current_batch_item", item)

      # Run the flow with this item, but only through the start node
      {:ok, updated_shared} = run_start_node(flow, item_shared)

      # Update the shared state in storage
      PocketFlex.StateStorage.update_state(flow_id, updated_shared)
      # Continue with the updated shared state
      {:cont, {:ok, updated_shared}}
    end)
  end

  # Run only the start node of the flow
  defp run_start_node(flow, shared) do
    # Prepare the start node
    prep_result = flow.start_node.prep(shared)

    # Execute the start node
    exec_result = flow.start_node.exec(prep_result)

    # Post-process the start node
    {_action, updated_shared} = flow.start_node.post(shared, prep_result, exec_result)

    # Return the updated shared state
    {:ok, updated_shared}
  end

  # Get all nodes that should be executed after the start node
  defp get_next_nodes(flow, node) do
    # Get all connections from this node
    connections = Map.get(flow.connections, node, %{})

    # Get all target nodes
    Enum.map(connections, fn {_action, target_node} -> target_node end)
    |> Enum.uniq()
  end

  # Execute remaining nodes in the flow
  defp execute_remaining_nodes(flow, flow_id, nodes) do
    # Get the latest shared state
    current_shared = PocketFlex.StateStorage.get_state(flow_id)

    # Execute each node in sequence
    Enum.reduce_while(nodes, {:ok, current_shared}, fn node, {:ok, acc_shared} ->
      # Run the node
      {:ok, updated_shared} = run_node(node, acc_shared)

      # Update the shared state in storage
      PocketFlex.StateStorage.update_state(flow_id, updated_shared)

      # Get the next nodes to execute
      next_nodes = get_next_nodes(flow, node)

      if Enum.empty?(next_nodes) do
        # No more nodes to execute
        {:halt, {:ok, updated_shared}}
      else
        # Execute the next nodes
        case execute_remaining_nodes(flow, flow_id, next_nodes) do
          {:ok, final_shared} -> {:halt, {:ok, final_shared}}
          error -> {:halt, error}
        end
      end
    end)
  end

  # Run a single node in the flow
  defp run_node(node, shared) do
    # Prepare the node
    prep_result = node.prep(shared)

    # Execute the node
    exec_result = node.exec(prep_result)

    # Post-process the node
    {_action, updated_shared} = node.post(shared, prep_result, exec_result)

    # Return the updated shared state
    {:ok, updated_shared}
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
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to:
    - {:ok, final_shared_state}
    - {:error, reason}
  """
  @spec run_async_parallel_batch(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async_parallel_batch(flow, shared) do
    # Generate a unique flow ID for this execution
    flow_id = "async_parallel_batch_#{:erlang.unique_integer([:positive])}"

    # Initialize state storage with the initial shared state
    PocketFlex.StateStorage.init(flow_id, shared)

    Task.async(fn ->
      try do
        # Get batch items from prep
        items = flow.start_node.prep(shared)

        case items do
          nil ->
            result = {:ok, shared}
            PocketFlex.StateStorage.cleanup(flow_id)
            result

          [] ->
            result = {:ok, shared}
            PocketFlex.StateStorage.cleanup(flow_id)
            result

          items when is_list(items) ->
            # Process items in parallel
            result = process_items_in_parallel(flow, flow_id, items)

            # Run any remaining nodes in the flow that aren't part of the batch processing
            case result do
              {:ok, _batch_shared} ->
                # Get all nodes that should be executed after the start node
                next_nodes = get_next_nodes(flow, flow.start_node)

                # Execute each node in sequence
                final_result = execute_remaining_nodes(flow, flow_id, next_nodes)
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
          current_shared = PocketFlex.StateStorage.get_state(flow_id)

          # Create a new shared map with the current batch item
          item_shared = Map.put(current_shared, "current_batch_item", item)

          # Run the flow with this item, but only through the start node
          {:ok, updated_shared} = run_start_node(flow, item_shared)

          # Update the shared state in storage by merging
          PocketFlex.StateStorage.merge_state(flow_id, updated_shared)
          {:ok, updated_shared}
        end)
      end)

    # Wait for all tasks to complete
    _results = Task.await_many(tasks, :infinity)

    # Return the final state from storage
    {:ok, PocketFlex.StateStorage.get_state(flow_id)}
  end

  # Run only the start node of the flow
  defp run_start_node(flow, shared) do
    # Prepare the start node
    prep_result = flow.start_node.prep(shared)

    # Execute the start node
    exec_result = flow.start_node.exec(prep_result)

    # Post-process the start node
    {_action, updated_shared} = flow.start_node.post(shared, prep_result, exec_result)

    # Return the updated shared state
    {:ok, updated_shared}
  end

  # Get all nodes that should be executed after the start node
  defp get_next_nodes(flow, node) do
    # Get all connections from this node
    connections = Map.get(flow.connections, node, %{})

    # Get all target nodes
    Enum.map(connections, fn {_action, target_node} -> target_node end)
    |> Enum.uniq()
  end

  # Execute remaining nodes in the flow
  defp execute_remaining_nodes(flow, flow_id, nodes) do
    # Get the latest shared state
    current_shared = PocketFlex.StateStorage.get_state(flow_id)

    # Execute each node in sequence
    Enum.reduce_while(nodes, {:ok, current_shared}, fn node, {:ok, acc_shared} ->
      # Run the node
      {:ok, updated_shared} = run_node(node, acc_shared)

      # Update the shared state in storage
      PocketFlex.StateStorage.update_state(flow_id, updated_shared)

      # Get the next nodes to execute
      next_nodes = get_next_nodes(flow, node)

      if Enum.empty?(next_nodes) do
        # No more nodes to execute
        {:halt, {:ok, updated_shared}}
      else
        # Execute the next nodes
        case execute_remaining_nodes(flow, flow_id, next_nodes) do
          {:ok, final_shared} -> {:halt, {:ok, final_shared}}
          error -> {:halt, error}
        end
      end
    end)
  end

  # Run a single node in the flow
  defp run_node(node, shared) do
    # Prepare the node
    prep_result = node.prep(shared)

    # Execute the node
    exec_result = node.exec(prep_result)

    # Post-process the node
    {_action, updated_shared} = node.post(shared, prep_result, exec_result)

    # Return the updated shared state
    {:ok, updated_shared}
  end
end
