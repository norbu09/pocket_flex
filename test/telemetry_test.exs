defmodule PocketFlex.TelemetryTest do
  use ExUnit.Case, async: true

  alias PocketFlex.Telemetry

  describe "Telemetry event emission and PubSub" do
    setup do
      # Subscribe to the telemetry PubSub topic
      Phoenix.PubSub.subscribe(PocketFlex.PubSub, "telemetry:events")
      :ok
    end

    test "emits and broadcasts a span event" do
      parent = self()
      ref = make_ref()
      meta = %{test: true, ref: ref}

      spawn(fn ->
        Telemetry.span([:pocket_flex, :test, :span], meta, fn ->
          :ok
        end)
        send(parent, :done)
      end)

      assert_receive {[:pocket_flex, :test, :span, :start], _meas, ^meta}, 200
      assert_receive {[:pocket_flex, :test, :span, :stop], _meas, %{test: true, ref: ^ref, result: :ok}}, 200
      assert_receive :done, 200
    end

    test "LLM span emits and broadcasts events" do
      meta = %{provider: "openai", model: "gpt-4o", prompt: "hi!"}
      Telemetry.llm_span([:pocket_flex, :llm, :call], meta, fn ->
        {:ok, %{response: "hello", usage: %{tokens: 5}}}
      end)

      assert_receive {[:pocket_flex, :llm, :call, :start], _meas, ^meta}, 200
      assert_receive {[:pocket_flex, :llm, :call, :stop], _meas, stop_meta}, 200
      assert stop_meta.provider == "openai"
      assert stop_meta.model == "gpt-4o"
      assert stop_meta.result == {:ok, %{response: "hello", usage: %{tokens: 5}}}
    end

    test "handler receives and logs LLM events" do
      # Attach handler
      PocketFlex.LLM.TelemetryHandler.attach()
      meta = %{provider: "openai", model: "gpt-4o", prompt: "hi!"}
      Telemetry.llm_span([:pocket_flex, :llm, :call], meta, fn ->
        {:ok, %{response: "hello", usage: %{tokens: 5}}}
      end)
      # Handler should log and rebroadcast, but we only assert broadcast here
      assert_receive {[:pocket_flex, :llm, :call, :stop], _meas, stop_meta}, 200
      assert stop_meta.provider == "openai"
    end
  end
end
