defmodule DemoWeb.ResourceActions.PostAssignCategory do
  use AshBackpex.ResourceAction

  backpex do
    resource Demo.Blog.Post
    action :assign_category
    label "Bulk Assign Category"
    title "Assign Category to Multiple Posts"

    fields do
      field :category do
        module Backpex.Fields.BelongsTo
        label "Category"
        help_text "Select the category to assign"
        display_field :name
        live_resource DemoWeb.CategoryLive
        options fn _assigns ->
          Demo.Blog.Category
          |> Ash.read!(domain: Demo.Blog)
          |> Enum.map(&{&1.name, &1.id})
        end
      end
    end
  end
end
