defmodule AshBackpex.ResourceAction.Transformers.GenerateResourceAction do
  @moduledoc """
  Transformer that generates Backpex.ResourceAction callbacks from Ash action configuration.
  """

  use Spark.Dsl.Transformer

  alias AshBackpex.FieldHelpers
  alias AshBackpex.ResourceAction.Info

  @impl true
  def transform(dsl_state) do
    resource = Info.resource(dsl_state)
    action_name = Info.action(dsl_state)
    label = Info.label(dsl_state)
    title = Info.title(dsl_state)
    configured_fields = Info.fields(dsl_state)

    if resource && action_name do
      action = Ash.Resource.Info.action(resource, action_name)

      if !action do
        {:error, "Action #{inspect(action_name)} not found on resource #{inspect(resource)}"}
      else
        # Generate the code directly instead of using after_compile
        quoted = generate_resource_action_code(resource, action, label, title, configured_fields)

        {:ok, Spark.Dsl.Transformer.eval(dsl_state, [], quoted)}
      end
    else
      {:error, "Both resource and action must be configured"}
    end
  end

  defp generate_resource_action_code(resource, action, label, title, configured_fields) do
    # Generate label with default if not provided
    label = label || action.name |> to_string() |> String.replace("_", " ") |> String.capitalize()

    # Generate title with default if not provided
    title = title || action.name |> to_string() |> String.replace("_", " ") |> String.capitalize()

    # Generate fields from configured fields or auto-derive from action arguments
    fields =
      if configured_fields && !Enum.empty?(configured_fields) do
        # Use explicitly configured fields
        Enum.map(configured_fields, fn field_config ->
          field_name = field_config.argument

          # Get the argument definition for additional info
          # For BelongsTo fields, try to find the foreign key argument if direct lookup fails
          argument = Enum.find(action.arguments, &(&1.name == field_name)) ||
            (if field_config.module == Backpex.Fields.BelongsTo do
              foreign_key_name = String.to_atom("#{field_name}_id")
              Enum.find(action.arguments, &(&1.name == foreign_key_name))
            else
              nil
            end)

          if is_nil(argument) do
            raise "No argument found for field #{inspect(field_name)}. Available arguments: #{inspect(Enum.map(action.arguments, & &1.name))}"
          end

          # Build the field map
          field_map = %{
            module: field_config.module || FieldHelpers.derive_field_module(argument.type),
            label:
              field_config.label ||
                field_name |> to_string() |> String.replace("_", " ") |> String.capitalize(),
            type: FieldHelpers.derive_ecto_type(argument.type)
          }

          # Add optional field configuration
          field_map =
            if field_config.help_text,
              do: Map.put(field_map, :help_text, field_config.help_text),
              else: field_map

          field_map =
            if field_config.display_field,
              do: Map.put(field_map, :display_field, field_config.display_field),
              else: field_map

          field_map =
            if field_config.live_resource,
              do: Map.put(field_map, :live_resource, field_config.live_resource),
              else: field_map

          field_map =
            if field_config.options,
              do: Map.put(field_map, :options, field_config.options),
              else: field_map

          # Add required validation
          field_map =
            if argument && argument.allow_nil? == false do
              Map.put(field_map, :required, true)
            else
              field_map
            end

          # Add upload_key for Upload fields
          field_map =
            if field_map.module == Backpex.Fields.Upload do
              options = Map.get(field_map, :options, %{})
              options = Map.put_new(options, :upload_key, field_name)
              Map.put(field_map, :options, options)
            else
              field_map
            end

          # For BelongsTo fields, add the actual argument name for changeset casting
          field_map =
            if field_map.module == Backpex.Fields.BelongsTo do
              Map.put(field_map, :changeset_key, argument.name)
            else
              field_map
            end

          {field_name, field_map}
        end)
      else
        # Auto-derive fields from action arguments
        Enum.map(action.arguments, fn argument ->
          field_name = argument.name
          field_module = FieldHelpers.derive_field_module(argument.type)
          field_type = FieldHelpers.derive_ecto_type(argument.type)

          field_label =
            argument.name |> to_string() |> String.replace("_", " ") |> String.capitalize()

          # Build the field map with all options at the top level
          field_map = %{
            module: field_module,
            label: field_label,
            type: field_type
          }

          # Add additional options
          field_map =
            if argument.description do
              Map.put(field_map, :help_text, argument.description)
            else
              field_map
            end

          field_map =
            if argument.allow_nil? == false do
              Map.put(field_map, :required, true)
            else
              field_map
            end

          # Add upload_key for Upload fields
          field_map =
            if field_module == Backpex.Fields.Upload do
              options = Map.get(field_map, :options, %{})
              options = Map.put_new(options, :upload_key, field_name)
              Map.put(field_map, :options, options)
            else
              field_map
            end

          {field_name, field_map}
        end)
      end

    quote do
      use Backpex.ResourceAction

      @doc false
      def __ash_action__, do: unquote(action.name)

      @impl Backpex.ResourceAction
      def label, do: unquote(label)

      @impl Backpex.ResourceAction
      def title, do: unquote(title)

      @impl Backpex.ResourceAction
      def fields do
        unquote(Macro.escape(fields))
      end

      @impl Backpex.ResourceAction
      def base_schema(_assigns) do
        types = changeset_types_with_belongs_to(fields())
        {%{}, types}
      end

      defp changeset_types_with_belongs_to(fields) do
        fields
        |> Enum.map(fn {name, field_options} ->
          # For BelongsTo fields, use the changeset_key if available
          key = Map.get(field_options, :changeset_key, name)
          {key, field_options.type}
        end)
        |> Enum.into(%{})
      end

      @impl Backpex.ResourceAction
      def changeset(change, attrs, metadata) do
        types =
          unquote(resource)
          |> Ash.Resource.Info.action(unquote(action.name))
          |> Map.get(:arguments, [])
          |> Enum.map(fn arg ->
            {arg.name, derive_ecto_type(arg.type)}
          end)
          |> Map.new()

        change
        |> Ecto.Changeset.cast(attrs, Map.keys(types))
        |> validate_required_arguments()
        |> maybe_validate_with_metadata(metadata)
      end

      defp derive_ecto_type(type) do
        AshBackpex.FieldHelpers.derive_ecto_type(type)
      end

      defp validate_required_arguments(changeset) do
        required_fields =
          unquote(resource)
          |> Ash.Resource.Info.action(unquote(action.name))
          |> Map.get(:arguments, [])
          |> Enum.filter(&(&1.allow_nil? == false))
          |> Enum.map(& &1.name)

        Ecto.Changeset.validate_required(changeset, required_fields)
      end

      defp maybe_validate_with_metadata(changeset, metadata) do
        # Metadata contains :assigns and :target for context-aware validation
        # Users can override changeset/3 to use these for custom validation
        changeset
      end

      @impl Backpex.ResourceAction
      def handle(socket, params) do
        resource = unquote(resource)
        action_name = unquote(action.name)
        action_type = unquote(action.type)

        # Convert params to action arguments
        arguments =
          params
          |> Map.drop(["_csrf_token"])
          |> Enum.map(fn
            {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
            {k, v} when is_atom(k) -> {k, v}
          end)
          |> Map.new()

        # Get domain from resource
        domain = Ash.Resource.Info.domain(resource)

        # Execute the action based on its type
        case action_type do
          :action ->
            # For generic actions, use ActionInput
            try do
              result =
                resource
                |> Ash.ActionInput.for_action(action_name, arguments)
                |> Ash.run_action!(domain: domain)

              {:ok, Phoenix.LiveView.put_flash(socket, :info, "Action completed successfully")}
            rescue
              e ->
                changeset =
                  %{}
                  |> Ecto.Changeset.cast(%{}, [])
                  |> Ecto.Changeset.add_error(:base, Exception.message(e))

                {:error, changeset}
            end

          :create ->
            # For create actions
            case Ash.bulk_create([arguments], resource, action_name, domain: domain) do
              %Ash.BulkResult{status: :success} ->
                {:ok, Phoenix.LiveView.put_flash(socket, :info, "Created successfully")}

              %Ash.BulkResult{errors: errors} ->
                error_messages = Enum.map_join(errors, ", ", &Exception.message/1)

                changeset =
                  %{}
                  |> Ecto.Changeset.cast(%{}, [])
                  |> Ecto.Changeset.add_error(:base, error_messages)

                {:error, changeset}
            end

          :update ->
            # For update actions
            records = Ash.read!(resource, domain: domain)

            case Ash.bulk_update(records, action_name, arguments, domain: domain) do
              %Ash.BulkResult{status: :success} ->
                {:ok, Phoenix.LiveView.put_flash(socket, :info, "Updated successfully")}

              %Ash.BulkResult{errors: errors} ->
                error_messages = Enum.map_join(errors, ", ", &Exception.message/1)

                changeset =
                  %{}
                  |> Ecto.Changeset.cast(%{}, [])
                  |> Ecto.Changeset.add_error(:base, error_messages)

                {:error, changeset}
            end

          :destroy ->
            # For destroy actions
            records = Ash.read!(resource, domain: domain)

            case Ash.bulk_destroy(records, action_name, arguments, domain: domain) do
              %Ash.BulkResult{status: :success} ->
                {:ok, Phoenix.LiveView.put_flash(socket, :info, "Destroyed successfully")}

              %Ash.BulkResult{errors: errors} ->
                error_messages = Enum.map_join(errors, ", ", &Exception.message/1)

                changeset =
                  %{}
                  |> Ecto.Changeset.cast(%{}, [])
                  |> Ecto.Changeset.add_error(:base, error_messages)

                {:error, changeset}
            end
        end
      end
    end
  end
end
