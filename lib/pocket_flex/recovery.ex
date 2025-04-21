defmodule PocketFlex.Recovery do
  @moduledoc """
  Provides error recovery mechanisms for PocketFlex flows.

  This module handles:
  - Classifying errors into standard categories
  - Determining recovery strategies based on error types
  - Implementing recovery mechanisms like retries with backoff
  - Providing fallback mechanisms for errors

  ## Telemetry Integration

  This module is designed to be extended with telemetry integration in the future.
  Recovery attempts will emit telemetry events that can be consumed by telemetry handlers.
  """

  require Logger

  @doc """
  Attempts to recover from an error based on its type and context.

  ## Parameters
    - error: The error to recover from
    - context: The context where the error occurred
    - state: The current state
    - recovery_opts: Options for recovery

  ## Returns
    - `{:ok, recovered_state}` if recovery was successful
    - `{:error, reason}` if recovery failed
  """
  @spec attempt_recovery(term(), atom(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def attempt_recovery(error, context, state, recovery_opts \\ []) do
    error_category = classify_error(error)

    # Future telemetry integration point
    # :telemetry.execute(
    #   [:pocket_flex, :recovery, :attempt],
    #   %{system_time: System.system_time()},
    #   %{error_category: error_category, context: context}
    # )

    case get_recovery_strategy(error_category, context) do
      {:retry, max_retries} ->
        retry_with_backoff(error, context, state, max_retries, recovery_opts)

      {:fallback, fallback_fn} when is_function(fallback_fn, 1) ->
        try do
          result = {:ok, fallback_fn.(state)}

          # Future telemetry integration point
          # :telemetry.execute(
          #   [:pocket_flex, :recovery, :fallback_success],
          #   %{system_time: System.system_time()},
          #   %{error_category: error_category, context: context}
          # )

          result
        rescue
          e ->
            # Future telemetry integration point
            # :telemetry.execute(
            #   [:pocket_flex, :recovery, :fallback_failed],
            #   %{system_time: System.system_time()},
            #   %{error_category: error_category, context: context, error: e}
            # )

            PocketFlex.ErrorHandler.report_error(e, :fallback_failed, %{
              original_error: error,
              context: context
            })
        end

      :skip_node ->
        # Future telemetry integration point
        # :telemetry.execute(
        #   [:pocket_flex, :recovery, :skip_node],
        #   %{system_time: System.system_time()},
        #   %{error_category: error_category, context: context}
        # )

        {:ok, state}

      :abort_flow ->
        # Future telemetry integration point
        # :telemetry.execute(
        #   [:pocket_flex, :recovery, :abort_flow],
        #   %{system_time: System.system_time()},
        #   %{error_category: error_category, context: context}
        # )

        {:error, %{original_error: error, reason: :flow_aborted, context: context}}

      _ ->
        # Future telemetry integration point
        # :telemetry.execute(
        #   [:pocket_flex, :recovery, :no_strategy],
        #   %{system_time: System.system_time()},
        #   %{error_category: error_category, context: context}
        # )

        {:error, %{original_error: error, reason: :no_recovery_strategy, context: context}}
    end
  end

  @doc """
  Classifies an error into a standard category.

  ## Parameters
    - error: The error to classify

  ## Returns
    The error category as an atom
  """
  @spec classify_error(term()) :: atom()
  def classify_error(error) do
    cond do
      is_exception(error) && match?(%{__exception__: true}, error) ->
        classify_exception(error)

      is_atom(error) ->
        error

      is_binary(error) ->
        :string_error

      is_map(error) ->
        :map_error

      true ->
        :unknown_error
    end
  end

  # Private functions

  defp classify_exception(exception) do
    cond do
      match?(%ArgumentError{}, exception) -> :argument_error
      match?(%ArithmeticError{}, exception) -> :arithmetic_error
      match?(%ErlangError{}, exception) -> :erlang_error
      match?(%FunctionClauseError{}, exception) -> :function_clause_error
      match?(%KeyError{}, exception) -> :key_error
      match?(%MatchError{}, exception) -> :match_error
      match?(%RuntimeError{}, exception) -> :runtime_error
      match?(%UndefinedFunctionError{}, exception) -> :undefined_function_error
      true -> :unknown_exception
    end
  end

  defp get_recovery_strategy(error_category, context) do
    # This could be made configurable in the future
    case {error_category, context} do
      # Network errors can be retried
      {:network_error, _} -> {:retry, 3}
      # Timeout errors can be retried with longer timeouts
      {:timeout, _} -> {:retry, 2}
      # For node execution errors, provide a fallback
      {_, :node_execution} -> {:fallback, &default_fallback/1}
      # For prep errors, skip the node
      {_, :node_prep} -> :skip_node
      # For critical errors, abort the flow
      {:critical_error, _} -> :abort_flow
      # Default strategy
      {_, _} -> :no_strategy
    end
  end

  defp retry_with_backoff(error, context, state, max_retries, opts) do
    retry_fn = Keyword.get(opts, :retry_fn)
    base_delay = Keyword.get(opts, :base_delay, 100)
    max_delay = Keyword.get(opts, :max_delay, 5000)

    # Future telemetry integration point
    # :telemetry.execute(
    #   [:pocket_flex, :recovery, :retry_start],
    #   %{system_time: System.system_time()},
    #   %{max_retries: max_retries, base_delay: base_delay, max_delay: max_delay}
    # )

    do_retry_with_backoff(error, context, state, retry_fn, max_retries, 0, base_delay, max_delay)
  end

  defp do_retry_with_backoff(
         _error,
         _context,
         state,
         _retry_fn,
         _max_retries,
         current_retry,
         _base_delay,
         _max_delay
       )
       when current_retry < 0 do
    {:ok, state}
  end

  defp do_retry_with_backoff(
         _error,
         _context,
         state,
         nil,
         _max_retries,
         _current_retry,
         _base_delay,
         _max_delay
       ) do
    {:ok, state}
  end

  defp do_retry_with_backoff(
         _error,
         _context,
         state,
         _retry_fn,
         max_retries,
         current_retry,
         _base_delay,
         _max_delay
       )
       when current_retry >= max_retries do
    # Future telemetry integration point
    # :telemetry.execute(
    #   [:pocket_flex, :recovery, :retry_max_exceeded],
    #   %{system_time: System.system_time()},
    #   %{max_retries: max_retries, attempts: current_retry}
    # )

    {:error, %{reason: :max_retries_exceeded, retries: current_retry, state: state}}
  end

  defp do_retry_with_backoff(
         error,
         context,
         state,
         retry_fn,
         max_retries,
         current_retry,
         base_delay,
         max_delay
       ) do
    # Calculate exponential backoff delay
    delay = min(base_delay * :math.pow(2, current_retry), max_delay)

    # Sleep before retry
    Process.sleep(round(delay))

    # Future telemetry integration point
    # :telemetry.execute(
    #   [:pocket_flex, :recovery, :retry_attempt],
    #   %{system_time: System.system_time()},
    #   %{attempt: current_retry + 1, max_retries: max_retries, delay: delay}
    # )

    # Attempt the retry
    try do
      case retry_fn.(state) do
        {:ok, new_state} ->
          # Future telemetry integration point
          # :telemetry.execute(
          #   [:pocket_flex, :recovery, :retry_success],
          #   %{system_time: System.system_time()},
          #   %{attempt: current_retry + 1, max_retries: max_retries}
          # )

          {:ok, new_state}

        {:error, new_error} ->
          Logger.warning(
            "Retry attempt #{current_retry + 1} failed for error #{inspect(error)}: #{inspect(new_error)}"
          )

          # Future telemetry integration point
          # :telemetry.execute(
          #   [:pocket_flex, :recovery, :retry_failure],
          #   %{system_time: System.system_time()},
          #   %{attempt: current_retry + 1, max_retries: max_retries, error: new_error}
          # )

          do_retry_with_backoff(
            new_error,
            context,
            state,
            retry_fn,
            max_retries,
            current_retry + 1,
            base_delay,
            max_delay
          )
      end
    rescue
      e ->
        Logger.warning(
          "Retry attempt #{current_retry + 1} failed for error #{inspect(error)}: #{inspect(e)}"
        )

        # Future telemetry integration point
        # :telemetry.execute(
        #   [:pocket_flex, :recovery, :retry_exception],
        #   %{system_time: System.system_time()},
        #   %{attempt: current_retry + 1, max_retries: max_retries, error: e}
        # )

        do_retry_with_backoff(
          e,
          context,
          state,
          retry_fn,
          max_retries,
          current_retry + 1,
          base_delay,
          max_delay
        )
    end
  end

  defp default_fallback(state) do
    # Simply return the state unchanged as a fallback strategy
    state
  end
end
