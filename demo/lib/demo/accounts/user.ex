defmodule Demo.Accounts.User do
  use Ash.Resource,
    domain: Demo.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "users"
    repo Demo.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :subscribed_to_newsletter, :boolean do
      default false
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    default_accept [:email, :name, :subscribed_to_newsletter]

    defaults [:create, :read, :update, :destroy]
  end
end