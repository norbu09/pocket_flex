defmodule PocketFlex.BatchFlow do
  @moduledoc """
  Manages the execution of batch processing flows.
  
  Extends the basic Flow module with support for batch
  processing of multiple items.
  """
  
  require Logger
  
  @doc """
  Runs the batch flow with the given shared state.
  
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
  def run_batch(flow, shared) do
    try do
      # Get batch items from prep
      items = flow.start_node.prep(shared)
      
      case items do
        nil -> {:ok, shared}
        [] -> {:ok, shared}
        items when is_list(items) ->
          # Process each item sequentially
          Enum.reduce_while(items, {:ok, shared}, fn item, {:ok, acc_shared} ->
            # Create a new shared map with the current batch item
            item_shared = Map.put(acc_shared, "current_batch_item", item)
            
            # Run the flow with this item
            case PocketFlex.Flow.run(flow, item_shared) do
              {:ok, updated_shared} -> {:cont, {:ok, updated_shared}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
          end)
          
        _ -> {:error, "Batch prep must return a list"}
      end
    rescue
      e -> {:error, e}
    end
  end
end

defmodule PocketFlex.ParallelBatchFlow do
  @moduledoc """
  Manages the parallel execution of batch processing flows.
  
  Extends the BatchFlow module with support for processing
  multiple items in parallel using Elixir's Task module.
  """
  
  require Logger
  
  @doc """
  Runs the batch flow with the given shared state, processing items in parallel.
  
  The batch flow expects the start node's prep function to return a list of items.
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
  def run_parallel_batch(flow, shared) do
    try do
      # Get batch items from prep
      items = flow.start_node.prep(shared)
      
      case items do
        nil -> {:ok, shared}
        [] -> {:ok, shared}
        items when is_list(items) ->
          # Process each item in parallel
          tasks = Enum.map(items, fn item ->
            Task.async(fn ->
              # Create a new shared map with the current batch item
              item_shared = Map.put(shared, "current_batch_item", item)
              
              # Run the flow with this item
              PocketFlex.Flow.run(flow, item_shared)
            end)
          end)
          
          # Wait for all tasks to complete
          results = Task.await_many(tasks, :infinity)
          
          # Merge results
          Enum.reduce_while(results, {:ok, shared}, fn
            {:ok, item_shared}, {:ok, acc_shared} ->
              {:cont, {:ok, Map.merge(acc_shared, item_shared)}}
              
            {:error, reason}, _acc ->
              {:halt, {:error, reason}}
          end)
          
        _ -> {:error, "Batch prep must return a list"}
      end
    rescue
      e -> {:error, e}
    end
  end
end
