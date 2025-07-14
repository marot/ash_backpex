defmodule AshBackpex.LiveResource.Transformers.GenerateBackpex do
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    backpex =
      quote do
        @resource Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :resource)
        @data_layer_info_module ((@resource |> Ash.Resource.Info.data_layer() |> Atom.to_string()) <>
                                   ".Info")
                                |> String.to_existing_atom()
        @repo @resource |> @data_layer_info_module.repo()

        @panels Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :panels) || []

        @singular_name Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :singular_name) ||
                         @resource |> Atom.to_string() |> String.split(".") |> List.last()

        @plural_name Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :plural_name) ||
                       (@resource |> Atom.to_string() |> String.split(".") |> List.last()) <> "s"

        @create_action Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :create_action) ||
                         Ash.Resource.Info.primary_action(@resource, :create)
                         |> then(&(&1 || %{}))
                         |> Map.get(:name, :create)

        @read_action Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :read_action) ||
                       Ash.Resource.Info.primary_action(@resource, :read)
                       |> then(&(&1 || %{}))
                       |> Map.get(:name, :read)

        @update_action Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :update_action) ||
                         Ash.Resource.Info.primary_action(@resource, :update)
                         |> then(&(&1 || %{}))
                         |> Map.get(:name, :update)

        @destroy_action Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :destroy_action) ||
                          Ash.Resource.Info.primary_action(@resource, :destroy)
                          |> then(&(&1 || %{}))
                          |> Map.get(:name, :destroy)

        atom_to_title_case = fn atom ->
          atom
          |> Atom.to_string()
          |> String.split("_")
          |> Enum.map_join(" ", &String.capitalize/1)
        end

        try_derive_module = fn attribute_name ->
          type =
            cond do
              !is_nil(Ash.Resource.Info.attribute(@resource, attribute_name)) ->
                Ash.Resource.Info.attribute(@resource, attribute_name).type

              !is_nil(Ash.Resource.Info.relationship(@resource, attribute_name)) ->
                Ash.Resource.Info.relationship(@resource, attribute_name).type

              !is_nil(Ash.Resource.Info.calculation(@resource, attribute_name)) ->
                Ash.Resource.Info.calculation(@resource, attribute_name).type

              !is_nil(Ash.Resource.Info.aggregate(@resource, attribute_name)) ->
                Ash.Resource.Info.aggregate(@resource, attribute_name).kind

              true ->
                raise "Unable to derive the field type for #{inspect(attribute_name)} field in #{__MODULE__}. Please specify a field type."
            end

          # Handle special cases first, then use helper for regular types
          case type do
            Ash.Type.Atom -> Backpex.Fields.Text
            Ash.Type.CiString -> Backpex.Fields.Text
            Ash.Type.UtcDatetime -> Backpex.Fields.DateTime
            Ash.Type.UtcDatetimeUsec -> Backpex.Fields.DateTime
            Ash.Type.NaiveDateTime -> Backpex.Fields.DateTime
            Ash.Type.Time -> Backpex.Fields.Time
            :belongs_to -> Backpex.Fields.BelongsTo
            :has_many -> Backpex.Fields.HasMany
            :count -> Backpex.Fields.Number
            :exists -> Backpex.Fields.Boolean
            :sum -> Backpex.Fields.Number
            :max -> Backpex.Fields.Number
            :min -> Backpex.Fields.Number
            :avg -> Backpex.Fields.Number
            _ -> AshBackpex.FieldHelpers.derive_field_module(type)
          end
        end

        @fields Spark.Dsl.Extension.get_entities(__MODULE__, [:backpex, :fields])
                |> Enum.reverse()
                |> Enum.reduce([], fn field, acc ->
                  module = field.module || field.attribute |> try_derive_module.()

                  field_map = %{
                    module: module,
                    label: field.label || field.attribute |> atom_to_title_case.(),
                    only: field.only,
                    except: field.except,
                    default: field.default,
                    options: field.options,
                    display_field: field.display_field,
                    live_resource: field.live_resource,
                    panel: field.panel,
                    link_assocs:
                      case {module, Map.get(field, :link_assocs)} do
                        {Backpex.Fields.HasMany, nil} -> true
                        {Backpex.Fields.HasMany, true} -> true
                        {Backpex.Fields.HasMany, false} -> false
                        _ -> nil
                      end
                  }

                  # Add upload_key for Upload fields
                  field_map =
                    if module == Backpex.Fields.Upload do
                      options = Map.get(field_map, :options, %{})
                      options = Map.put_new(options, :upload_key, field.attribute)
                      Map.put(field_map, :options, options)
                    else
                      field_map
                    end

                  field_map =
                    field_map
                    |> Map.to_list()
                    |> Enum.reject(fn {k, v} -> is_nil(v) end)
                    |> Map.new()

                  Keyword.put(acc, field.attribute, field_map)
                end)

        @filters Spark.Dsl.Extension.get_entities(__MODULE__, [:backpex, :filters])
                 |> Enum.reduce([], fn filter, acc ->
                   Keyword.put(
                     acc,
                     filter.attribute,
                     %{
                       module: filter.module,
                       label: filter.label || filter.attribute |> atom_to_title_case.()
                     }
                   )
                 end)

        @item_actions Spark.Dsl.Extension.get_entities(__MODULE__, [:backpex, :item_actions])
                      |> Enum.reduce([], fn action, acc ->
                        Keyword.put(
                          acc,
                          action.name,
                          %{
                            module: action.module
                          }
                        )
                      end)

        @item_action_strip_defaults Spark.Dsl.Extension.get_opt(
                                      __MODULE__,
                                      [:backpex, :item_actions],
                                      :strip_default
                                    ) || []

        @resource_actions Spark.Dsl.Extension.get_entities(__MODULE__, [
                            :backpex,
                            :resource_actions
                          ])
                          |> Enum.reduce([], fn action, acc ->
                            Keyword.put(
                              acc,
                              action.name,
                              %{module: action.module}
                            )
                          end)

        use Backpex.LiveResource,
          adapter: AshBackpex.Adapter,
          layout: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :layout),
          adapter_config: [
            resource: @resource,
            schema: @resource,
            repo: @repo,
            create_action: @create_action,
            read_action: @read_action,
            update_action: @update_action,
            destroy_action: @destroy_action,
            create_changeset:
              Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :create_changeset) ||
                (&AshBackpex.Adapter.create_changeset/3),
            update_changeset:
              Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :update_changeset) ||
                (&AshBackpex.Adapter.update_changeset/3),
            load:
              case Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :load) do
                nil -> &AshBackpex.Adapter.load/3
                some_loads -> &__MODULE__.load/3
              end
          ]

        @impl Backpex.LiveResource
        def fields(), do: @fields

        @impl Backpex.LiveResource
        def filters(), do: @filters

        @impl Backpex.LiveResource
        def item_actions(defaults) do
          defaults = Keyword.drop(defaults, @item_action_strip_defaults)

          @item_actions
          |> Enum.reduce(defaults, fn {k, v}, acc ->
            Keyword.put(acc, k, v)
          end)
        end

        @impl Backpex.LiveResource
        def resource_actions() do
          @resource_actions
        end

        @impl Backpex.LiveResource
        def singular_name, do: @singular_name

        @impl Backpex.LiveResource
        def plural_name, do: @plural_name

        @impl Backpex.LiveResource
        def panels, do: @panels

        def load(_, _, _), do: Spark.Dsl.Extension.get_opt(__MODULE__, [:backpex], :load)

        @impl Backpex.LiveResource
        def can?(assigns, action, item) do
          deny_if_no_user_present_for_action? = fn resource, assigns, action_type, deny ->
            action =
              case action_type do
                :create -> @create_action
                :update -> @update_action
                :read -> @read_action
                :destroy -> @destroy_action
              end

            case Map.get(assigns, :current_user) do
              nil ->
                !deny

              curr_user ->
                # assigns
                if Ash.Resource.Info.action(@resource, action) do
                  Ash.can?({@resource, action}, curr_user)
                else
                  false
                end
            end
          end

          case action do
            :index ->
              deny_if_no_user_present_for_action?.(@resource, assigns, :read, false)

            :show ->
              deny_if_no_user_present_for_action?.(@resource, assigns, :read, false)

            :edit ->
              deny_if_no_user_present_for_action?.(@resource, assigns, :update, true)

            :delete ->
              deny_if_no_user_present_for_action?.(@resource, assigns, :destroy, true)

            :new ->
              deny_if_no_user_present_for_action?.(@resource, assigns, :create, true)

            action_key ->
              # Check if this is a resource action
              if Keyword.has_key?(@resource_actions, action_key) do
                case Map.get(assigns, :current_user) do
                  nil ->
                    false

                  curr_user ->
                    # Get the actual Ash action name from the resource action module
                    resource_action_module = @resource_actions[action_key][:module]
                    ash_action_name = resource_action_module |> apply(:__ash_action__, [])

                    if Ash.Resource.Info.action(@resource, ash_action_name) do
                      Ash.can?({@resource, ash_action_name}, curr_user)
                    else
                      false
                    end
                end
              else
                # Default to true for unknown actions
                true
              end
          end
        end

        Backpex.LiveResource.__before_compile__(__ENV__)
      end

    {:ok, Spark.Dsl.Transformer.eval(dsl_state, [], backpex)}
  end
end
