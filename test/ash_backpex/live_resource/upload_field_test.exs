defmodule AshBackpex.LiveResource.UploadFieldTest do
  use ExUnit.Case

  defmodule Product do
    use Ash.Resource,
      domain: AshBackpex.LiveResource.UploadFieldTest.Shop,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id
      attribute :name, :string
      attribute :image, Ash.Type.File
    end

    actions do
      defaults [:read, :destroy, create: [:name, :image], update: [:name, :image]]
    end
  end

  defmodule Shop do
    use Ash.Domain

    resources do
      resource Product
    end
  end

  defmodule ProductLive do
    use AshBackpex.LiveResource

    backpex do
      resource Product
      layout {AshBackpex.Test.Layouts, :admin}

      fields do
        field :name
        field :image
      end
    end
  end

  describe "auto-generated upload fields" do
    test "upload field should have upload_key option set automatically" do
      fields = ProductLive.fields()
      image_field = fields[:image]

      assert image_field.module == Backpex.Fields.Upload
      # This test will currently fail because upload_key is not being set
      assert image_field.options[:upload_key] == :image
    end
  end
end