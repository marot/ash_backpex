defmodule AshBackpex.ResourceActionTest do
  use ExUnit.Case, async: true

  defmodule CategoryResource do
    use Ash.Resource,
      domain: AshBackpex.ResourceActionTest.TestDomain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:create, :read]
    end
  end

  defmodule TestResource do
    use Ash.Resource,
      domain: AshBackpex.ResourceActionTest.TestDomain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    relationships do
      belongs_to :category, CategoryResource, public?: true
    end

    actions do
      defaults [:create, :read]

      action :test_action, :struct do
        argument :string_arg, :string do
          allow_nil? false
        end

        argument :array_arg, {:array, :string} do
          allow_nil? true
        end

        argument :boolean_arg, :boolean do
          default true
        end

        run fn input, _context ->
          {:ok, %{result: "success", args: input.arguments}}
        end
      end

      action :assign_category, :struct do
        argument :category_id, :uuid do
          allow_nil? false
        end

        argument :note, :string

        run fn input, _context ->
          {:ok, %{result: "category assigned", category_id: input.arguments.category_id}}
        end
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource TestResource
      resource CategoryResource
    end
  end

  defmodule TestResourceAction do
    use AshBackpex.ResourceAction

    backpex do
      resource TestResource
      action :test_action
      label("Test Action")
      title("Test Resource Action")
    end
  end

  defmodule TestCategoryLive do
    # Mock LiveResource module for testing
    def config(:adapter_config), do: [schema: CategoryResource]
  end

  defmodule TestAssignCategoryAction do
    use AshBackpex.ResourceAction

    backpex do
      resource TestResource
      action :assign_category
      label("Assign Category")
      title("Assign Category to Resource")

      fields do
        field :category_id do
          module Backpex.Fields.BelongsTo
          label("Category")
          display_field(:name)
          live_resource(TestCategoryLive)
        end

        field :note do
          module Backpex.Fields.Text
          help_text("Optional note about the assignment")
        end
      end
    end
  end

  describe "resource action generation" do
    test "generates required callbacks" do
      assert function_exported?(TestResourceAction, :label, 0)
      assert function_exported?(TestResourceAction, :title, 0)
      assert function_exported?(TestResourceAction, :fields, 0)
      assert function_exported?(TestResourceAction, :changeset, 3)
      assert function_exported?(TestResourceAction, :handle, 2)
      assert function_exported?(TestResourceAction, :base_schema, 1)
    end

    test "derives fields from action arguments" do
      fields = TestResourceAction.fields()

      assert fields[:string_arg][:module] == Backpex.Fields.Text
      assert fields[:string_arg][:type] == :string
      assert fields[:string_arg][:required] == true

      assert fields[:array_arg][:module] == Backpex.Fields.MultiSelect
      assert fields[:array_arg][:type] == {:array, :string}

      assert fields[:boolean_arg][:module] == Backpex.Fields.Boolean
      assert fields[:boolean_arg][:type] == :boolean
    end

    test "changeset validates required fields" do
      {base_data, base_types} = TestResourceAction.base_schema(%{})
      changeset = TestResourceAction.changeset({base_data, base_types}, %{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).string_arg

      changeset =
        TestResourceAction.changeset({base_data, base_types}, %{"string_arg" => "test"}, %{})

      assert changeset.valid?
    end

    test "base_schema returns proper structure" do
      {data, types} = TestResourceAction.base_schema(%{})
      assert is_map(data)
      assert is_map(types)
    end
  end

  describe "resource action with belongs_to fields" do
    test "configures belongs_to field with explicit module" do
      fields = TestAssignCategoryAction.fields()

      assert fields[:category_id][:module] == Backpex.Fields.BelongsTo
      assert fields[:category_id][:label] == "Category"
      assert fields[:category_id][:display_field] == :name
      assert fields[:category_id][:live_resource] == TestCategoryLive
      assert fields[:category_id][:type] == Ecto.UUID
      assert fields[:category_id][:required] == true

      assert fields[:note][:module] == Backpex.Fields.Text
      assert fields[:note][:help_text] == "Optional note about the assignment"
    end

    test "generates valid changeset for belongs_to field" do
      {base_data, base_types} = TestAssignCategoryAction.base_schema(%{})

      # Should be invalid without required category_id
      changeset = TestAssignCategoryAction.changeset({base_data, base_types}, %{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).category_id

      # Should be valid with category_id
      category_id = Ecto.UUID.generate()

      changeset =
        TestAssignCategoryAction.changeset(
          {base_data, base_types},
          %{"category_id" => category_id},
          %{}
        )

      assert changeset.valid?
      assert changeset.changes.category_id == category_id
    end

    test "includes all belongs_to field options in fields configuration" do
      fields = TestAssignCategoryAction.fields()
      category_field = fields[:category_id]

      # Verify all BelongsTo-specific options are present
      assert Map.has_key?(category_field, :module)
      assert Map.has_key?(category_field, :label)
      assert Map.has_key?(category_field, :display_field)
      assert Map.has_key?(category_field, :live_resource)
      assert Map.has_key?(category_field, :type)
      assert Map.has_key?(category_field, :required)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
