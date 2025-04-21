defmodule PocketFlex.AsyncFlow do
  @moduledoc """
  Manages the asynchronous execution of connected nodes.
  
  Extends the basic Flow module with support for asynchronous
  execution using Elixir processes.
  """
  
  @doc """
  Runs the flow asynchronously with the given shared state.
  
  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run_async(PocketFlex.Flow.t(), map()) :: {:ok, map()} | {:error, term()}
  def run_async(flow, shared) do
    Task.async(fn -> PocketFlex.Flow.run(flow, shared) end)
    |> Task.await(:infinity)
  end
  
  @doc """
  Runs the flow asynchronously with the given shared state and timeout.
  
  ## Parameters
    - flow: The flow to run
    - shared: The initial shared state
    - timeout: The maximum time to wait for completion (in milliseconds)
    
  ## Returns
    A tuple containing:
    - :ok and the final shared state, or
    - :error and an error reason
  """
  @spec run_async(PocketFlex.Flow.t(), map(), timeout()) :: {:ok, map()} | {:error, term()}
  def run_async(flow, shared, timeout) do
    Task.async(fn -> PocketFlex.Flow.run(flow, shared) end)
    |> Task.await(timeout)
  end
end
