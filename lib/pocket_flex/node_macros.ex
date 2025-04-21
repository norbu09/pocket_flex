defmodule PocketFlex.NodeMacros do
  @moduledoc """
  Provides macros for simplifying node implementation.
  
  This module allows developers to create nodes with minimal boilerplate
  by providing default implementations for optional callbacks.
  """
  
  defmacro __using__(opts) do
    quote do
      @behaviour PocketFlex.Node
      
      # Default implementations
      @impl true
      def prep(_shared), do: nil
      
      @impl true
      def post(shared, _prep_res, exec_res), do: {"default", shared}
      
      @impl true
      def exec_fallback(_prep_res, exception), do: raise(exception)
      
      @impl true
      def max_retries(), do: unquote(Keyword.get(opts, :max_retries, 1))
      
      @impl true
      def wait_time(), do: unquote(Keyword.get(opts, :wait_time, 0))
      
      # Allow overriding any of these defaults
      defoverridable prep: 1, post: 3, exec_fallback: 2, max_retries: 0, wait_time: 0
    end
  end
end
