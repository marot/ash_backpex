defmodule DemoWeb.PostLive do
  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Blog.Post)
    layout({DemoWeb.Layouts, :admin})

    load([:word_count])

    fields do
      field(:title)

      field :content do
        module(Backpex.Fields.Textarea)
      end

      field(:published)

      field :category do
        module(Backpex.Fields.BelongsTo)
        label("Category")
        display_field(:name)
      end

      field :word_count do
        except([:new, :edit])
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

    resource_actions do
      action(:send_email, DemoWeb.ResourceActions.PostSendEmail)
      action(:send_newsletter, DemoWeb.ResourceActions.PostSendNewsletter)
      action(:import_posts, DemoWeb.ResourceActions.PostImportCsv)
      action(:generate_report, DemoWeb.ResourceActions.PostGenerateReport)
      action(:assign_category, DemoWeb.ResourceActions.PostAssignCategory)
    end
  end
end
