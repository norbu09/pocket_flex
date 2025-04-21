# Define callbacks to manage ETS state between tests - MOVED to test/support/test_callbacks.ex
# defmodule PocketFlex.TestCallbacks do
#   use ExUnit.Callbacks
#
#   # Clear the ETS table before each test to ensure isolation
#   setup :set_ets_clean_state do
#     :ets.delete_all_objects(:pocket_flex_shared_state)
#     :ok
#   end
# end

# Configure ExUnit to use the callbacks (defined in test/support/test_callbacks.ex)
ExUnit.configure(callbacks: [PocketFlex.TestCallbacks])

# Start ExUnit
ExUnit.start()
