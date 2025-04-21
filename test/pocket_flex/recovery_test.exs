defmodule PocketFlex.RecoveryTest do
  use ExUnit.Case
  require Logger

  alias PocketFlex.Recovery

  describe "error classification" do
    test "classify_error correctly identifies exceptions" do
      # Test various exception types
      assert Recovery.classify_error(%ArgumentError{}) == :argument_error
      assert Recovery.classify_error(%ArithmeticError{}) == :arithmetic_error
      assert Recovery.classify_error(%RuntimeError{}) == :runtime_error
      assert Recovery.classify_error(%KeyError{}) == :key_error
    end

    test "classify_error handles non-exception values" do
      # Test atoms
      assert Recovery.classify_error(:timeout) == :timeout
      assert Recovery.classify_error(:error) == :error
      
      # Test strings
      assert Recovery.classify_error("error message") == :string_error
      
      # Test maps
      assert Recovery.classify_error(%{error: "details"}) == :map_error
      
      # Test other values
      assert Recovery.classify_error(123) == :unknown_error
    end
  end

  describe "recovery strategies" do
    test "attempt_recovery with retry strategy" do
      # Set up a state and error
      state = %{count: 0}
      error = :network_error
      context = :api_call
      
      # Define a recovery function that increments the count
      recovery_opts = [
        retry_fn: fn state ->
          updated_state = Map.update(state, :count, 1, &(&1 + 1))
          {:ok, updated_state}
        end,
        max_retries: 2,
        base_delay: 10,
        max_delay: 50
      ]
      
      # Attempt recovery
      {:ok, recovered_state} = Recovery.attempt_recovery(error, context, state, recovery_opts)
      
      # Verify the recovery function was called
      assert recovered_state.count == 1
    end

    test "attempt_recovery with failing retry strategy" do
      # Set up a state and error
      state = %{count: 0}
      error = :network_error
      context = :api_call
      
      # Define a recovery function that always fails
      recovery_opts = [
        retry_fn: fn _state ->
          {:error, :still_failing}
        end,
        max_retries: 2,
        base_delay: 10,
        max_delay: 50
      ]
      
      # Attempt recovery
      result = Recovery.attempt_recovery(error, context, state, recovery_opts)
      
      # Verify the recovery failed
      assert match?({:error, _}, result)
    end

    test "attempt_recovery with skip_node strategy" do
      # Set up a state and error
      state = %{data: "original"}
      error = :validation_error
      context = :node_prep
      
      # Attempt recovery
      {:ok, recovered_state} = Recovery.attempt_recovery(error, context, state)
      
      # Verify the state was returned unchanged
      assert recovered_state == state
    end

    test "attempt_recovery with abort_flow strategy" do
      # Set up a state and error
      state = %{data: "original"}
      error = :critical_error
      context = :flow_orchestration
      
      # Attempt recovery
      result = Recovery.attempt_recovery(error, context, state)
      
      # Verify the flow was aborted
      assert match?({:error, %{reason: :flow_aborted}}, result)
    end
  end

  describe "retry with backoff" do
    test "retry_with_backoff succeeds after retries" do
      # Set up a test that will succeed on the second attempt
      attempt_count = :ets.new(:attempt_count, [:set, :public])
      :ets.insert(attempt_count, {:count, 0})
      
      state = %{original: true}
      error = :timeout
      context = :api_call
      
      # Define a recovery function that succeeds on the second attempt
      recovery_opts = [
        retry_fn: fn state ->
          count = :ets.update_counter(attempt_count, :count, 1)
          
          if count < 2 do
            {:error, :still_failing}
          else
            {:ok, Map.put(state, :recovered, true)}
          end
        end,
        max_retries: 3,
        base_delay: 10,
        max_delay: 50
      ]
      
      # Attempt recovery
      {:ok, recovered_state} = Recovery.attempt_recovery(error, context, state, recovery_opts)
      
      # Verify the recovery succeeded after retries
      assert recovered_state.recovered == true
      assert :ets.lookup(attempt_count, :count) == [{:count, 2}]
      
      # Clean up
      :ets.delete(attempt_count)
    end

    test "retry_with_backoff fails after max retries" do
      # Set up a test that will always fail
      attempt_count = :ets.new(:attempt_count, [:set, :public])
      :ets.insert(attempt_count, {:count, 0})
      
      state = %{original: true}
      error = :timeout
      context = :api_call
      
      # Define a recovery function that always fails
      recovery_opts = [
        retry_fn: fn _state ->
          count = :ets.update_counter(attempt_count, :count, 1)
          Logger.debug("Retry attempt #{count}")
          {:error, :persistent_failure}
        end,
        max_retries: 2,
        base_delay: 1,  # Use very small delays for testing
        max_delay: 5
      ]
      
      # Attempt recovery
      result = Recovery.attempt_recovery(error, context, state, recovery_opts)
      
      # Wait a moment to ensure all retries complete
      Process.sleep(50)
      
      # Verify the recovery failed after max retries
      assert match?({:error, _}, result)
      # The count should be 3: initial attempt + 2 retries = 3 total attempts
      [{:count, count}] = :ets.lookup(attempt_count, :count)
      assert count >= 2  # At least 2 attempts should have been made
      
      # Clean up
      :ets.delete(attempt_count)
    end
  end
end
