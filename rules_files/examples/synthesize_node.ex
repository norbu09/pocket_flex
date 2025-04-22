# lib/my_project/nodes/synthesize_node.ex
# Example: Node that synthesizes an answer using an LLM

defmodule MyProject.Nodes.SynthesizeNode do
  @moduledoc """
  Node that uses the LLM to synthesize an answer from retrieved context.

  This node demonstrates the standard PocketFlex node lifecycle:
  - `prep/1` extracts the query and docs from shared state
  - `exec/1` builds a prompt and calls the LLM utility
  - `post/3` updates the state and determines the next transition
  """

  require Logger
  alias MyProject.Utils.LLMCaller

  @doc """
  Prepares data for synthesis from shared state.
  Reads :user_query and :retrieved_docs.
  """
  def prep(shared_state) do
    query = Map.get(shared_state, :user_query)
    docs = Map.get(shared_state, :retrieved_docs, [])
    {:ok, %{query: query, docs: docs}}
  end

  @doc """
  Executes synthesis using the LLM utility.
  Returns {:ok, llm_response} or {:error, reason}.
  """
  def exec({:ok, %{query: query, docs: docs}})
      when is_binary(query) and is_list(docs) do
    context = Enum.map_join(docs, "\n\n", fn doc -> doc.content end)
    prompt = """
    Based on the following context:
    --- Context ---
    #{context}
    --- End Context ---

    Answer the question: #{query}
    """
    Logger.debug("Executing SynthesizeNode with prompt length: #{String.length(prompt)}")
    # Call the utility that uses LangchainEx
    case LLMCaller.invoke_llm(prompt) do
      {:ok, llm_response} -> {:ok, llm_response}
      {:error, reason} -> {:error, reason}
    end
  end
  def exec({:ok, prep_data}) do
     Logger.error("SynthesizeNode: Invalid prep data received: #{inspect(prep_data)}")
     {:error, :invalid_prep_data}
  end
  def exec({:error, reason}), do: {:error, reason}

  @doc """
  Updates the shared state with the LLM response and determines the next action.
  """
  def post(shared_state, _prep_data, {:ok, llm_response}) do
    Logger.info("SynthesizeNode successful.")
    new_state = Map.put(shared_state, :llm_response, llm_response)
    {:ok, {:default, new_state}}
  end
  def post(shared_state, _prep_data, {:error, reason}) do
     Logger.error("SynthesizeNode failed during exec: #{inspect(reason)}")
     new_state = Map.put(shared_state, :error_info, {__MODULE__, reason})
     {:ok, {:error, new_state}}
  end
end