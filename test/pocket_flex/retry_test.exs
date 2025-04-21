defmodule PocketFlex.RetryTest do
  use ExUnit.Case
  require Logger

  alias PocketFlex.Retry

  describe "retry function" do
    test "retry succeeds on first attempt" do
      # Define a function that succeeds immediately
      function = fn -> "success" end

      # Call retry
      result = Retry.retry(function)

      # Verify the result
      assert result == "success"
    end

    test "retry succeeds after failures" do
      # Set up a counter to track attempts
      attempt_count = :ets.new(:attempt_count, [:set, :public])
      :ets.insert(attempt_count, {:count, 0})

      # Define a function that succeeds on the third attempt
      function = fn ->
        count = :ets.update_counter(attempt_count, :count, 1)

        if count < 3 do
          raise "Simulated failure on attempt #{count}"
        else
          "success on attempt #{count}"
        end
      end

      # Call retry with enough retries
      result = Retry.retry(function, max_retries: 3, base_delay: 10, max_delay: 50)

      # Verify the result
      assert result == "success on attempt 3"
      assert :ets.lookup(attempt_count, :count) == [{:count, 3}]

      # Clean up
      :ets.delete(attempt_count)
    end

    test "retry fails after max retries" do
      # Set up a counter to track attempts
      attempt_count = :ets.new(:attempt_count, [:set, :public])
      :ets.insert(attempt_count, {:count, 0})

      # Define a function that always fails
      function = fn ->
        count = :ets.update_counter(attempt_count, :count, 1)
        raise "Simulated failure on attempt #{count}"
      end

      # Call retry with limited retries
      result = Retry.retry(function, max_retries: 2, base_delay: 10, max_delay: 50)

      # Verify the result
      assert match?({:error, %RuntimeError{}}, result)
      # Initial + 2 retries
      assert :ets.lookup(attempt_count, :count) == [{:count, 3}]

      # Clean up
      :ets.delete(attempt_count)
    end

    test "retry with custom retry_on function" do
      # Set up a counter to track attempts
      attempt_count = :ets.new(:attempt_count, [:set, :public])
      :ets.insert(attempt_count, {:count, 0})

      # Define a function that raises different errors
      function = fn ->
        count = :ets.update_counter(attempt_count, :count, 1)

        case count do
          1 -> raise ArgumentError, "Retry this"
          2 -> raise KeyError, "Don't retry this"
          _ -> "success"
        end
      end

      # Call retry with a custom retry_on function that only retries ArgumentError
      result =
        Retry.retry(function,
          max_retries: 3,
          base_delay: 10,
          retry_on: fn
            %ArgumentError{} -> true
            _ -> false
          end
        )

      # Verify the result - should fail on KeyError without retrying
      assert match?({:error, %KeyError{}}, result)
      assert :ets.lookup(attempt_count, :count) == [{:count, 2}]

      # Clean up
      :ets.delete(attempt_count)
    end
  end

  describe "with_backoff function" do
    test "with_backoff uses exponential backoff" do
      # Set up a counter to track attempts and timing
      state = :ets.new(:backoff_state, [:set, :public])
      :ets.insert(state, {:count, 0})
      :ets.insert(state, {:last_time, System.monotonic_time(:millisecond)})

      # Define a function that tracks time between attempts
      function = fn ->
        count = :ets.update_counter(state, :count, 1)
        now = System.monotonic_time(:millisecond)

        # Get the time since last attempt
        [{:last_time, last_time}] = :ets.lookup(state, :last_time)
        time_diff = now - last_time
        :ets.insert(state, {:last_time, now})
        :ets.insert(state, {count, time_diff})

        if count < 3 do
          raise "Simulated failure on attempt #{count}"
        else
          "success on attempt #{count}"
        end
      end

      # Call with_backoff
      result = Retry.with_backoff(function, max_retries: 3, base_delay: 20, max_delay: 100)

      # Verify the result
      assert result == "success on attempt 3"

      # Verify that delays increased (approximately)
      # First attempt has no delay
      [{2, delay1}] = :ets.lookup(state, 2)
      [{3, delay2}] = :ets.lookup(state, 3)

      # The second delay should be longer than the first
      assert delay2 > delay1

      # Clean up
      :ets.delete(state)
    end
  end

  describe "with_circuit_breaker function" do
    test "with_circuit_breaker delegates to retry" do
      # Define a function that succeeds immediately
      function = fn -> "success" end

      # Call with_circuit_breaker
      result = Retry.with_circuit_breaker(function)

      # Verify the result
      assert result == "success"
    end

    test "with_circuit_breaker handles closed circuit" do
      # Set up a counter to track attempts
      attempt_count = :ets.new(:attempt_count, [:set, :public])
      :ets.insert(attempt_count, {:count, 0})

      # Define a function that succeeds on the second attempt
      function = fn ->
        count = :ets.update_counter(attempt_count, :count, 1)

        if count < 2 do
          raise "Simulated failure on attempt #{count}"
        else
          "success on attempt #{count}"
        end
      end

      # Call with_circuit_breaker
      result =
        Retry.with_circuit_breaker(function,
          max_failures: 2,
          cooldown_ms: 100,
          retry_opts: [max_retries: 2, base_delay: 10]
        )

      # Verify the result
      assert result == "success on attempt 2"
      assert :ets.lookup(attempt_count, :count) == [{:count, 2}]

      # Clean up
      :ets.delete(attempt_count)
    end
  end
end
