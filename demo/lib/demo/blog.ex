defmodule Demo.Blog do
  use Ash.Domain

  resources do
    resource Demo.Blog.Post
    resource Demo.Blog.Category
  end
end