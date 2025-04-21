# lib/my_project/nodes/synthesize_node.ex
defmodule MyProject.Nodes.SynthesizeNode do
  @moduledoc "Node that uses the LLM to synthesize an answer."
  # @behaviour PocketFlex.Node # Assuming this behaviour
  require Logger
  # Assuming the utility is aliased or imported elsewhere
  # alias MyProject.Utils.LLMCaller

  def prep(shared_state) do
    query = Map.get(shared_state, :user_query)
    docs = Map.get(shared_state, :retrieved_docs, [])
    {:ok, %{query: query, docs: docs}}
  end

  def exec({:ok, %{query: query, docs: docs}})
      when is_binary(query) and is_list(docs) do
    context = Enum.map_join(docs, "\n\n", fn doc -> doc.content end) # Adjust based on actual doc structure
    prompt = """
    Based on the following context:
    --- Context ---
    #{context}
    --- End Context ---

    Answer the question: #{query}
    """
    
    Logger.debug("Executing SynthesizeNode with prompt length: #{String.length(prompt)}")
    # Call the utility that uses LangchainEx
    # Replace with actual call, e.g.: MyProject.Utils.LLMCaller.invoke_llm(prompt)
    # For this example file, we'll return placeholder data
    {:ok, "This is a synthesized answer based on the context."} 
  end
  def exec({:ok, prep_data}) do
     Logger.error("SynthesizeNode: Invalid prep data received: #{inspect(prep_data)}")
     {:error, :invalid_prep_data}
  end
  def exec({:error, reason}) do
     {:error, reason} # Propagate prep error
  end

  def post(shared_state, _prep_data, {:ok, llm_response}) do
    Logger.info("SynthesizeNode successful.")
    new_state = Map.put(shared_state, :llm_response, llm_response)
    {:ok, {:default, new_state}}
  end
  def post(shared_state, _prep_data, {:error, reason}) do
     Logger.error("SynthesizeNode failed during exec: #{inspect(reason)}")
     new_state = Map.put(shared_state, :error_info, {__MODULE__, reason})
     {:ok, {:error, new_state}} # Transition to error state/path
  end
end 