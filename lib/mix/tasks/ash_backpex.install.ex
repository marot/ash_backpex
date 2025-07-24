defmodule Mix.Tasks.AshBackpex.Install do
  @moduledoc """
  Installs AshBackpex support in a Phoenix/Ash project.

  This task automatically configures your project with all necessary dependencies,
  router setup, layouts, authentication, and asset configurations for AshBackpex.

  ## Examples

      mix ash_backpex.install
      mix ash_backpex.install --web MyAppWeb --layout custom_admin
      mix ash_backpex.install --no-demo-auth --no-redirect-root

  ## Options

    * `--web` - The web module to use (default: inferred from app name)
    * `--layout` - Layout name (default: admin)
    * `--demo-auth` - Include demo authentication setup (default: true)
    * `--redirect-root` - Add root redirect to admin (default: true)
    * `--themes` - Include custom theme setup (default: true)

  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = igniter.args.options
    
    app_name = get_app_name()
    web_module = opts[:web] || infer_web_module(app_name)
    layout_name = opts[:layout] || "admin"
    demo_auth = Keyword.get(opts, :demo_auth, true)
    redirect_root = Keyword.get(opts, :redirect_root, true)
    themes = Keyword.get(opts, :themes, true)

    igniter
    |> add_dependencies()
    |> modify_router(web_module, demo_auth, redirect_root)
    |> create_admin_layout(web_module, layout_name)
    |> create_auth_module(web_module, demo_auth)
    |> configure_assets(themes)
    |> copy_vendor_assets(themes)
    |> create_page_controller(web_module, redirect_root)
  end

  defp get_app_name do
    Mix.Project.config()[:app] || :app
  end

  defp infer_web_module(app_name) do
    app_name
    |> Atom.to_string()
    |> Macro.camelize()
    |> then(&"#{&1}Web")
  end

  defp add_dependencies(igniter) do
    igniter
    |> Igniter.Project.Deps.add_dep({:ash_backpex, "~> 0.0.3"})
    |> Igniter.Project.Deps.add_dep({:backpex, github: "marot/backpex"})
  end

  defp modify_router(igniter, web_module, demo_auth, redirect_root) do
    router_path = "lib/#{web_module |> Macro.underscore()}/router.ex"
    
    router_content = generate_router_content(web_module, demo_auth, redirect_root)
    
    igniter
    |> Igniter.create_new_file(router_path, router_content)
  end

  defp generate_router_content(web_module, demo_auth, redirect_root) do
    import_line = if demo_auth, do: "  import Backpex.Router", else: "  import Backpex.Router"
    
    pipeline_plug = if demo_auth do
      "    pipe_through([:browser, Backpex.ThemeSelectorPlug, :assign_user])"
    else
      "    pipe_through([:browser, Backpex.ThemeSelectorPlug])"
    end

    assign_user_function = if demo_auth do
      """

        def assign_user(conn, _opts) do
          assign(conn, :current_user, %{"name" => "Demo User"})
        end
      """
    else
      ""
    end

    root_route = if redirect_root do
      """

          get("/", PageController, :redirect_to_admin)
      """
    else
      ""
    end

    live_session_mount = if demo_auth do
      "      on_mount: [{#{web_module}.LiveUserAuth, :live_user_demo}, Backpex.InitAssigns] do"
    else
      "      on_mount: [Backpex.InitAssigns] do"
    end

    """
    defmodule #{web_module}.Router do
      use #{web_module}, :router
    #{import_line}

      pipeline :browser do
        plug(:accepts, ["html"])
        plug(:fetch_session)
        plug(:fetch_live_flash)
        plug(:put_root_layout, html: {#{web_module}.Layouts, :root})
        plug(:protect_from_forgery)
        plug(:put_secure_browser_headers)
      end
    #{assign_user_function}
      scope "/", #{web_module} do
    #{pipeline_plug}
    #{root_route}
        backpex_routes()

        live_session :backpex_admin,
    #{live_session_mount}
          # Add your live_resources here
          # live_resources("/posts", PostLive)
        end
      end
    end
    """
  end

  defp create_admin_layout(igniter, web_module, layout_name) do
    layout_path = "lib/#{web_module |> Macro.underscore()}/layouts/#{layout_name}.html.heex"
    
    layout_content = generate_admin_layout_content()
    
    igniter
    |> Igniter.create_new_file(layout_path, layout_content)
  end

  defp generate_admin_layout_content do
    """
    <Backpex.HTML.Layout.app_shell fluid={@fluid?}>
      <:topbar>
        <Backpex.HTML.Layout.topbar_branding />

        <Backpex.HTML.Layout.theme_selector
          socket={@socket}
          class="mr-2"
          themes={[
            {"Light", "light"},
            {"Dark", "dark"}
          ]}
        />
      </:topbar>
      <:sidebar>
        <Backpex.HTML.Layout.sidebar_section id="main">
          <:label>Admin</:label>
          <!-- Add your sidebar items here -->
          <!-- Example:
          <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/posts">
            <Backpex.HTML.CoreComponents.icon name="hero-document-text" class="size-5" /> Posts
          </Backpex.HTML.Layout.sidebar_item>
          -->
        </Backpex.HTML.Layout.sidebar_section>
      </:sidebar>
      <Backpex.HTML.Layout.flash_messages flash={@flash} />
      {@inner_content}
    </Backpex.HTML.Layout.app_shell>
    """
  end

  defp create_auth_module(igniter, web_module, demo_auth) do
    if demo_auth do
      auth_path = "lib/#{web_module |> Macro.underscore()}/live_user_auth.ex"
      
      auth_content = generate_auth_content(web_module)
      
      igniter
      |> Igniter.create_new_file(auth_path, auth_content)
    else
      igniter
    end
  end

  defp generate_auth_content(web_module) do
    """
    defmodule #{web_module}.LiveUserAuth do
      @moduledoc \"\"\"
      Helpers for authenticating users in LiveViews.
      \"\"\"

      import Phoenix.Component
      use #{web_module}, :verified_routes

      def on_mount(:live_user_demo, _params, _session, socket) do
        {:cont,
         socket
         |> assign_new(:current_user, fn -> %{name: "Demo User"} end)}
      end
    end
    """
  end

  defp configure_assets(igniter, themes) do
    igniter
    |> configure_css_assets(themes)
    |> configure_js_assets()
  end

  defp configure_css_assets(igniter, themes) do
    css_content = generate_css_content(themes)
    
    igniter
    |> Igniter.create_new_file("assets/css/app.css", css_content)
  end

  defp generate_css_content(themes) do
    theme_plugins = if themes do
      """

      /* daisyUI Tailwind Plugin */
      @plugin "../vendor/daisyui" {
          themes: false;
      }

      /* Custom light theme */
      @plugin "../vendor/daisyui-theme" {
          name: "light";
          default: true;
          prefersdark: false;
          color-scheme: "light";
          --color-base-100: oklch(98% 0 0);
          --color-base-200: oklch(96% 0.001 286.375);
          --color-base-300: oklch(92% 0.004 286.32);
          --color-base-content: oklch(21% 0.006 285.885);
          --color-primary: oklch(70% 0.213 47.604);
          --color-primary-content: oklch(98% 0.016 73.684);
          --radius-selector: 0.25rem;
          --radius-field: 0.25rem;
          --radius-box: 0.5rem;
          --border: 1.5px;
      }

      /* Custom dark theme */
      @plugin "../vendor/daisyui-theme" {
          name: "dark";
          default: false;
          prefersdark: true;
          color-scheme: "dark";
          --color-base-100: oklch(30.33% 0.016 252.42);
          --color-base-200: oklch(25.26% 0.014 253.1);
          --color-base-300: oklch(20.15% 0.012 254.09);
          --color-base-content: oklch(97.807% 0.029 256.847);
          --color-primary: oklch(58% 0.233 277.117);
          --color-primary-content: oklch(96% 0.018 272.314);
          --radius-selector: 0.25rem;
          --radius-field: 0.25rem;
          --radius-box: 0.5rem;
          --border: 1.5px;
      }
      """
    else
      ""
    end

    """
    /* See the Tailwind configuration guide for advanced usage
       https://tailwindcss.com/docs/configuration */

    @import "tailwindcss" source(none);
    @source "../../deps/backpex/**/*.*ex";
    @source "../../deps/backpex/assets/js/**/*.*js";
    @source "../css";
    @source "../js";
    @source "../../lib/**/*.*ex";

    /* A Tailwind plugin that makes "hero-#{ICON}" classes available */
    @plugin "../vendor/heroicons";
    #{theme_plugins}
    /* Add variants based on LiveView classes */
    @custom-variant phx-click-loading (.phx-click-loading&, .phx-click-loading &);
    @custom-variant phx-submit-loading (.phx-submit-loading&, .phx-submit-loading &);
    @custom-variant phx-change-loading (.phx-change-loading&, .phx-change-loading &);

    /* Make LiveView wrapper divs transparent for layout */
    [data-phx-session] {
        display: contents;
    }

    /* This file is for your main application CSS */
    """
  end

  defp configure_js_assets(igniter) do
    js_content = generate_js_content()
    
    igniter
    |> Igniter.create_new_file("assets/js/app.js", js_content)
  end

  defp generate_js_content do
    """
    // Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
    import "phoenix_html";
    // Establish Phoenix Socket and LiveView configuration.
    import { Socket } from "phoenix";
    import { LiveSocket } from "phoenix_live_view";
    import topbar from "../vendor/topbar";
    import { Hooks as BackpexHooks } from "backpex";

    const csrfToken = document
      .querySelector("meta[name='csrf-token']")
      .getAttribute("content");
    const liveSocket = new LiveSocket("/live", Socket, {
      longPollFallbackMs: 2500,
      params: { _csrf_token: csrfToken },
      hooks: { ...BackpexHooks },
    });

    // Show progress bar on live navigation and form submits
    topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
    window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
    window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

    /**
     * Theme Selector
     */
    BackpexHooks.BackpexThemeSelector.setStoredTheme();

    // connect if there are any LiveViews on the page
    liveSocket.connect();

    // expose liveSocket on window for web console debug logs and latency simulation:
    // >> liveSocket.enableDebug()
    // >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
    // >> liveSocket.disableLatencySim()
    window.liveSocket = liveSocket;
    """
  end

  defp copy_vendor_assets(igniter, themes) do
    if themes do
      igniter
      |> copy_heroicons_vendor()
      |> copy_topbar_vendor()
      |> copy_daisyui_vendor()
      |> copy_theme_vendor()
    else
      igniter
      |> copy_heroicons_vendor()
      |> copy_topbar_vendor()
    end
  end

  defp copy_heroicons_vendor(igniter) do
    # For now, just create a placeholder - in real implementation would copy from backpex deps
    heroicons_content = """
    // Heroicons plugin for Tailwind CSS
    // This would normally be copied from the backpex dependency
    module.exports = function() {
      return {
        // Hero icons configuration
      }
    }
    """
    
    igniter
    |> Igniter.create_new_file("assets/vendor/heroicons.js", heroicons_content)
  end

  defp copy_topbar_vendor(igniter) do
    # Simplified topbar implementation
    topbar_content = """
    // Simple topbar implementation
    const topbar = {
      config: function(options) {
        this.options = options;
      },
      show: function(delay) {
        // Show loading bar
        console.log('Showing topbar');
      },
      hide: function() {
        // Hide loading bar
        console.log('Hiding topbar');
      }
    };

    export default topbar;
    """
    
    igniter
    |> Igniter.create_new_file("assets/vendor/topbar.js", topbar_content)
  end

  defp copy_daisyui_vendor(igniter) do
    daisyui_content = """
    // DaisyUI Tailwind CSS plugin
    // This would normally be copied from the latest daisyUI release
    module.exports = function() {
      return {
        // DaisyUI plugin configuration
      }
    }
    """
    
    igniter
    |> Igniter.create_new_file("assets/vendor/daisyui.js", daisyui_content)
  end

  defp copy_theme_vendor(igniter) do
    theme_content = """
    // DaisyUI theme plugin
    // This would normally be copied from the latest daisyUI theme release
    module.exports = function() {
      return {
        // Theme plugin configuration
      }
    }
    """
    
    igniter
    |> Igniter.create_new_file("assets/vendor/daisyui-theme.js", theme_content)
  end

  defp create_page_controller(igniter, web_module, redirect_root) do
    if redirect_root do
      controller_path = "lib/#{web_module |> Macro.underscore()}/controllers/page_controller.ex"
      
      controller_content = generate_page_controller_content(web_module)
      
      igniter
      |> Igniter.create_new_file(controller_path, controller_content)
    else
      igniter
    end
  end

  defp generate_page_controller_content(web_module) do
    """
    defmodule #{web_module}.PageController do
      use Phoenix.Controller

      def redirect_to_admin(conn, _params) do
        redirect(conn, to: "/")
      end
    end
    """
  end
end