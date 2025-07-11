defmodule DemoWeb.ResourceActions.PostSendEmail do
  use AshBackpex.ResourceAction

  backpex do
    resource Demo.Blog.Post
    action :send_email
    label "Send Email"
    title "Send Post via Email"
    
    fields do
      field :post_id do
        module Backpex.Fields.Select
        label "Post"
        options fn _assigns ->
          # Query all posts and return {display_text, value} tuples
          Demo.Blog.Post
          |> Ash.read!(domain: Demo.Blog)
          |> Enum.map(&{&1.title, &1.id})
        end
      end
      
      field :email do
        module Backpex.Fields.Text
        label "Email Address"
        help_text "Enter the recipient's email address"
      end
    end
  end
end
