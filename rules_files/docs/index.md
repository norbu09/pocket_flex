---
layout: default
title: "Home"
nav_order: 1
---

# PocketFlex

A minimalist Elixir framework inspired by PocketFlow for *Agents, Task Decomposition, RAG, etc.*.

- **Lightweight**: Focuses on the core flow graph abstraction.
- **Expressive**: Aims to enable patterns like Agents, Workflows, RAG, etc., using Elixir idioms.
- **Agentic-Coding Friendly**: Designed to be intuitive for AI agents collaborating with humans to build complex LLM applications in Elixir.


## Core Abstraction

PocketFlex orchestrates computations through a directed graph of **Nodes**. Each node performs a specific task, potentially interacting with external **Utilities** (including LLMs via wrappers like LangchainEx) and communicating through a shared **State** map.

- **[Node](./core_abstraction/node.md)**: The basic unit of computation, likely implemented as an Elixir module following a specific behaviour.
- **[Communication](./core_abstraction/communication.md)**: How nodes share data, typically via an immutable shared state map passed through the flow.
- **[Control Flow](./core_abstraction/control_flow.md)**: How the execution path is determined, usually based on the return values of a node's `post/3` function.

## Design Patterns

Explore common patterns implemented with PocketFlex:

- **[Agent](./design_pattern/agent.md)**: Nodes making decisions based on state and LLM outputs.
- **[RAG (Retrieval-Augmented Generation)](./design_pattern/rag.md)**: Combining retrieval nodes and LLM synthesis nodes.
- **[MapReduce](./design_pattern/mapreduce.md)**: Using Elixir's concurrency (`Task.async_stream`) potentially orchestrated by PocketFlex nodes.
- **[Workflow](./design_pattern/workflow.md)**: Defining complex sequences and conditional paths.
- **[Multi-Agent](./design_pattern/multi_agent.md)**: Coordinating multiple independent PocketFlex flows or agents (potentially using OTP principles).

## Tutorials

Get started with these examples:

- **[Hello World](./tutorials/hello_world.md)**: A minimal PocketFlex flow.
- **[Chatbot](./tutorials/chatbot.md)**: Building a conversational agent.
- **[Code Generation](./tutorials/code_generation.md)**: Using PocketFlex and an LLM for code tasks.
- **[Web Search](./tutorials/web_search.md)**: Integrating external tools like web search. 