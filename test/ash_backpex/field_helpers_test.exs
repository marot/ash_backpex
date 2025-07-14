defmodule AshBackpex.FieldHelpersTest do
  use ExUnit.Case, async: true
  alias AshBackpex.FieldHelpers

  describe "derive_field_module/1" do
    test "derives correct field modules for basic types" do
      assert FieldHelpers.derive_field_module(Ash.Type.String) == Backpex.Fields.Text
      assert FieldHelpers.derive_field_module(Ash.Type.Integer) == Backpex.Fields.Number
      assert FieldHelpers.derive_field_module(Ash.Type.Boolean) == Backpex.Fields.Boolean
      assert FieldHelpers.derive_field_module(Ash.Type.Date) == Backpex.Fields.Date
      assert FieldHelpers.derive_field_module(Ash.Type.DateTime) == Backpex.Fields.DateTime
      assert FieldHelpers.derive_field_module(Ash.Type.File) == Backpex.Fields.Upload
    end

    test "derives MultiSelect for array types" do
      assert FieldHelpers.derive_field_module({:array, :string}) == Backpex.Fields.MultiSelect
      assert FieldHelpers.derive_field_module({:array, :integer}) == Backpex.Fields.MultiSelect
    end

    test "derives Text for unknown types" do
      assert FieldHelpers.derive_field_module(:unknown_type) == Backpex.Fields.Text
      assert FieldHelpers.derive_field_module(nil) == Backpex.Fields.Text
    end
  end

  describe "derive_ecto_type/1" do
    test "derives correct ecto types for basic types" do
      assert FieldHelpers.derive_ecto_type(Ash.Type.String) == :string
      assert FieldHelpers.derive_ecto_type(Ash.Type.Integer) == :integer
      assert FieldHelpers.derive_ecto_type(Ash.Type.Boolean) == :boolean
      assert FieldHelpers.derive_ecto_type(Ash.Type.Float) == :float
      assert FieldHelpers.derive_ecto_type(Ash.Type.Date) == :date
      assert FieldHelpers.derive_ecto_type(Ash.Type.UUID) == Ecto.UUID
      assert FieldHelpers.derive_ecto_type(Ash.Type.File) == :map
    end

    test "derives array types correctly" do
      assert FieldHelpers.derive_ecto_type({:array, Ash.Type.String}) == {:array, :string}
      assert FieldHelpers.derive_ecto_type({:array, Ash.Type.Integer}) == {:array, :integer}

      assert FieldHelpers.derive_ecto_type({:array, {:array, Ash.Type.String}}) ==
               {:array, {:array, :string}}
    end

    test "derives string for unknown types" do
      assert FieldHelpers.derive_ecto_type(:unknown_type) == :string
      assert FieldHelpers.derive_ecto_type(nil) == :string
    end
  end
end
