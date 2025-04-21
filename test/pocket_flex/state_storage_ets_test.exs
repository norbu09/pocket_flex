defmodule PocketFlex.StateStorage.ETS.Test do
  use ExUnit.Case, async: false
  alias PocketFlex.StateStorage.ETS

  setup_all do
    # Ensure ETS is started for all tests in this module
    case ETS.start_link(nil) do
      {:ok, _} ->
        :ok

      {:error, {:already_started, _}} ->
        :ok

      other ->
        IO.inspect(other, label: "ETS.start_link/1 unexpected result")
        :ok
    end

    :ok
  end

  setup do
    # Clear the ETS table for test isolation
    ETS.clear_table()
    :ok
  end

  test "get_state returns empty map when no entry" do
    assert ETS.get_state("missing") == %{}
  end

  test "update_state and get_state works" do
    ETS.update_state("flow1", %{a: 1})
    assert ETS.get_state("flow1")[:a] == 1
  end

  test "merge_state merges existing state" do
    ETS.update_state("flow2", %{a: 1})
    ETS.merge_state("flow2", %{b: 2})
    assert ETS.get_state("flow2") == %{a: 1, b: 2}
  end

  test "cleanup removes entry" do
    ETS.update_state("flow3", %{a: 3})
    ETS.cleanup("flow3")
    assert ETS.get_state("flow3") == %{}
  end
end
