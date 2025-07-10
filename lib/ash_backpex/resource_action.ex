defmodule AshBackpex.ResourceAction do
  @moduledoc """
  A Spark DSL for defining Backpex resource actions backed by Ash actions.

  This module allows you to create resource actions that automatically derive
  their fields and behavior from Ash action definitions.

  ## Example

      defmodule MyApp.ResourceActions.SendEmail do
        use AshBackpex.ResourceAction

        backpex do
          resource MyApp.Blog.Post
          action :send_email
        end
      end

  This will automatically generate a Backpex resource action that:
  - Derives form fields from the Ash action's arguments
  - Implements validation using the Ash action's constraints
  - Executes the Ash action when the form is submitted
  """

  use Spark.Dsl,
    default_extensions: [
      extensions: [AshBackpex.ResourceAction.Dsl]
    ]
end
