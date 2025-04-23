# PocketFlex Telemetry & PubSub Integration

## Overview

PocketFlex provides first-class observability by instrumenting all core operations, node lifecycle events, and LLM utility calls using Elixir's `:telemetry` and PubSub. This enables:

- Rich metrics and logging for developers and operators
- Real-time streaming of events to UIs, dashboards, or APIs
- Extensible event system for future needs

---

## Telemetry Events

### Core Events

| Event Name                                 | When Emitted                        | Measurements/Metadata                         |
|---------------------------------------------|-------------------------------------|-----------------------------------------------|
| [:pocket_flex, :flow, :start]               | Flow execution starts               | flow_id, flow_name, initial_state             |
| [:pocket_flex, :flow, :stop]                | Flow execution ends                 | flow_id, flow_name, final_state, duration     |
| [:pocket_flex, :node, :prep, :start]        | Before node prep/validation         | node, flow_id, shared_state                   |
| [:pocket_flex, :node, :prep, :stop]         | After node prep                     | node, flow_id, prep_data, duration            |
| [:pocket_flex, :node, :exec, :start]        | Before node exec                    | node, flow_id, prep_data                      |
| [:pocket_flex, :node, :exec, :stop]         | After node exec                     | node, flow_id, exec_result, duration          |
| [:pocket_flex, :node, :post, :start]        | Before node post                    | node, flow_id, exec_result                    |
| [:pocket_flex, :node, :post, :stop]         | After node post                     | node, flow_id, updated_state, duration        |
| [:pocket_flex, :node, :error]               | On node error                       | node, flow_id, phase, reason, stacktrace      |

### LLM Utility Events

| Event Name                                   | When Emitted                     | Measurements/Metadata                                 |
|-----------------------------------------------|----------------------------------|-------------------------------------------------------|
| [:pocket_flex, :llm, :call, :start]           | Before LLM API call              | provider, model, prompt, options, node, flow_id       |
| [:pocket_flex, :llm, :call, :stop]            | After LLM API call               | provider, model, prompt, response, usage, duration, node, flow_id |
| [:pocket_flex, :llm, :call, :error]           | On LLM call error                | provider, model, prompt, error, node, flow_id         |

---

## PubSub Integration

- All telemetry events are also broadcast on the `PocketFlex.PubSub` server under the `"telemetry:events"` topic.
- UIs, APIs, or other consumers can subscribe to this topic for real-time event streaming.

---

## Usage

### 1. Add Dependencies

In `mix.exs`:

```elixir
{:phoenix_pubsub, ">= 2.1"}
```

### 2. Application Setup

In your supervision tree:

```elixir
children = [
  {Phoenix.PubSub, name: PocketFlex.PubSub}
]
```

### 3. Telemetry Handler

Attach the handler on application start:

```elixir
PocketFlex.LLM.TelemetryHandler.attach()
```

### 4. Subscribing to Events

To receive all telemetry events in a process:

```elixir
Phoenix.PubSub.subscribe(PocketFlex.PubSub, "telemetry:events")
# Handle {event, measurements, metadata} tuples in your process
```

---

## Example: Handling Events in a UI

```elixir
def handle_info({[:pocket_flex, :llm, :call, :stop], measurements, metadata}, state) do
  # Update UI with LLM call stats
  {:noreply, state}
end
```

---

## Testing

- ExUnit tests should assert both telemetry emission and PubSub broadcast for all events.

---

## Extensibility

- Add more events as needed.
- Provide custom handlers for logging, metrics, or alerting.

---

## References

- [Elixir Telemetry](https://hexdocs.pm/telemetry/)
- [Phoenix PubSub](https://hexdocs.pm/phoenix_pubsub/)
