defmodule PocketFlex.NodeRunner do
  @moduledoc """
  Handles the execution of nodes in a flow.

  This module provides functionality for running nodes with error handling,
  retry logic, and monitoring capabilities.
  """

  require Logger
  alias PocketFlex.ErrorHandler

  @doc """
  Runs a node with the given shared state.

  ## Parameters
    - node: The node module to run
    - shared: The shared state map
    - flow_id: Optional flow ID for monitoring
    
  ## Returns
    A tuple containing:
    - :ok, the action key, and the updated shared state, or
    - :error and an error reason
  """
  @spec run_node(module(), map(), String.t() | nil) ::
          {:ok, atom() | nil, map()} | {:error, term()}
  def run_node(node, shared, flow_id \\ nil) do
    try do
      # Update monitoring if flow_id is provided
      if flow_id, do: ErrorHandler.update_monitoring(flow_id, node, :running)

      # Prepare data
      case node_prep(node, shared) do
        {:ok, prep_result} ->
          # Execute with retry logic
          case execute_with_retries(node, prep_result, 0, flow_id) do
            {:ok, exec_result} ->
              # Post-process
              case node_post(node, shared, prep_result, exec_result) do
                {:ok, action, updated_shared} ->
                  # Update monitoring if flow_id is provided
                  if flow_id, do: ErrorHandler.update_monitoring(flow_id, node, :completed)
                  {:ok, action, updated_shared}

                {:error, reason} ->
                  if flow_id do
                    ErrorHandler.record_error(flow_id, reason, node, %{stage: :post})
                  end

                  ErrorHandler.report_error(reason, :node_post, %{node: node})
              end

            {:error, reason} ->
              if flow_id do
                ErrorHandler.record_error(flow_id, reason, node, %{stage: :exec})
              end

              ErrorHandler.report_error(reason, :node_execution, %{node: node})
          end

        {:error, reason} ->
          if flow_id do
            ErrorHandler.record_error(flow_id, reason, node, %{stage: :prep})
          end

          ErrorHandler.report_error(reason, :node_prep, %{node: node})
      end
    rescue
      e ->
        if flow_id do
          ErrorHandler.record_error(flow_id, e, node, %{stage: :unknown})
        end

        ErrorHandler.report_error(e, :node_execution, %{node: node, stacktrace: __STACKTRACE__})
    end
  end

  @doc """
  Executes the node's prep function with error handling.

  ## Returns
    - `{:ok, prep_result}` on success
    - `{:error, reason}` on failure
  """
  @spec node_prep(module(), map()) :: {:ok, term()} | {:error, term()}
  def node_prep(node, state) do
    try do
      {:ok, node.prep(state)}
    rescue
      error ->
        Logger.error("Error in node prep: #{inspect(error)}")
        {:error, {:prep_failed, error}}
    end
  end

  @doc """
  Executes the node's post function with error handling.

  ## Returns
    - `{:ok, action, updated_state}` on success
    - `{:error, reason}` on failure
  """
  @spec node_post(module(), map(), term(), term()) :: {:ok, atom(), map()} | {:error, term()}
  def node_post(node, state, prep_result, exec_result) do
    try do
      {action, updated_state} = node.post(state, prep_result, exec_result)
      {:ok, action, updated_state}
    rescue
      error ->
        Logger.error("Error in node post: #{inspect(error)}")
        {:error, {:post_failed, error}}
    end
  end

  @doc """
  Executes a node with retry logic.

  ## Parameters
    - node: The node module to run
    - prep_result: The result from the prep phase
    - retry_count: The current retry count
    - flow_id: Optional flow ID for monitoring
    
  ## Returns
    - `{:ok, exec_result}` on success
    - `{:error, reason}` on failure
  """
  @spec execute_with_retries(module(), term(), non_neg_integer(), String.t() | nil) ::
          {:ok, term()} | {:error, term()}
  def execute_with_retries(node, prep_result, retry_count, flow_id \\ nil) do
    try do
      {:ok, node.exec(prep_result)}
    rescue
      e ->
        max_retries =
          if function_exported?(node, :max_retries, 0), do: node.max_retries(), else: 1

        wait_time = if function_exported?(node, :wait_time, 0), do: node.wait_time(), else: 0

        # Log retry attempt
        if retry_count > 0 do
          Logger.warning("Retry attempt #{retry_count} for #{inspect(node)}")

          if flow_id do
            ErrorHandler.update_monitoring(flow_id, node, :retrying, %{
              retry_count: retry_count,
              max_retries: max_retries
            })
          end
        end

        if retry_count < max_retries - 1 do
          if wait_time > 0, do: Process.sleep(wait_time)
          execute_with_retries(node, prep_result, retry_count + 1, flow_id)
        else
          if function_exported?(node, :exec_fallback, 2) do
            try do
              Logger.info("Using fallback for #{inspect(node)}")

              if flow_id do
                ErrorHandler.update_monitoring(flow_id, node, :fallback)
              end

              {:ok, node.exec_fallback(prep_result, e)}
            rescue
              fallback_error ->
                Logger.error("Fallback failed for #{inspect(node)}: #{inspect(fallback_error)}")
                {:error, {:fallback_failed, fallback_error}}
            end
          else
            # Try to recover using the error handler
            case ErrorHandler.attempt_recovery(e, :node_execution, %{
                   node: node,
                   prep_result: prep_result
                 }) do
              {:ok, recovery_result} ->
                Logger.info("Recovered from error in #{inspect(node)}")
                {:ok, recovery_result}

              _ ->
                Logger.error("Max retries exceeded for #{inspect(node)}: #{inspect(e)}")
                {:error, {:max_retries_exceeded, e}}
            end
          end
        end
    end
  end
end
