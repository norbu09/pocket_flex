defmodule PocketFlex.Telemetry do
  @moduledoc """
  Telemetry helpers for PocketFlex core and LLM events, with PubSub broadcasting.
  """
  
  @pubsub PocketFlex.PubSub
  @pubsub_topic "telemetry:events"

  @doc """
  Emit a telemetry event and broadcast to PubSub.
  """
  def emit(event, measurements, metadata) do
    :telemetry.execute(event, measurements, metadata)
    broadcast(event, measurements, metadata)
  end

  @doc """
  Broadcast telemetry event to PubSub.
  """
  def broadcast(event, measurements, metadata) do
    if Code.ensure_loaded?(Phoenix.PubSub) do
      Phoenix.PubSub.broadcast(@pubsub, @pubsub_topic, {event, measurements, metadata})
    else
      :ok
    end
  end

  @doc """
  Span helper for timing and emitting start/stop/error events.
  """
  def span(event, meta, fun) do
    start_time = System.monotonic_time()
    emit(event ++ [:start], %{system_time: start_time}, meta)
    try do
      result = fun.()
      duration = System.monotonic_time() - start_time
      emit(event ++ [:stop], %{duration: duration}, Map.put(meta, :result, result))
      {:ok, result}
    rescue
      e ->
        emit(event ++ [:error], %{error: e, stacktrace: __STACKTRACE__}, meta)
        reraise e, __STACKTRACE__
    end
  end

  @doc """
  Specialized span for LLM calls.
  """
  def llm_span(event, meta, fun) do
    span(event, meta, fun)
  end
end
