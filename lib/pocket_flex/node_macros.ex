defmodule PocketFlex.NodeMacros do
  @moduledoc """
  Provides macros for simplifying node implementation in PocketFlex.

  This module allows developers to create nodes with minimal boilerplate
  by providing default implementations for optional callbacks. It enforces:

  - Atoms for action keys in `post/3` (e.g., `:default`, `:success`, `:error`).
  - Tuple-based error handling (`{:ok, ...}`/`{:error, ...}`) for all node and flow operations.
  - Never overwriting the shared state with a raw value in `post/3`.
  - Customization of retry and wait logic via options.

  ## Best Practices

  - Override only the callbacks you need.
  - Use pattern matching in function heads.
  - See the main docs and guides for error handling and migration notes.
  """

  defmacro __using__(opts) do
    quote do
      @behaviour PocketFlex.Node

      # Default implementations
      @impl true
      def prep(_shared), do: nil

      @impl true
      def post(shared, _prep_res, exec_res) do
        case exec_res do
          {action, state} when is_atom(action) or is_binary(action) ->
            {action, state}

          {:ok, action, state} when (is_atom(action) or is_binary(action)) and is_map(state) ->
            {action, state}

          {:ok, state} when is_map(state) ->
            {"default", state}

          {:ok, value} when is_map(shared) ->
            {"default", shared}

          value when is_map(shared) ->
            {"default", shared}

          other ->
            {"default", other}
        end
      end

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
