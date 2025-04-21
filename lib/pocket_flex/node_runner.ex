defmodule PocketFlex.NodeRunner do
  @moduledoc false

  require Logger

  @doc """
  Runs a node with the given shared state.

  ## Parameters
    - node: The node module to run
    - shared: The shared state map
    
  ## Returns
    A tuple containing:
    - :ok, the action key, and the updated shared state, or
    - :error and an error reason
  """
  @spec run_node(module(), map()) :: {:ok, String.t() | nil, map()} | {:error, term()}
  def run_node(node, shared) do
    try do
      # Prepare data
      prep_result = node.prep(shared)

      # Execute with retry logic
      exec_result = execute_with_retries(node, prep_result, 0)

      # Post-process
      {action, updated_shared} = node.post(shared, prep_result, exec_result)

      {:ok, action, updated_shared}
    rescue
      e ->
        Logger.error("Error running node: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc false
  defp execute_with_retries(node, prep_result, retry_count) do
    try do
      node.exec(prep_result)
    rescue
      e ->
        max_retries =
          if function_exported?(node, :max_retries, 0), do: node.max_retries(), else: 1

        wait_time = if function_exported?(node, :wait_time, 0), do: node.wait_time(), else: 0

        if retry_count < max_retries - 1 do
          if wait_time > 0, do: Process.sleep(wait_time)
          execute_with_retries(node, prep_result, retry_count + 1)
        else
          if function_exported?(node, :exec_fallback, 2) do
            node.exec_fallback(prep_result, e)
          else
            raise e
          end
        end
    end
  end
end
