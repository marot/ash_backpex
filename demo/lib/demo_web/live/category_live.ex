defmodule DemoWeb.CategoryLive do
  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Blog.Category)
    layout({DemoWeb.Layouts, :admin})

    fields do
      field(:name)
      
      field :slug do
        help_text("URL-friendly version of the name")
      end
      
      field :description do
        module(Backpex.Fields.Textarea)
      end

      field :inserted_at do
        label("Created At")
        except([:new, :edit])
      end

      field :updated_at do
        label("Updated At")
        except([:new, :edit])
      end
    end
  end
end