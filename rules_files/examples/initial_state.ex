# Example initial state definition
initial_state = %{
  user_query: nil,
  retrieved_docs: [],
  llm_response: nil,
  error_info: nil
}

# You might access it like this (example):
# IO.inspect(initial_state.user_query) 