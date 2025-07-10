defmodule DemoWeb.ResourceActions.PostSendEmail do
  use AshBackpex.ResourceAction

  backpex do
    resource(Demo.Blog.Post)
    action(:send_email)
    
    fields do
      field :post_id do
        module Backpex.Fields.Select
        label "Post"
        options fn _assigns ->
          # Query all posts and return {display_text, value} tuples
          Demo.Blog.Post
          |> Demo.Repo.all()
          |> Enum.map(&{&1.title, &1.id})
        end
      end
      
      field :email do
        module Backpex.Fields.Text
      end
    end
  end
end
