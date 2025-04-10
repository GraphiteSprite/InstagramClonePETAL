defmodule InstagramCloneWeb do
  @moduledoc """
  The entrypoint for defining your web interface.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: InstagramCloneWeb.Layouts]
      
      import Plug.Conn
      import InstagramCloneWeb.Gettext
      
      unquote(verified_routes())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {InstagramCloneWeb.Layouts, :app}
      
      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import InstagramCloneWeb.Gettext
    end
  end

  def html do
    quote do
      use Phoenix.Component
      import PetalComponents
      
      # Import convenience functions for HTML
      import Phoenix.HTML
      import Phoenix.LiveView.Helpers
      
      # Import core UI components
      import InstagramCloneWeb.CoreComponents
      
      # Import custom helpers
      import InstagramCloneWeb.Gettext
      
      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS
      
      # Routes generation
      unquote(verified_routes())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import InstagramCloneWeb.CoreComponents
      import InstagramCloneWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: InstagramCloneWeb.Endpoint,
        router: InstagramCloneWeb.Router,
        statics: InstagramCloneWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
