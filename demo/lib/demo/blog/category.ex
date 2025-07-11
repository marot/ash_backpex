defmodule Demo.Blog.Category do
  use Ash.Resource,
    domain: Demo.Blog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "categories"
    repo Demo.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      allow_nil? true
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :posts, Demo.Blog.Post
  end

  actions do
    default_accept [:name, :description, :slug]

    defaults [:create, :read, :update, :destroy]
  end
end