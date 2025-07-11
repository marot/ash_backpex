defmodule DemoWeb.ResourceActions.PostAssignCategory do
  use AshBackpex.ResourceAction

  backpex do
    resource Demo.Blog.Post
    action :assign_category
    label "Bulk Assign Category"
    title "Assign Category to Multiple Posts"
    
    fields do
      field :category_id do
        module Backpex.Fields.BelongsTo
        label "Category"
        help_text "Select the category to assign"
        display_field :name
        live_resource DemoWeb.CategoryLive
        options fn _assigns ->
          Demo.Blog.Category
          |> Ash.read!(domain: Demo.Blog)
          |> Enum.map(&{&1.name, &1.id})
        end
      end
      
      # Note: The conditions field is a map type which will be rendered as JSON input
      # In a real implementation, you might want to create a custom field module
      # for a more user-friendly conditions builder
      field :conditions do
        module Backpex.Fields.Textarea
        label "Filter Conditions (JSON)"
        help_text ~s(Enter conditions as JSON, e.g., {"published": true, "title_contains": "Tutorial"})
      end
    end
  end
  
  # Custom changeset to parse JSON conditions
  @impl Backpex.ResourceAction
  def changeset(change, attrs, metadata) do
    import Ecto.Changeset
    
    # Parse conditions from JSON string to map
    attrs = 
      case Map.get(attrs, "conditions") do
        nil -> attrs
        "" -> Map.put(attrs, "conditions", %{})
        json_string when is_binary(json_string) ->
          case Jason.decode(json_string) do
            {:ok, conditions} -> Map.put(attrs, "conditions", conditions)
            {:error, _} -> attrs
          end
        conditions -> Map.put(attrs, "conditions", conditions)
      end
    
    change
    |> cast(attrs, [:category_id, :conditions])
    |> validate_required([:category_id])
    |> validate_conditions()
  end
  
  defp validate_conditions(changeset) do
    case get_change(changeset, :conditions) do
      nil -> changeset
      conditions when is_map(conditions) -> changeset
      _ -> add_error(changeset, :conditions, "must be a valid JSON object")
    end
  end
end