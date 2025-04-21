# test/support/test_callbacks.ex
defmodule PocketFlex.TestCallbacks do
  use ExUnit.Callbacks

  # Clear the ETS table before each test to ensure isolation
  # This assumes the ETS table (:pocket_flex_shared_state) is started
  # by the application's supervision tree.
  setup :set_ets_clean_state do
    PocketFlex.StateStorage.ETS.clear_table()
    :ok
  end
end
