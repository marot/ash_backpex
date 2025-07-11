defmodule AshBackpex.ResourceActionTest do
  use ExUnit.Case, async: true

  defmodule TestResource do
    use Ash.Resource,
      domain: AshBackpex.ResourceActionTest.TestDomain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
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
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource TestResource
    end
  end

  defmodule TestResourceAction do
    use AshBackpex.ResourceAction

    backpex do
      resource TestResource
      action :test_action
      label "Test Action"
      title "Test Resource Action"
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
      
      changeset = TestResourceAction.changeset({base_data, base_types}, %{"string_arg" => "test"}, %{})
      assert changeset.valid?
    end

    test "base_schema returns proper structure" do
      {data, types} = TestResourceAction.base_schema(%{})
      assert is_map(data)
      assert is_map(types)
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