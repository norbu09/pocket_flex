---
layout: default
title: "Agent"
parent: "Design Patterns"
nav_order: 1
---

# Design Pattern: Agent

An "Agent" in PocketFlex is a pattern where a node (or set of nodes) uses an LLM to decide what action to take next, often by interpreting state and tool availability.

## Concept in PocketFlex

- **LLM Utility**: Use a utility module (like `LLMCaller`) to invoke an LLM.
- **Agentic Node(s)**: Nodes prepare a prompt, call the LLM, and parse the result to determine the next action (transition atom or tool invocation).
- **Tool Nodes/Utilities**: Other nodes perform concrete actions (e.g., web search, DB query) as directed by the agent node.

## Example Flow

```mermaid
graph TD
    A[Start: User Query] --> B{Agent Node: Plan Next Step};
    B -- Decision: Need Search --> C{Tool Node: Web Search};
    B -- Decision: Need DB Info --> D{Tool Node: Database Query};
    B -- Decision: Answer Directly --> E{Node: Format Answer};
    C --> F{Agent Node: Process Search Results};
    D --> G{Agent Node: Process DB Results};
    F --> B; # Re-plan based on search
    G --> B; # Re-plan based on DB info
    E --> Z[End: Show Answer];
```

## Implementation Notes

- **Prompt Engineering**: Prompts should include the goal, context, available actions, and instructions for response formatting.
- **Parsing LLM Output**: The agent node's `post/3` must reliably parse the LLM's output to extract the chosen action and parameters.
- **State Management**: The agent node updates shared state with its plan or tool results.
- **Control Flow**: Use transition atoms (e.g., `:need_search`, `:answer_ready`) to route to the correct node.
- **Separation of Concerns**: Agent nodes decide; tool nodes act.

## Best Practices

- Use a dedicated utility module for LLM calls.
- Keep agent logic modular and testable.
- Handle all possible LLM outputs robustly in `post/3`.
- Document prompt structure and expected LLM output format.

## References
- See [Node](../core_abstraction/node.md) for node lifecycle.
- See [Control Flow](../core_abstraction/control_flow.md) for transitions.
- See [Web Search](../tutorials/web_search.md) for tool integration.