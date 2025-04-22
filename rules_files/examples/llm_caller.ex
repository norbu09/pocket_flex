# lib/my_project/utils/llm_caller.ex
# Example: Utility for interacting with an LLM using LangchainEx

defmodule MyProject.Utils.LLMCaller do
  @moduledoc """
  Provides a utility function to interact with an LLM using LangchainEx chains.

  This module demonstrates best practices for LLM invocation in PocketFlex flows.
  The utility is stateless and can be injected into nodes for easier testing and mocking.

  ## Example

      iex> MyProject.Utils.LLMCaller.invoke_llm("What's the weather?", %{model: "gpt-4o"})
      {:ok, "It's sunny!"}
  """

  require Logger
  alias LangChain.Chains.LLMChain
  alias LangChain.LLM.OpenAI
  alias LangChain.Message

  @doc """
  Returns a default LLM client (OpenAI) with the given config.
  """
  defp default_llm(config \\ %{model: "gpt-4o"}) do
    OpenAI.new(config)
  end

  @doc """
  Returns a default LLM chain for the given LLM client.
  """
  defp default_chain(llm) do
    LLMChain.new!(%{llm: llm})
  end

  @doc """
  Invokes the configured LLM Chain with a single user prompt.

  ## Parameters
    - user_prompt: The string prompt for the LLM.
    - llm: (optional) A LangChain.LLM.t() client. If not provided, uses default.
    - chain: (optional) A preconfigured LLMChain.t(). If not provided, uses default.

  ## Returns
    - {:ok, response_content} on success
    - {:error, reason} on failure

  ## Example

      iex> MyProject.Utils.LLMCaller.invoke_llm("Hello!", %{model: "gpt-4o"})
      {:ok, "Hi there!"}
  """
  @spec invoke_llm(String.t(), map() | LangChain.LLM.t() | nil, LLMChain.t() | nil) :: {:ok, String.t()} | {:error, any()}
  def invoke_llm(user_prompt, llm \\ nil, chain \\ nil) do
    llm = llm || default_llm()
    chain = chain || default_chain(llm)
    user_message = Message.new_user!(user_prompt)
    Logger.debug("Running LLM Chain with message: #{inspect(user_message)}")
    chain_with_message = LLMChain.add_message(chain, user_message)
    case LLMChain.run(chain_with_message) do
      {:ok, _final_chain_state, response} ->
        content = Map.get(response, :content, inspect(response))
        Logger.info("LLM Chain run successful.")
        Logger.debug("LLM Response content: #{content}")
        {:ok, content}
      {:error, reason} ->
        Logger.error("LLM Chain run failed: #{inspect(reason)}")
        {:error, reason}
      other ->
        Logger.error("Unexpected LLMChain.run/1 result: #{inspect(other)}")
        {:error, :unexpected_llmchain_result}
    end
  end
end