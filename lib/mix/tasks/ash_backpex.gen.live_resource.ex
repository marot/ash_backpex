defmodule Mix.Tasks.AshBackpex.Gen.LiveResource do
  @moduledoc """
  Generates an AshBackpex live resource for an existing Ash resource.

  ## Examples

      mix ash_backpex.gen.live_resource Demo.Blog.Post
      mix ash_backpex.gen.live_resource Demo.Blog.Category --web DemoWeb

  ## Options

    * `--web` - The web module to use (default: inferred from resource module)

  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = igniter.args.options
    resource_module_name = List.first(igniter.args.argv)

    case validate_resource_module(resource_module_name) do
      {:ok, resource_module} ->
        web_module = opts[:web] || infer_web_module(resource_module)
        
        igniter
        |> generate_live_resource(resource_module, web_module)

      {:error, reason} ->
        Mix.raise(reason)
    end
  end

  defp validate_resource_module(nil) do
    {:error, "Resource module name is required"}
  end

  defp validate_resource_module(module_name) do
    try do
      # First try to compile all mix dependencies to ensure modules are loaded
      Mix.Task.run("compile")
      
      module = String.to_atom("Elixir.#{module_name}")
      
      case Code.ensure_loaded(module) do
        {:module, ^module} ->
          if Ash.Resource.Info.resource?(module) do
            {:ok, module}
          else
            {:error, "#{module_name} is not an Ash resource"}
          end
        
        {:error, _reason} ->
          {:error, "Module #{module_name} does not exist or could not be loaded"}
      end
    rescue
      error ->
        {:error, "Error validating module #{module_name}: #{inspect(error)}"}
    end
  end

  defp infer_web_module(resource_module) do
    module_parts = Module.split(resource_module)
    
    case module_parts do
      [app_name | _] ->
        "#{app_name}Web"
      _ ->
        "Web"
    end
  end

  defp generate_live_resource(igniter, resource_module, web_module) do
    resource_name = get_resource_name(resource_module)
    live_module_name = "#{web_module}.#{Macro.camelize(resource_name)}Live"
    file_path = "lib/#{web_module |> Macro.underscore()}/live/#{Macro.underscore(resource_name)}_live.ex"

    live_resource_content = generate_live_resource_content(resource_module, live_module_name, web_module)

    igniter
    |> Igniter.create_new_file(file_path, live_resource_content)
  end

  defp get_resource_name(resource_module) do
    resource_module
    |> Module.split()
    |> List.last()
  end

  defp generate_live_resource_content(resource_module, live_module_name, web_module) do
    resource_info = get_resource_info(resource_module)
    fields_content = generate_fields_content(resource_info)
    layout_content = generate_layout_content(web_module)
    load_content = generate_load_content(resource_info)

    """
    defmodule #{live_module_name} do
      use AshBackpex.LiveResource

      backpex do
        resource(#{inspect(resource_module)})#{layout_content}#{load_content}

        fields do#{fields_content}
        end
      end
    end
    """
  end

  defp get_resource_info(resource_module) do
    attributes = Ash.Resource.Info.attributes(resource_module)
    relationships = Ash.Resource.Info.relationships(resource_module)
    calculations = Ash.Resource.Info.calculations(resource_module)

    %{
      attributes: attributes,
      relationships: relationships,
      calculations: calculations
    }
  end

  defp generate_fields_content(%{attributes: attributes, relationships: relationships, calculations: calculations}) do
    attribute_fields = Enum.map(attributes, &generate_attribute_field/1)
    relationship_fields = Enum.map(relationships, &generate_relationship_field/1)
    calculation_fields = Enum.map(calculations, &generate_calculation_field/1)

    [attribute_fields, relationship_fields, calculation_fields]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
  end

  defp generate_attribute_field(%{name: name, type: type}) do
    cond do
      name in [:id, :inserted_at, :updated_at] and type in [Ash.Type.UUID, :uuid] ->
        generate_timestamp_field(name)
      
      name in [:inserted_at, :updated_at] ->
        generate_timestamp_field(name)
      
      type == :string and name_suggests_textarea?(name) ->
        generate_textarea_field(name)
      
      type == :boolean ->
        generate_boolean_field(name)
      
      true ->
        generate_basic_field(name)
    end
  end

  defp generate_relationship_field(%{name: name, type: :belongs_to, destination: destination}) do
    display_field = guess_display_field(destination)
    
    "\n\n          field :#{name} do\n            module(Backpex.Fields.BelongsTo)\n            label(\"#{humanize_field_name(name)}\")\n            display_field(:#{display_field})\n          end"
  end

  defp generate_relationship_field(_), do: nil

  defp generate_calculation_field(%{name: name}) do
    "\n\n          field :#{name} do\n            except([:new, :edit])\n          end"
  end

  defp generate_basic_field(name) do
    "\n\n          field(:#{name})"
  end

  defp generate_textarea_field(name) do
    "\n\n          field :#{name} do\n            module(Backpex.Fields.Textarea)\n          end"
  end

  defp generate_boolean_field(name) do
    "\n\n          field(:#{name})"
  end

  defp generate_timestamp_field(name) do
    label = case name do
      :inserted_at -> "Created At"
      :updated_at -> "Updated At"
      _ -> humanize_field_name(name)
    end

    "\n\n          field :#{name} do\n            label(\"#{label}\")\n            except([:new, :edit])\n          end"
  end

  defp name_suggests_textarea?(name) do
    name_str = to_string(name)
    Enum.any?(["content", "description", "body", "text"], &String.contains?(name_str, &1))
  end

  defp guess_display_field(destination_module) do
    try do
      attributes = Ash.Resource.Info.attributes(destination_module)
      
      # Look for common display field names
      display_candidates = [:name, :title, :email, :username, :slug]
      
      Enum.find(display_candidates, :id, fn field_name ->
        Enum.any?(attributes, &(&1.name == field_name))
      end)
    rescue
      _ -> :id
    end
  end

  defp humanize_field_name(name) do
    name
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp generate_layout_content(web_module) do
    "\n        layout({#{web_module}.Layouts, :admin})"
  end

  defp generate_load_content(%{calculations: calculations}) when length(calculations) > 0 do
    calc_names = Enum.map(calculations, & &1.name)
    "\n        load(#{inspect(calc_names)})"
  end

  defp generate_load_content(_), do: ""
end