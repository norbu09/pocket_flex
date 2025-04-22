# lib/my_project/flow.ex
# Example: Defining a PocketFlex flow (RAG pipeline)
defmodule MyProject.Flow do
  @moduledoc """
  Example of defining a PocketFlex flow for a RAG (Retrieval-Augmented Generation) pipeline.

  This module demonstrates how to wire up nodes using the PocketFlex DSL.

  ## Example

      alias MyProject.Nodes
      alias PocketFlex.DSL

      def define_rag_flow do
        DSL.define(
          start_node: Nodes.GetQueryNode,
          nodes: [
            %{module: Nodes.GetQueryNode, transitions: %{default: Nodes.FormatNode}},
            %{module: Nodes.FormatNode, transitions: %{default: Nodes.RetrieveNode, error: :end_flow_error}},
            %{module: Nodes.RetrieveNode, transitions: %{default: Nodes.SynthesizeNode, error: :end_flow_error}},
            %{module: Nodes.SynthesizeNode, transitions: %{default: :end_flow_success, error: :end_flow_error}}
          ]
        )
      end
  """

  alias MyProject.Nodes
  alias PocketFlex.DSL

  @doc """
  Defines a RAG flow using the PocketFlex DSL.

  Returns `{:ok, flow}` on success.
  """
  def define_rag_flow do
    DSL.define(
      start_node: Nodes.GetQueryNode,
      nodes: [
        %{module: Nodes.GetQueryNode, transitions: %{default: Nodes.FormatNode}},
        %{module: Nodes.FormatNode, transitions: %{default: Nodes.RetrieveNode, error: :end_flow_error}},
        %{module: Nodes.RetrieveNode, transitions: %{default: Nodes.SynthesizeNode, error: :end_flow_error}},
        %{module: Nodes.SynthesizeNode, transitions: %{default: :end_flow_success, error: :end_flow_error}}
      ]
    )
  end
end