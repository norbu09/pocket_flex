# lib/my_project/utils/llm_caller.ex
defmodule MyProject.Utils.LLMCaller do
  @moduledoc \"\"\"
  Provides a utility function to interact with an LLM using LangchainEx chains.
  This approach offers more flexibility for adding system prompts, memory, etc.
  \"\"\"
  require Logger
  alias LangChain.Chains.LLMChain
  alias LangChain.LLM.OpenAI # Or your chosen provider
  alias LangChain.Message

  # Consider making the LLM and Chain configuration dynamic or configurable
  # For the example, we define a default one.
  defp default_llm(config \\ %{model: \"gpt-4o\"}) do
    # Assumes API key is in environment (e.g., OPENAI_API_KEY)
    OpenAI.new(config)
  end

  defp default_chain(llm) do
    # Basic chain, could add system prompts, memory, etc. here
    LLMChain.new!(%{llm: llm})
    # Example with system prompt:
    # |> LLMChain.add_message(Message.new_system!(\"You are a helpful assistant.\"))
  end

  @doc \"\"\"
  Invokes the configured LLM Chain with a single user prompt.
  
  Handles basic invocation. For streaming or more complex interactions 
  (like adding conversation history), create more specific functions.

  Returns `{:ok, response_content}` or `{:error, reason}`.
  \"\"\"
  @spec invoke_llm(String.t(), map() | LangChain.LLM.t(), LLMChain.t() | nil) :: {:ok, String.t()} | {:error, any()}
  def invoke_llm(user_prompt, llm \\ nil, chain \\ nil) do
    llm = llm || default_llm()
    chain = chain || default_chain(llm)

    # Convert the simple prompt string into a Langchain User Message
    user_message = Message.new_user!(user_prompt)
    
    Logger.debug(\"Running LLM Chain with message: #{inspect(user_message)}\")

    # Add the user message to the chain for this run
    # Note: Depending on chain type/memory, adding might modify state persistently 
    # or just for this run. Basic LLMChain is stateless for messages added this way.
    chain_with_message = LLMChain.add_message(chain, user_message)

    case LLMChain.run(chain_with_message) do
      {:ok, _final_chain_state, response} ->
        # Response structure depends on the LLM/ChatModel used
        # We assume a structure containing a `content` field
        content = Map.get(response, :content, inspect(response))
        Logger.info(\"LLM Chain run successful.\")
        Logger.debug(\"LLM Response content: #{content}\")
        {:ok, content}
      {:error, reason} ->
        Logger.error(\"LLM Chain run failed: #{inspect(reason)}\")
        {:error, reason}
      other -> 
        # Catch unexpected return values from run/1
        Logger.error(\"LLM Chain run returned unexpected value: #{inspect(other)}\")
        {:error, {:unexpected_chain_result, other}}
    end
  end

  # Example of how you might add a streaming function later
  # @spec stream_llm(pid(), String.t(), map(), LLMChain.t() | nil) :: any()
  # def stream_llm(receiver_pid, user_prompt, llm_config \\ %{}, chain \\ nil) do
  #   llm = default_llm(Map.put(llm_config, :stream, true)) # Ensure streaming is enabled
  #   chain = chain || default_chain(llm)
  #   user_message = Message.new_user!(user_prompt)
  #   
  #   handler = %{ # Define callback handlers for streaming }
  # 
  #   chain
  #   |> LLMChain.add_callback(handler)
  #   |> LLMChain.add_llm_callback(handler) # If needed for the model
  #   |> LLMChain.add_message(user_message)
  #   |> LLMChain.run() # Run likely triggers the async stream
  # end
end 