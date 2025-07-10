defmodule AshBackpex.ResourceAction.Dsl do
  @moduledoc """
  The DSL for configuring AshBackpex resource actions.
  """

  defmodule Field do
    defstruct [
      :argument,
      :module,
      :label,
      :help_text,
      :options,
      :display_field,
      :live_resource
    ]
  end

  @field %Spark.Dsl.Entity{
    name: :field,
    args: [:argument],
    target: AshBackpex.ResourceAction.Dsl.Field,
    describe: "Configures how an action argument should be displayed as a field in the form.",
    schema: [
      argument: [
        type: :atom,
        required: true,
        doc: "The argument name from the Ash action."
      ],
      module: [
        type: :module,
        required: false,
        doc: "The Backpex field module to use. If not specified, will be auto-derived from the argument type."
      ],
      label: [
        type: :string,
        required: false,
        doc: "The label for the field. Defaults to a humanized version of the argument name."
      ],
      help_text: [
        type: :string,
        required: false,
        doc: "Help text to display below the field."
      ],
      options: [
        type: :any,
        required: false,
        doc: "Additional options to pass to the field module."
      ],
      display_field: [
        type: :atom,
        required: false,
        doc: "For BelongsTo fields, the field to display in the dropdown."
      ],
      live_resource: [
        type: :module,
        required: false,
        doc: "For BelongsTo fields, the LiveResource module for the related resource."
      ]
    ]
  }

  @fields %Spark.Dsl.Section{
    name: :fields,
    entities: [@field]
  }

  @backpex %Spark.Dsl.Section{
    name: :backpex,
    describe: """
    Configuration for the Backpex resource action.
    """,
    examples: [
      """
      backpex do
        resource MyApp.Blog.Post
        action :send_email
        
        fields do
          field :post_id do
            module Backpex.Fields.BelongsTo
            label "Post"
            display_field :title
            live_resource DemoWeb.PostLive
          end
          
          field :email, Backpex.Fields.Text
        end
      end
      """
    ],
    schema: [
      resource: [
        type: {:spark, Ash.Resource},
        required: true,
        doc: "The Ash resource this action belongs to."
      ],
      action: [
        type: :atom,
        required: true,
        doc: "The name of the Ash action to execute."
      ],
      label: [
        type: :string,
        required: false,
        doc:
          "The label for the action button. Defaults to a humanized version of the action name."
      ],
      title: [
        type: :string,
        required: false,
        doc:
          "The title shown in the action modal. Defaults to a humanized version of the action name."
      ]
    ],
    sections: [@fields]
  }

  use Spark.Dsl.Extension,
    sections: [@backpex],
    transformers: [AshBackpex.ResourceAction.Transformers.GenerateResourceAction]
end
