# PocketFlex Telemetry Utility Instrumentation Examples

## Instrumenting an LLM Utility Call

To instrument a utility (such as an LLM call) for telemetry and PubSub streaming, wrap the call using `PocketFlex.Telemetry.llm_span/3`:

```elixir
defmodule MyProject.Utils.LLMCaller do
  def invoke_llm(user_prompt, llm \\ nil, chain \\ nil) do
    PocketFlex.Telemetry.llm_span(
      [:pocket_flex, :llm, :call],
      %{provider: "openai", model: get_model(llm), prompt: user_prompt},
      fn ->
        llm = llm || default_llm()
        chain = chain || default_chain(llm)
        user_message = Message.new_user!(user_prompt)
        chain_with_message = LLMChain.add_message(chain, user_message)
        case LLMChain.run(chain_with_message) do
          {:ok, _final_chain_state, response} ->
            {:ok, %{response: response, usage: extract_usage(_final_chain_state)}}
          error ->
            error
        end
      end
    )
    |> case do
      {:ok, %{response: response}} -> {:ok, response}
      {:ok, other} -> {:ok, other}
      {:error, reason} -> {:error, reason}
    end
  end
  # ...
end
```

- This emits standardized start/stop/error events for LLM calls.
- Metadata is generic and extensible.
- All events are broadcast via PubSub for UI/API streaming.

## Subscribing to Telemetry Events in a UI or API

```elixir
Phoenix.PubSub.subscribe(PocketFlex.PubSub, "telemetry:events")
# Now handle {event, measurements, metadata} in your process
```

## Attaching a Sample Handler

```elixir
PocketFlex.LLM.TelemetryHandler.attach()
```

## Extending for Other Utilities

You can use `PocketFlex.Telemetry.span/3` for any external utility (API, DB, etc.):

```elixir
PocketFlex.Telemetry.span([
  :pocket_flex, :external, :api_call
], %{service: "my_api", request: ...}, fn ->
  # ... call external API ...
end)
```

---

See the main `docs/telemetry.md` for the full event list and best practices.
