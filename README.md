# Ash Backpex

You got your Ash in my Backpex. You got your Backpex in my Ash.

I built this so that I could use Backpex in my production app. It's exceedingly incomplete, and for now I will only be adding features as I need them. While I hope to distribute this on Hex in the future, right now this is more of "gist" than a repo and is intended as an example for other Ash devs.

```elixir
# myapp_web/live/admin/post_live.ex
defmodule MyAppWeb.Live.Admin.PostLive do
  use AshBackpex, resource: MyApp.Blog.Post, layout: {MyAppWeb.Layouts, :admin}, load: &__MODULE__.load/3

    def load(_, _, _), do: [:author]

    @impl Backpex.LiveResource
    def singular_name, do: "Post"

    @impl Backpex.LiveResource
    def plural_name, do: "Posts"

    @impl Backpex.LiveResource
    def fields do
      [
        title: %{
          module: Backpex.Fields.Text,
          label: "title",
        },
        author: %{
          module: Backpex.Fields.BelongsTo,
          label: "Author",
          display_field: :name,
          live_resource: MyAppWeb.AdminResources.AuthorLive
        },
        published_at: %{
          module: Backpex.Fields.DateTime,
          label: "Published At"
        }
      ]
    end
```

## Thanks!

Building this little integration seemed like a better business decision than any alternatives, which is a credit to the great work of the Backpex team!

Claude wrote the Phoenix Form protocol implementation for Ash.Changeset. Needs testing, etc.
