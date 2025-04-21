---
layout: default
title: "Agent"
parent: "Design Patterns"
nav_order: 1
---

# Design Pattern: Agent

An "Agent" in the context of LLM frameworks like PocketFlex typically refers to a system that uses an LLM to make decisions about what actions to take next.

## Concept in PocketFlex

Instead of a monolithic "Agent" object, an agentic pattern in PocketFlex is often implemented using a combination of:

1.  **LLM Utility**: A utility module (like the `LLMCaller` example using LangchainEx) that allows nodes to invoke an LLM.
2.  **Agentic Node(s)**: One or more PocketFlex [Nodes](../core_abstraction/node.md) whose primary purpose is to:
    *   Prepare a prompt for the LLM based on the current [Shared State](../core_abstraction/communication.md) and available tools/actions.
    *   Execute the LLM call via the utility.
    *   Post-process the LLM response to determine the next action (which might be calling another tool/utility node or deciding the next step in the [Control Flow](../core_abstraction/control_flow.md)).
3.  **Tool Nodes/Utilities**: Regular Elixir modules or specific PocketFlex nodes that perform concrete actions (e.g., web search, database query, file I/O), which the agentic node can decide to invoke (often indirectly by setting specific flags or data in the shared state that trigger a transition to the tool node).

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

- **Prompt Engineering**: The core of the agentic node lies in constructing the right prompt for the LLM. This prompt should include:
    - The overall goal.
    - The current state/context.
    - Available actions/tools (with descriptions).
    - Instructions on how the LLM should format its response (e.g., specify the next action/tool and its parameters).
- **Parsing LLM Output**: The `post/3` function of the agentic node needs to reliably parse the LLM's response to extract the chosen action and parameters.
- **State Management**: The agentic node updates the shared state with its plan or the results of tool executions.
- **Control Flow**: Transitions in the flow definition (`:need_search`, `:need_db`, `:answer_ready`) are based on the parsed LLM decision returned by the agentic node's `post/3` function using different `next_action_atom` values.
- **Tool Execution**: Often, the agent node doesn't call the tool directly in `exec/1`. Instead, its `post/3` function returns a specific atom (e.g., `:invoke_web_search`), and the flow definition routes this to the `WebSearchNode`. The `WebSearchNode` performs the action, and its `post/3` likely transitions back to the agent node with the results added to the shared state.

This modular approach allows for better testing and separation of concerns compared to a single, large agent function. 