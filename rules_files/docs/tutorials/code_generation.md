---
layout: default
title: "Code Generation"
parent: "Tutorials"
nav_order: 3
---

# Tutorial: Code Generation

This tutorial shows how PocketFlex can be used with an LLM to generate code based on a specification.

## 1. Define Nodes

**Node: GetSpecification**
- `prep`: None.
- `exec`: Reads the code specification (e.g., from a file specified in initial state, or prompts user).
- `post`: Adds the specification string to the shared state under `:spec`.

**Node: GenerateCode**
- `prep`: Reads `:spec` from state.
- `exec`: Constructs a detailed prompt for the LLM asking it to generate Elixir code based on the `:spec`. Calls the `LLMCaller.invoke_llm/1` utility.
- `post`: Adds the generated code string (extracted from the LLM response) to state under `:generated_code`. Handles LLM errors.

**Node: ValidateCode (Optional but Recommended)**
- `prep`: Reads `:generated_code` from state.
- `exec`: Attempts to parse or validate the code. 
    - Simple validation: Check for basic syntax errors (e.g., using `Code.string_to_quoted/1`).
    - Advanced validation: Write the code to a temporary file and try to compile it (`mix compile`), or run basic tests against it.
- `post`: Adds validation status (`:ok` or `:error`) and any error messages to state under `:validation_result`. Determines transition (`:valid` or `:invalid`).

**Node: SaveCode**
- `prep`: Reads `:generated_code` and maybe a target filename from state.
- `exec`: Writes the code to the target file (`File.write/2`).
- `post`: Updates state indicating success/failure. 

**Node: HandleGenerationError**
- `prep`: Reads error info (from `GenerateCode` or `ValidateCode`).
- `exec`: Logs the error, notifies the user.
- `post`: Clears error state.

## 2. Define Flow

```elixir
# lib/my_codegen_app/flow.ex
defmodule MyCodegenApp.Flow do
  alias MyCodegenApp.Nodes
  # alias PocketFlex

  def define_codegen_flow do
    PocketFlex.define(
      start_node: Nodes.GetSpecification,
      nodes: [
        %{module: Nodes.GetSpecification, transitions: %{default: Nodes.GenerateCode}},
        
        %{module: Nodes.GenerateCode, 
          transitions: %{default: Nodes.ValidateCode, error: Nodes.HandleGenerationError}
        },
        
        %{module: Nodes.ValidateCode, 
          transitions: %{
            valid: Nodes.SaveCode, 
            invalid: Nodes.HandleGenerationError, # Or loop back to GenerateCode?
            error: Nodes.HandleGenerationError # Error during validation itself
           }
        },

        %{module: Nodes.SaveCode, 
          transitions: %{default: :end, error: Nodes.HandleGenerationError}
        },

        %{module: Nodes.HandleGenerationError, 
          transitions: %{default: :end}
        }
      ]
    )
  end
end
```

## 3. Run the Flow

```elixir
# lib/my_codegen_app.ex
defmodule MyCodegenApp do
  require Logger
  alias MyCodegenApp.Flow
  # alias PocketFlex

  def run_codegen(spec_file, output_file) do
    initial_state = %{spec_file: spec_file, output_file: output_file}
    flow_definition = Flow.define_codegen_flow()

    Logger.info("Starting Code Generation flow...")
    case PocketFlex.run(flow_definition, initial_state) do
      {:ok, final_state} ->
        Logger.info("Code Generation flow completed.")
        # Check final_state for success/failure indicators
        IO.inspect(final_state, label: "Final State")
      {:error, reason, final_state} ->
        Logger.error("Code Generation flow failed: #{inspect(reason)}")
        IO.inspect(final_state, label: "Final State on Error")
    end
  end
end

# To run:
# mix run -e 'MyCodegenApp.run_codegen("path/to/spec.md", "path/to/output.ex")'
```

## Key Considerations

- **Prompt Quality**: The success heavily depends on the prompt given to the LLM in `GenerateCode`. It should be specific, provide context, and clearly state the desired output format (e.g., "Generate only the Elixir code module. Do not include explanations.").
- **Validation**: Simple syntax checking is often insufficient. Trying to compile or run tests against the generated code provides much higher confidence.
- **Error Handling/Retries**: If validation fails, the flow could loop back to `GenerateCode` with modified instructions (e.g., including the previous error) to attempt self-correction. 