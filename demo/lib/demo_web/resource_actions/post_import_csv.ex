defmodule DemoWeb.ResourceActions.PostImportCsv do
  use AshBackpex.ResourceAction


  def file_label(file) do
    "label"
  end

  backpex do
    resource Demo.Blog.Post
    action :import_posts
    label "Import from CSV"
    title "Import Posts from CSV File"

    fields do
      field :csv_file do
        # module Backpex.Fields.Text
        module Backpex.Fields.Upload
        label "CSV File"
        help_text "Upload a CSV file with posts (columns: title, content, published)"
        options %{
          file_label: &__MODULE__.file_label/1,
          accept: ["text/csv"],
          max_entries: 1,
          max_file_size: 10_485_760 # 10MB,
        }
      end

      field :category do
        module Backpex.Fields.BelongsTo
        label "Default Category"
        help_text "Category to assign to imported posts (optional)"
        display_field :name
        live_resource DemoWeb.CategoryLive
      end

      field :publish_imported do
        module Backpex.Fields.Boolean
        label "Publish Imported Posts"
        help_text "Set all imported posts as published"
      end
    end
  end
end
