defmodule PocketFlex do
  @moduledoc """
  PocketFlex is a flexible node-based processing framework for Elixir.
  
  It allows you to create flows of connected nodes, each with its own
  lifecycle methods (prep, exec, post) and supports different execution
  models including synchronous, asynchronous, and batch processing.
  """
  
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
  Runs a flow asynchronously with the given shared state.
  
  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A Task that will resolve to:
    - {:ok, final_shared_state}
    - {:error, reason}
  """
  @spec run_async(PocketFlex.Flow.t(), map()) :: Task.t()
  def run_async(flow, shared) do
    Task.async(fn -> run(flow, shared) end)
  end
  
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
  Runs a batch flow with the given shared state, processing items in parallel.
  
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
  defdelegate run_parallel_batch(flow, shared), to: PocketFlex.ParallelBatchFlow
end
