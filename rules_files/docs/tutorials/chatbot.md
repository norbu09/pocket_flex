---
layout: default
title: "Chatbot"
parent: "Tutorials"
nav_order: 2
---

# Tutorial: Chatbot

This tutorial outlines building a simple conversational chatbot using PocketFlex and an LLM.

## 1. Define Nodes

We need nodes to handle user input, manage conversation history, call the LLM, and present the response.

**Node: GetUserInput**
- `prep`: Maybe gets conversation history from state to show user.
- `exec`: Prompts the user for input (`IO.gets/1`). Returns `{:ok, user_input}`.
- `post`: Adds `user_input` to the shared state under a key like `:current_input` and potentially appends it to a `:history` list. Returns `{:ok, {:default, state}}`.

**Node: PrepareLLMPrompt**
- `prep`: Reads `:current_input` and `:history` from state.
- `exec`: Formats the history and current input into a single prompt string suitable for the LLM (e.g., alternating "User: ...", "Assistant: ..."). Returns `{:ok, llm_prompt}`.
- `post`: Adds `llm_prompt` to the state. Returns `{:ok, {:default, state}}`.

**Node: CallLLM**
- `prep`: Reads `:llm_prompt` from state.
- `exec`: Calls the `MyProject.Utils.LLMCaller.invoke_llm/1` utility (which uses LangchainEx) with the prompt. Returns `{:ok, llm_response_content}` or `{:error, reason}`.
- `post`: If OK, adds `llm_response_content` to state under `:current_response` and appends an assistant message to `:history`. Returns `{:ok, {:default, state}}`. If error, updates state with error info and returns `{:ok, {:error, state}}`.

**Node: DisplayResponse**
- `prep`: Reads `:current_response` from state.
- `exec`: Prints the response to the console (`IO.puts/1`). Returns `{:ok, nil}`.
- `post`: No state change needed. Returns `{:ok, {:default, state}}` to potentially loop back.

**Node: HandleError**
- `prep`: Reads error info from state.
- `exec`: Logs the error, maybe prints a user-friendly error message. Returns `{:ok, nil}`.
- `post`: Clears error info. Returns `{:ok, {:default, state}}` to end or loop.

## 2. Define Flow

The flow connects these nodes, potentially in a loop.

```elixir
# lib/my_chatbot_app/flow.ex
defmodule MyChatbotApp.Flow do
  alias MyChatbotApp.Nodes
  # alias PocketFlex

  def define_chat_flow do
    PocketFlex.define(
      start_node: Nodes.GetUserInput,
      nodes: [
        %{module: Nodes.GetUserInput, transitions: %{default: Nodes.PrepareLLMPrompt}},
        
        %{module: Nodes.PrepareLLMPrompt, transitions: %{default: Nodes.CallLLM}},
        
        %{module: Nodes.CallLLM, 
          transitions: %{
            default: Nodes.DisplayResponse, 
            error: Nodes.HandleError
          }
        },

        %{module: Nodes.DisplayResponse, 
          transitions: %{
            default: Nodes.GetUserInput # Loop back for next input
          }
        },

        %{module: Nodes.HandleError, 
          transitions: %{
            default: Nodes.GetUserInput # Loop back after error
          }
        }
      ]
    )
  end
end
```

## 3. Run the Flow

```elixir
# lib/my_chatbot_app.ex
defmodule MyChatbotApp do
  require Logger
  alias MyChatbotApp.Flow
  # alias PocketFlex

  def run_chatbot do
    # Initial state includes empty history
    initial_state = %{history: []}
    flow_definition = Flow.define_chat_flow()

    Logger.info("Starting Chatbot flow...")
    # Run the flow (PocketFlex.run might block or run async depending on implementation)
    # For a chatbot, you might run this within a GenServer or loop manually.
    # This example assumes PocketFlex.run handles the looping based on transitions.
    case PocketFlex.run(flow_definition, initial_state) do
      # Depending on how PocketFlex handles infinite loops or end states,
      # the return here might indicate completion or an unhandled exit.
      {:ok, final_state} ->
        Logger.info("Chatbot flow finished (unexpectedly?).")
        IO.inspect(final_state, label: "Final State")
      {:error, reason, final_state} ->
        Logger.error("Chatbot flow failed: #{inspect(reason)}")
        IO.inspect(final_state, label: "Final State on Error")
    end
  end
end

# To run:
# mix run -e "MyChatbotApp.run_chatbot()"
```

## Enhancements

- **Memory Management**: Limit the size of the `:history` list passed to the LLM to manage context window size and cost.
- **Streaming Responses**: Modify `CallLLM` and `DisplayResponse` to use the streaming capabilities of the LLM (if supported by the LangchainEx model/utility) for a better user experience.
- **Error Recovery**: Improve error handling logic.
- **State Persistence**: Save/load conversation history from a database. 