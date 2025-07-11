defmodule DemoWeb.ResourceActions.PostImportCsv do
  use AshBackpex.ResourceAction

  backpex do
    resource Demo.Blog.Post
    action :import_posts
    label "Import from CSV"
    title "Import Posts from CSV File"
    
    fields do
      field :csv_file do
        module Backpex.Fields.Upload
        label "CSV File"
        help_text "Upload a CSV file with posts (columns: title, content, published)"
      end
      
      field :default_category_id do
        module Backpex.Fields.BelongsTo
        label "Default Category"
        help_text "Category to assign to imported posts (optional)"
        display_field :name
        live_resource DemoWeb.CategoryLive
        options fn _assigns ->
          Demo.Blog.Category
          |> Ash.read!(domain: Demo.Blog)
          |> Enum.map(&{&1.name, &1.id})
        end
      end
      
      field :publish_imported do
        module Backpex.Fields.Boolean
        label "Publish Imported Posts"
        help_text "Set all imported posts as published"
      end
    end
  end
end