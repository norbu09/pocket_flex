# Example: Initial shared state for a PocketFlex flow

@moduledoc """
Defines the initial shared state map for a PocketFlex flow.

The shared state is an immutable Elixir map that is passed from node to node.
All data needed by nodes or produced by them should be stored here.

## Example

    initial_state = %{
      user_query: nil,
      retrieved_docs: [],
      llm_response: nil,
      error_info: nil
    }

    # Usage:
    # Pass `initial_state` as the starting state when running a flow.
    # e.g., PocketFlex.run(flow, initial_state)
"""

initial_state = %{
  user_query: nil,
  retrieved_docs: [],
  llm_response: nil,
  error_info: nil
}