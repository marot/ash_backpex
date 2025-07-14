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
        # Only support generic actions
        if action.type != :action do
          {:error,
           "Only generic actions are supported for resource actions. Got #{inspect(action.type)}"}
        else
          # Generate the code directly instead of using after_compile
          quoted =
            generate_resource_action_code(resource, action, label, title, configured_fields)

          {:ok, Spark.Dsl.Transformer.eval(dsl_state, [], quoted)}
        end
      end
    else
      {:error, "Both resource and action must be configured"}
    end
  end

  defp generate_resource_action_code(resource, action, label, title, configured_fields) do
    atom_to_title_case = fn atom ->
      atom
      |> to_string()
      |> String.replace("_", " ")
      |> String.capitalize()
    end

    # Generate label with default if not provided
    label = label || atom_to_title_case.(action.name)

    # Generate title with default if not provided
    title = title || atom_to_title_case.(action.name)

    # Generate fields from configured fields or auto-derive from action arguments
    fields =
      if configured_fields && !Enum.empty?(configured_fields) do
        # Use explicitly configured fields
        configured_fields
        |> Enum.reverse()
        |> Enum.reduce([], fn field_config, acc ->
          field_name = field_config.argument

          # Get the argument definition for additional info
          # For BelongsTo fields, try to find the foreign key argument if direct lookup fails
          argument =
            Enum.find(action.arguments, &(&1.name == field_name)) ||
              if field_config.module == Backpex.Fields.BelongsTo do
                foreign_key_name = String.to_atom("#{field_name}_id")
                Enum.find(action.arguments, &(&1.name == foreign_key_name))
              else
                nil
              end

          if is_nil(argument) do
            raise "No argument found for field #{inspect(field_name)}. Available arguments: #{inspect(Enum.map(action.arguments, & &1.name))}"
          end

          # Build the field map
          derived_module = field_config.module || FieldHelpers.derive_field_module(argument.type)

          field_map = %{
            module: derived_module,
            label: field_config.label || atom_to_title_case.(field_name),
            type: FieldHelpers.derive_ecto_type(argument.type),
            help_text: field_config.help_text,
            display_field: field_config.display_field,
            live_resource: field_config.live_resource,
            options: field_config.options,
            required: argument && argument.allow_nil? == false
          }

          # Add upload-specific fields
          field_map =
            if derived_module == Backpex.Fields.Upload do
              options = field_config.options || %{}

              Map.merge(field_map, %{
                upload_key: field_name,
                file_label: Map.get(options, :file_label),
                max_entries: Map.get(options, :max_entries, 1),
                accept: Map.get(options, :accept, []),
                max_file_size: Map.get(options, :max_file_size, 10_485_760)
              })
            else
              field_map
            end

          # Add BelongsTo-specific fields
          field_map =
            if derived_module == Backpex.Fields.BelongsTo do
              Map.put(field_map, :changeset_key, argument.name)
            else
              field_map
            end

          # Filter out nil values
          field_map =
            field_map
            |> Map.to_list()
            |> Enum.reject(fn {_k, v} -> is_nil(v) end)
            |> Map.new()

          Keyword.put(acc, field_name, field_map)
        end)
      else
        # Auto-derive fields from action arguments
        action.arguments
        |> Enum.reverse()
        |> Enum.reduce([], fn argument, acc ->
          field_name = argument.name
          field_module = FieldHelpers.derive_field_module(argument.type)

          field_map = %{
            module: field_module,
            label: atom_to_title_case.(field_name),
            type: FieldHelpers.derive_ecto_type(argument.type),
            help_text: argument.description,
            required: argument.allow_nil? == false
          }

          # Add upload-specific fields
          field_map =
            if field_module == Backpex.Fields.Upload do
              Map.merge(field_map, %{
                upload_key: field_name,
                max_entries: 1,
                accept: [],
                max_file_size: 10_485_760
              })
            else
              field_map
            end

          # Filter out nil values
          field_map =
            field_map
            |> Map.to_list()
            |> Enum.reject(fn {_k, v} -> is_nil(v) end)
            |> Map.new()

          Keyword.put(acc, field_name, field_map)
        end)
      end

    # Collect upload fields to generate callbacks
    upload_fields =
      fields
      |> Enum.filter(fn {_name, config} -> config.module == Backpex.Fields.Upload end)
      |> Enum.map(fn {name, _config} -> name end)

    quote do
      @resource unquote(resource)
      @action_name unquote(action.name)
      @label unquote(label)
      @title unquote(title)
      @fields unquote(Macro.escape(fields))

      atom_to_title_case = fn atom ->
        atom
        |> to_string()
        |> String.replace("_", " ")
        |> String.capitalize()
      end

      use Backpex.ResourceAction

      @doc false
      def __ash_action__, do: @action_name

      @impl Backpex.ResourceAction
      def label, do: @label

      @impl Backpex.ResourceAction
      def title, do: @title

      @impl Backpex.ResourceAction
      def base_schema(_assigns) do
        action = Ash.Resource.Info.action(@resource, @action_name)
        fields_map = Map.new(fields())

        # Build types map from action arguments
        types =
          action
          |> Map.get(:arguments, [])
          |> Enum.map(fn arg ->
            # For file uploads, use :string type in changeset validation
            type = if arg.type == Ash.Type.File, do: :string, else: derive_ecto_type(arg.type)
            {arg.name, type}
          end)
          |> Map.new()

        # Also add types for BelongsTo fields that need _id suffix
        belongs_to_types =
          fields_map
          |> Enum.filter(fn {_name, config} -> config.module == Backpex.Fields.BelongsTo end)
          |> Enum.map(fn {field_name, config} ->
            # Get the changeset_key or default to field_name_id
            key = Map.get(config, :changeset_key, field_name)
            # Find the type from the action arguments
            arg = Enum.find(action.arguments, &(&1.name == key))
            type = if arg, do: derive_ecto_type(arg.type), else: :binary_id
            {key, type}
          end)
          |> Map.new()

        # Merge the types, with belongs_to_types taking precedence
        all_types = Map.merge(types, belongs_to_types)

        {%{}, all_types}
      end

      @impl Backpex.ResourceAction
      def fields do
        base_fields = @fields

        # Process each field at runtime to inject callbacks
        unquote_splicing(
          fields
          |> Enum.filter(fn {_name, config} -> config.module == Backpex.Fields.Upload end)
          |> Enum.map(fn {name, _config} ->
            quote do
              base_fields =
                Enum.map(base_fields, fn
                  {unquote(name), config} when config.module == Backpex.Fields.Upload ->
                    config =
                      config
                      |> Map.put_new(
                        :list_existing_files,
                        Function.capture(
                          __MODULE__,
                          unquote(:"list_existing_files_for_#{name}"),
                          1
                        )
                      )
                      |> Map.put_new(
                        :put_upload_change,
                        Function.capture(__MODULE__, unquote(:"put_upload_change_for_#{name}"), 6)
                      )
                      |> Map.put_new(
                        :consume_upload,
                        Function.capture(__MODULE__, unquote(:"consume_upload_for_#{name}"), 4)
                      )
                      |> Map.put_new(
                        :remove_uploads,
                        Function.capture(__MODULE__, unquote(:"remove_uploads_for_#{name}"), 3)
                      )

                    {unquote(name), config}

                  other ->
                    other
                end)
            end
          end)
        )

        base_fields
      end

      @impl Backpex.ResourceAction
      def changeset(change, attrs, metadata) do
        action = Ash.Resource.Info.action(@resource, @action_name)
        fields_list = @fields
        fields_map = Map.new(fields_list)

        # Process attrs to handle BelongsTo fields
        processed_attrs =
          Enum.reduce(attrs, %{}, fn {key, value}, acc ->
            key_atom = if is_binary(key), do: String.to_atom(key), else: key
            field_config = Map.get(fields_map, key_atom)

            if field_config && field_config.module == Backpex.Fields.BelongsTo do
              # For BelongsTo fields, use the changeset_key if it exists, otherwise add _id
              target_key = Map.get(field_config, :changeset_key, key_atom)
              Map.put(acc, target_key, value)
            else
              Map.put(acc, key_atom, value)
            end
          end)

        types =
          action
          |> Map.get(:arguments, [])
          |> Enum.map(fn arg ->
            # For file uploads, use :string type in changeset validation
            type = if arg.type == Ash.Type.File, do: :string, else: derive_ecto_type(arg.type)
            {arg.name, type}
          end)
          |> Map.new()

        changeset =
          change
          |> Ecto.Changeset.cast(processed_attrs, Map.keys(types))

        # Get upload fields from the action
        upload_fields =
          action.arguments
          |> Enum.filter(&(&1.type == Ash.Type.File))
          |> Enum.map(& &1.name)

        changeset =
          changeset
          |> validate_required_arguments()
          |> validate_upload_fields(upload_fields)
          |> maybe_validate_with_metadata(metadata)

        changeset
      end

      defp derive_ecto_type(type) do
        AshBackpex.FieldHelpers.derive_ecto_type(type)
      end

      defp validate_required_arguments(changeset) do
        required_fields =
          @resource
          |> Ash.Resource.Info.action(@action_name)
          |> Map.get(:arguments, [])
          |> Enum.filter(&(&1.allow_nil? == false))
          |> Enum.map(& &1.name)

        Ecto.Changeset.validate_required(changeset, required_fields)
      end

      defp validate_upload_fields(changeset, upload_fields) do
        Enum.reduce(upload_fields, changeset, fn field, acc ->
          acc
          |> Ecto.Changeset.validate_length(field, min: 1)
          |> Ecto.Changeset.validate_change(field, fn
            ^field, "too_many_files" ->
              [{field, "has to be exactly one file"}]

            ^field, "" ->
              [{field, "can't be blank"}]

            ^field, _value ->
              []
          end)
        end)
      end

      defp maybe_validate_with_metadata(changeset, metadata) do
        # Metadata contains :assigns and :target for context-aware validation
        # Users can override changeset/3 to use these for custom validation
        changeset
      end

      @impl Backpex.ResourceAction
      def handle(socket, params) do
        resource = @resource
        action_name = @action_name

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

        # Process file arguments - convert paths to Ash.Type.File
        action = Ash.Resource.Info.action(resource, action_name)

        processed_arguments =
          Enum.reduce(arguments, %{}, fn {key, value}, acc ->
            arg = Enum.find(action.arguments, &(&1.name == key))

            processed_value =
              if arg && arg.type == Ash.Type.File && is_binary(value) do
                Ash.Type.File.from_path(value)
              else
                value
              end

            Map.put(acc, key, processed_value)
          end)

        # Execute the generic action
        try do
          result =
            resource
            |> Ash.ActionInput.for_action(action_name, processed_arguments)
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
      end

      # Generate upload callbacks for each upload field
      unquote_splicing(
        Enum.flat_map(upload_fields, fn field_name ->
          [
            # list_existing_files callback
            quote do
              def unquote(:"list_existing_files_for_#{field_name}")(_item) do
                []
              end
            end,

            # put_upload_change callback
            quote do
              def unquote(:"put_upload_change_for_#{field_name}")(
                    _socket,
                    params,
                    _item,
                    uploaded_entries,
                    removed_entries,
                    action
                  ) do
                existing_files = [] -- removed_entries

                new_entries =
                  case action do
                    :validate ->
                      elem(uploaded_entries, 1)

                    :insert ->
                      elem(uploaded_entries, 0)
                  end

                files = existing_files ++ Enum.map(new_entries, fn entry -> file_name(entry) end)

                result =
                  case files do
                    [file] ->
                      Map.put(params, unquote(to_string(field_name)), file)

                    [_file | _other_files] ->
                      Map.put(params, unquote(to_string(field_name)), "too_many_files")

                    [] ->
                      Map.put(params, unquote(to_string(field_name)), "")
                  end

                result
              end
            end,

            # consume_upload callback
            quote do
              def unquote(:"consume_upload_for_#{field_name}")(_socket, _item, _meta, entry) do
                # For now, just return the client name as the path
                # In production, you'd save the file and return the saved path
                {:ok, entry.client_name}
              end
            end,

            # remove_uploads callback
            quote do
              def unquote(:"remove_uploads_for_#{field_name}")(_socket, _item, _removed_entries) do
                :ok
              end
            end
          ]
        end)
      )

      # Helper function for file names
      defp file_name(entry) do
        entry.client_name
      end
    end
  end
end
