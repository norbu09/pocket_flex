defmodule PocketFlex.Examples.AsyncBatchExampleTest do
  use ExUnit.Case, async: true

  alias PocketFlex.Examples.AsyncBatchExample

  @urls ["http://a", "http://b", "http://c"]

  describe "AsyncBatchExample" do
    test "run/1 returns aggregated results" do
      {:ok, result} = AsyncBatchExample.run(@urls)
      assert result.total_urls == length(@urls)
      assert is_integer(result.total_word_count)
      assert is_float(result.average_word_count)
      assert %DateTime{} = result.timestamp
    end

    test "run_parallel/1 returns aggregated results" do
      {:ok, result} = AsyncBatchExample.run_parallel(@urls)
      assert result.total_urls == length(@urls)
      assert is_integer(result.total_word_count)
      assert is_float(result.average_word_count)
      assert %DateTime{} = result.timestamp
    end
  end
end
