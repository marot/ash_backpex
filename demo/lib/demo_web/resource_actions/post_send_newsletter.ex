defmodule DemoWeb.ResourceActions.PostSendNewsletter do
  use AshBackpex.ResourceAction

  backpex do
    resource Demo.Blog.Post
    action :send_newsletter
    label "Send Newsletter"
    title "Send Newsletter to Subscribers"
    
    fields do
      field :subject do
        module Backpex.Fields.Text
        label "Subject"
        help_text "The email subject line"
      end
      
      field :content do
        module Backpex.Fields.Textarea
        label "Newsletter Content"
        help_text "The main content of your newsletter"
      end
      
      field :recipient_emails do
        module Backpex.Fields.MultiSelect
        label "Recipients"
        help_text "Select newsletter recipients"
        options fn _assigns ->
          # In a real app, you'd query subscribed users
          Demo.Accounts.User
          |> Ash.read!(domain: Demo.Accounts)
          |> Enum.filter(& &1.subscribed_to_newsletter)
          |> Enum.map(&{&1.name <> " <" <> &1.email <> ">", &1.email})
        end
      end
      
      field :send_at do
        module Backpex.Fields.DateTime
        label "Schedule Send Time"
        help_text "Leave empty to send immediately"
      end
    end
  end
end