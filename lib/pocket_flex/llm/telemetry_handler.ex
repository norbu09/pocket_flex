defmodule PocketFlex.LLM.TelemetryHandler do
  @moduledoc """
  Telemetry handler for LLM events. Broadcasts all LLM telemetry events to PubSub and logs them.
  """
  require Logger

  @doc """
  Sample handler: logs and broadcasts LLM telemetry events. Attach with attach/0.
  """
  def attach do
    :telemetry.attach_many(
      "pocketflex-llm-handler",
      [
        [:pocket_flex, :llm, :call, :start],
        [:pocket_flex, :llm, :call, :stop],
        [:pocket_flex, :llm, :call, :error]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @doc """
  Handles LLM telemetry events: logs and rebroadcasts via PubSub.
  """
  def handle_event(event, measurements, metadata, _config) do
    require Logger
    Logger.info("[LLM Telemetry] #{inspect(event)} #{inspect(measurements)} #{inspect(metadata)}")
    PocketFlex.Telemetry.broadcast(event, measurements, metadata)
  end
end
