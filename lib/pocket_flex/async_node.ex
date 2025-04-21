defmodule PocketFlex.AsyncNode do
  @moduledoc """
  Behavior module for asynchronous nodes.
  
  Extends the basic Node behavior with asynchronous versions of
  the callbacks for concurrent execution.
  """
  
  @callback prep_async(shared :: map()) :: {:ok, any()} | {:error, term()}
  @callback exec_async(prep_result :: any()) :: {:ok, Task.t()} | {:error, term()}
  @callback post_async(shared :: map(), prep_result :: any(), exec_result :: any()) :: 
    {:ok, {String.t() | nil, map()}} | {:error, term()}
  
  defmacro __using__(_opts) do
    quote do
      @behaviour PocketFlex.Node
      @behaviour PocketFlex.AsyncNode
      
      # Default implementations for Node callbacks
      @impl PocketFlex.Node
      def prep(shared) do
        case prep_async(shared) do
          {:ok, result} -> result
          {:error, reason} -> raise "Async prep failed: #{inspect(reason)}"
        end
      end
      
      @impl PocketFlex.Node
      def exec(prep_result) do
        case exec_async(prep_result) do
          {:ok, task} when is_struct(task, Task) -> 
            Task.await(task)
          {:ok, result} -> 
            result
          {:error, reason} -> 
            raise "Async exec failed: #{inspect(reason)}"
        end
      end
      
      @impl PocketFlex.Node
      def post(shared, prep_result, exec_result) do
        case post_async(shared, prep_result, exec_result) do
          {:ok, result} -> result
          {:error, reason} -> raise "Async post failed: #{inspect(reason)}"
        end
      end
      
      # Default implementations for AsyncNode callbacks
      @impl PocketFlex.AsyncNode
      def prep_async(_shared), do: {:ok, nil}
      
      @impl PocketFlex.AsyncNode
      def exec_async(prep_result) do
        # This is the default implementation that should be overridden
        task = Task.async(fn -> prep_result end)
        {:ok, task}
      end
      
      @impl PocketFlex.AsyncNode
      def post_async(shared, _prep_res, exec_res), do: {:ok, {"default", shared}}
      
      # Allow overriding
      defoverridable [
        prep: 1, 
        exec: 1, 
        post: 3, 
        prep_async: 1,
        exec_async: 1,
        post_async: 3
      ]
    end
  end
end
