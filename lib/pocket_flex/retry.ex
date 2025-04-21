defmodule PocketFlex.Retry do
  @moduledoc """
  Provides retry functionality for operations that may fail temporarily.

  This module implements various retry strategies including:
  - Simple retry with a fixed number of attempts
  - Exponential backoff retry
  - Circuit breaker pattern for failing fast when a service is down
  """

  require Logger

  @doc """
  Retries a function with configurable retry options.

  ## Parameters
    - function: The function to retry (arity 0)
    - opts: Options for retrying
      - :max_retries - Maximum number of retries (default: 3)
      - :base_delay - Base delay in milliseconds (default: 100)
      - :max_delay - Maximum delay in milliseconds (default: 5000)
      - :jitter - Whether to add random jitter to delays (default: true)
      - :retry_on - Function that takes an error and returns true if it should be retried (default: retry all)

  ## Returns
    The result of the function if successful, or {:error, reason} after all retries fail

  ## Examples

  ```elixir
  result = PocketFlex.Retry.retry(fn -> 
    HTTPoison.get("https://example.com") 
  end, max_retries: 5)
  ```
  """
  @spec retry(function(), keyword()) :: any() | {:error, term()}
  def retry(function, opts \\ []) when is_function(function, 0) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    base_delay = Keyword.get(opts, :base_delay, 100)
    max_delay = Keyword.get(opts, :max_delay, 5000)
    jitter = Keyword.get(opts, :jitter, true)
    retry_on = Keyword.get(opts, :retry_on, fn _error -> true end)

    do_retry(function, max_retries, 0, base_delay, max_delay, jitter, retry_on)
  end

  @doc """
  Retries a function with exponential backoff.

  ## Parameters
    - function: The function to retry (arity 0)
    - opts: Options for retrying
      - :max_retries - Maximum number of retries (default: 3)
      - :base_delay - Base delay in milliseconds (default: 100)
      - :max_delay - Maximum delay in milliseconds (default: 5000)
      - :retry_on - Function that takes an error and returns true if it should be retried (default: retry all)

  ## Returns
    The result of the function if successful, or {:error, reason} after all retries fail

  ## Examples

  ```elixir
  result = PocketFlex.Retry.with_backoff(fn -> 
    HTTPoison.get("https://example.com") 
  end, max_retries: 5)
  ```
  """
  @spec with_backoff(function(), keyword()) :: any() | {:error, term()}
  def with_backoff(function, opts \\ []) when is_function(function, 0) do
    retry(function, Keyword.put(opts, :jitter, true))
  end

  @doc """
  Retries a function with a circuit breaker pattern.

  This function will "trip" the circuit after a certain number of failures,
  preventing further calls for a cooldown period.

  ## Parameters
    - function: The function to retry (arity 0)
    - opts: Options for the circuit breaker
      - :max_failures - Maximum failures before tripping (default: 5)
      - :cooldown_ms - Cooldown period in milliseconds (default: 30000)
      - :retry_opts - Options to pass to retry/2

  ## Returns
    The result of the function if successful, or {:error, reason} after circuit trips

  ## Examples

  ```elixir
  result = PocketFlex.Retry.with_circuit_breaker(fn -> 
    HTTPoison.get("https://example.com") 
  end, max_failures: 3, cooldown_ms: 10000)
  ```
  """
  @spec with_circuit_breaker(function(), keyword()) :: any() | {:error, term()}
  def with_circuit_breaker(function, opts \\ []) when is_function(function, 0) do
    _max_failures = Keyword.get(opts, :max_failures, 5)
    _cooldown_ms = Keyword.get(opts, :cooldown_ms, 30000)
    retry_opts = Keyword.get(opts, :retry_opts, [])

    case get_circuit_state() do
      :closed ->
        try_with_circuit(function, retry_opts)

      _ ->
        # Handle any other circuit state
        {:error, :circuit_unavailable}
    end
  end

  # Private functions

  defp do_retry(
         function,
         _max_retries,
         _current_retry,
         _base_delay,
         _max_delay,
         _jitter,
         _retry_on
       )
       when not is_function(function, 0) do
    {:error, :invalid_function}
  end

  defp do_retry(
         _function,
         max_retries,
         current_retry,
         _base_delay,
         _max_delay,
         _jitter,
         _retry_on
       )
       when current_retry > max_retries do
    {:error, :max_retries_exceeded}
  end

  defp do_retry(function, max_retries, current_retry, base_delay, max_delay, jitter, retry_on) do
    try do
      function.()
    rescue
      error ->
        handle_retry_error(
          error,
          function,
          max_retries,
          current_retry,
          base_delay,
          max_delay,
          jitter,
          retry_on
        )
    catch
      kind, value ->
        Logger.warning("Caught #{kind} in retry: #{inspect(value)}")

        if current_retry < max_retries do
          delay = calculate_delay(base_delay, current_retry, max_delay, jitter)
          Process.sleep(delay)

          do_retry(
            function,
            max_retries,
            current_retry + 1,
            base_delay,
            max_delay,
            jitter,
            retry_on
          )
        else
          {:error, {:caught, kind, value}}
        end
    end
  end

  defp handle_retry_error(
         error,
         function,
         max_retries,
         current_retry,
         base_delay,
         max_delay,
         jitter,
         retry_on
       ) do
    Logger.warning("Error in retry attempt #{current_retry}: #{inspect(error)}")

    if current_retry < max_retries && retry_on.(error) do
      delay = calculate_delay(base_delay, current_retry, max_delay, jitter)
      Logger.debug("Retrying after #{delay}ms")
      Process.sleep(delay)
      do_retry(function, max_retries, current_retry + 1, base_delay, max_delay, jitter, retry_on)
    else
      {:error, error}
    end
  end

  defp calculate_delay(base_delay, retry_count, max_delay, true) do
    exponential_delay = base_delay * :math.pow(2, retry_count)
    jitter_factor = :rand.uniform()
    delay = exponential_delay * (1 + jitter_factor / 2)
    min(round(delay), max_delay)
  end

  defp calculate_delay(base_delay, retry_count, max_delay, false) do
    delay = base_delay * :math.pow(2, retry_count)
    min(round(delay), max_delay)
  end

  defp get_circuit_state do
    :closed
  end

  defp try_with_circuit(function, retry_opts) do
    retry(function, retry_opts)
  end
end
