# Ash Backpex

You got your [Ash](https://ash-hq.org/) in my [Backpex](https://backpex.live/). You got your [Backpex](https://backpex.live/) in my [Ash](https://ash-hq.org/).

An integration library that brings together Ash Framework's powerful resource system with Backpex's admin interface capabilities. This library provides a clean DSL for creating admin interfaces directly from your Ash resources.

> Warning!
> Backpex itself is pre-1.0 so expect the API to change in a breaking way! Also, it cannot currently take full advantage of Ash authorization policies. For now I would only recommend using it in a high-trust environment such as internal tooling.

This is a partial implementation - feel free to open a github issue to request additional features or submit a PR if you're into that kind of thing ;)

## Installation

Add `ash_backpex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_backpex, "~> 0.0.1"}
  ]
end
```

## Usage

```elixir
# myapp_web/live/admin/post_live.ex
defmodule MyAppWeb.Live.Admin.PostLive do
    use AshBackpex.LiveResource

    backpex do
      resource MyApp.Blog.Post
      load [:author]
      layout({MyAppWeb.Layouts, :admin})

      fields do
        field :title
        field :published_at

        field :author do
          display_field(:name)
          live_resource(MyAppWeb.Live.Admin.AuthorLive)
        end
      end

      filters do
        filter :state do
          module MyAppWeb.Live.Admin.Filters.PostStateFilter
        end
      end
      
      resource_actions do
        action :send_newsletter, MyAppWeb.ResourceActions.PostSendNewsletter
        action :import_posts, MyAppWeb.ResourceActions.PostImportCsv
      end
    end
end
```

## Resource Actions

Ash Backpex supports resource actions, which are global operations that don't act on specific selected items. These are perfect for operations like sending newsletters, importing data, or generating reports.

### Creating a Resource Action

```elixir
defmodule MyAppWeb.ResourceActions.SendNewsletter do
  use AshBackpex.ResourceAction
  
  backpex do
    resource MyApp.Blog.Post
    action :send_newsletter  # The Ash action name
    label "Send Newsletter"
    title "Send Newsletter to Subscribers"
    
    fields do
      field :subject do
        module Backpex.Fields.Text
        label "Subject"
      end
      
      field :recipient_emails do
        module Backpex.Fields.MultiSelect
        label "Recipients"
        options fn _assigns ->
          MyApp.Accounts.list_subscribers()
          |> Enum.map(&{&1.name, &1.email})
        end
      end
    end
  end
end
```

### Supported Features

- **Automatic field derivation** from Ash action arguments
- **Array types** with MultiSelect fields
- **File uploads** with `Ash.Type.File`
- **Custom validation** via changeset callbacks
- **Base schema** support for complex forms
- **All Backpex field types** including BelongsTo, DateTime, etc.

### Field Type Mapping

Ash types are automatically mapped to appropriate Backpex field modules:
- `Ash.Type.String` → `Backpex.Fields.Text`
- `{:array, type}` → `Backpex.Fields.MultiSelect`
- `Ash.Type.File` → `Backpex.Fields.Upload`
- `Ash.Type.Boolean` → `Backpex.Fields.Boolean`
- And many more...

## Thanks!

Building this little integration seemed easier than any alternatives to get the admin I wanted, which is a credit to the great work of the Backpex team!
