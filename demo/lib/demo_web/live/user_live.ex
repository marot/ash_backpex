defmodule DemoWeb.UserLive do
  use AshBackpex.LiveResource

  backpex do
    resource(Demo.Accounts.User)
    layout({DemoWeb.Layouts, :admin})

    fields do
      field(:email)
      field(:name)
      
      field :subscribed_to_newsletter do
        label("Newsletter Subscriber")
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