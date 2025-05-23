defmodule PocketFlex.ErrorHandler do
  @moduledoc """
  Standardizes error reporting and handling for PocketFlex flows and nodes.

  This module provides functions for logging, formatting, and propagating errors
  with consistent structure and context across the system.

  ## Conventions

  - All error handling must use tuple-based error handling: `{:ok, ...}` or `{:error, ...}`
  - Use atoms for error reasons and control flow
  - Include stacktraces in error metadata during development

  ## Best Practices

  - Use pattern matching in function heads for error handling
  - Document all public functions and modules
  - Provide meaningful error messages with context
  - Use Logger for logging errors, not IO.inspect
  - See the guides for error handling and troubleshooting
  """

  require Logger
  alias PocketFlex.Monitoring
  alias PocketFlex.Recovery

  @doc """
  Reports an error with context and metadata, logging it in a standardized format.

  ## Parameters
    - error: The error term
    - context: Contextual information about where the error occurred
    - metadata: Additional metadata for the error (optional, default: `%{}`)

  ## Returns
    A standardized error tuple

  ## Example

      iex> PocketFlex.ErrorHandler.report_error(:timeout, :node_exec, %{node: :foo})
      {:error, %{error: :timeout, context: :node_exec, timestamp: ..., metadata: %{node: :foo}}}
  """
  @spec report_error(term(), atom(), map()) :: {:error, map()}
  def report_error(error, context, metadata \\ %{}) do
    error_info = %{
      error: error,
      context: context,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }

    # Log the error with standardized format
    Logger.error(
      "PocketFlex error in #{context}: #{inspect(error)}, metadata: #{inspect(metadata)}"
    )

    # Future telemetry integration point
    # :telemetry.execute(
    #   [:pocket_flex, :error, :report],
    #   %{system_time: System.system_time()},
    #   %{error: error, context: context}
    # )

    {:error, error_info}
  end

  # Delegate monitoring functions to PocketFlex.Monitoring

  @doc """
  Starts monitoring a flow execution.

  See `PocketFlex.Monitoring.start_monitoring/3` for details.
  """
  @spec start_monitoring(String.t(), PocketFlex.Flow.t(), map()) :: :ok
  defdelegate start_monitoring(flow_id, flow, initial_state), to: Monitoring

  @doc """
  Updates monitoring information for a flow execution.

  See `PocketFlex.Monitoring.update_monitoring/4` for details.
  """
  @spec update_monitoring(String.t(), module(), atom(), map()) :: :ok
  defdelegate update_monitoring(flow_id, current_node, status, metadata \\ %{}), to: Monitoring

  @doc """
  Records an error in the flow monitoring.

  See `PocketFlex.Monitoring.record_error/4` for details.
  """
  @spec record_error(String.t(), term(), module(), map()) :: :ok
  defdelegate record_error(flow_id, error, node, metadata \\ %{}), to: Monitoring

  @doc """
  Completes monitoring for a flow execution.

  See `PocketFlex.Monitoring.complete_monitoring/3` for details.
  """
  @spec complete_monitoring(String.t(), atom(), map()) :: :ok
  defdelegate complete_monitoring(flow_id, status, result), to: Monitoring

  @doc """
  Gets monitoring information for a flow.

  See `PocketFlex.Monitoring.get_monitoring/1` for details.
  """
  @spec get_monitoring(String.t()) :: map()
  defdelegate get_monitoring(flow_id), to: Monitoring

  @doc """
  Cleans up monitoring data for a flow.

  See `PocketFlex.Monitoring.cleanup_monitoring/1` for details.
  """
  @spec cleanup_monitoring(String.t()) :: :ok
  defdelegate cleanup_monitoring(flow_id), to: Monitoring

  # Delegate recovery functions to PocketFlex.Recovery

  @doc """
  Attempts to recover from an error based on its type and context.

  See `PocketFlex.Recovery.attempt_recovery/4` for details.
  """
  @spec attempt_recovery(term(), atom(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  defdelegate attempt_recovery(error, context, state, recovery_opts \\ []), to: Recovery

  @doc """
  Classifies an error into a standard category.

  See `PocketFlex.Recovery.classify_error/1` for details.
  """
  @spec classify_error(term()) :: atom()
  defdelegate classify_error(error), to: Recovery
end
