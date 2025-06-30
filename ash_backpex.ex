defmodule AshBackpex do
  defmacro __using__(opts \\ []) do
    quote do
      opts = unquote(opts)

      layout = Keyword.get(opts, :layout)

      resource = Keyword.get(opts, :resource)

      if !resource
         |> Ash.Resource.Info.resource?() do
        raise "You must provide a valid Ash.Resource as the :resource option to AshBackpex. Received: #{inspect(resource)}"
      end

      if is_nil(layout) do
        raise "You must provide a :layout to use with your resource. Got nil. E.g.:
          `layout: {MyAppWeb.Layouts, :admin}`
        "
      end

      # IO.inspect(resource)
      data_layer = resource |> Ash.Resource.Info.data_layer()

      if is_nil(data_layer) do
        raise "The provided resource #{inspect(resource)} does not have a data layer configured. A data layer is required"
      end

      data_layer_info_module = ((data_layer |> Atom.to_string()) <> ".Info") |> String.to_atom()
      repo = resource |> data_layer_info_module.repo()

      default_action = fn resource, action_type ->
        Ash.Resource.Info.primary_action(resource, action_type)
        |> Kernel.then(fn a ->
          if is_nil(a) do
            %{}
          else
            a
          end
        end)
        |> Map.get(:name, action_type)
      end

      @create_action Keyword.get(
                       opts,
                       :create_action,
                       default_action.(resource, :create)
                     )

      @update_action Keyword.get(
                       opts,
                       :update_action,
                       default_action.(resource, :update)
                     )

      @read_action Keyword.get(
                     opts,
                     :read_action,
                     default_action.(resource, :read)
                   )

      @destroy_action Keyword.get(
                        opts,
                        :destroy_action,
                        default_action.(resource, :destroy)
                      )

      create_changeset =
        Keyword.get(
          opts,
          :create_changeset,
          &AshBackpex.Adapter.create_changeset/3
        )

      update_changeset =
        Keyword.get(opts, :update_changeset, &AshBackpex.Adapter.update_changeset/3)

      load_fn = Keyword.get(opts, :load, &AshBackpex.Adapter.load/3)

      use Backpex.LiveResource,
        adapter: AshBackpex.Adapter,
        adapter_config: [
          resource: resource,
          schema: resource,
          repo: repo,
          create_action: @create_action,
          update_action: @update_action,
          create_changeset: create_changeset,
          update_changeset: update_changeset,
          load: load_fn
        ],
        layout: {InsiWeb.Layouts, :admin}

      @impl Backpex.LiveResource
      def can?(assigns, action, item) when action in [:index, :show, :edit, :delete, :new] do
        live_resource = assigns.live_resource
        config = live_resource.config(:adapter_config)
        ash_resource = Keyword.get(config, :resource)

        case action do
          :index -> deny_if_no_user_present_for_action(ash_resource, assigns, :read, false)
          :show -> deny_if_no_user_present_for_action(ash_resource, assigns, :read)
          :edit -> deny_if_no_user_present_for_action(ash_resource, assigns, :update)
          :delete -> deny_if_no_user_present_for_action(ash_resource, assigns, :destroy)
          :new -> deny_if_no_user_present_for_action(ash_resource, assigns, :create)
        end
      end

      defp deny_if_no_user_present_for_action(ash_resource, assigns, action_type, deny \\ false) do
        action =
          case action_type do
            :create -> @create_action
            :update -> @update_action
            :read -> @read_action
            :destroy -> @destroy_action
          end

        case Map.get(assigns, :current_user) do
          nil -> !deny
          curr_user -> Ash.can?({ash_resource, action}, curr_user)
        end
      end
    end
  end
end
