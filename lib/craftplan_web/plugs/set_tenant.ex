defmodule CraftplanWeb.SetTenant do
  @moduledoc """
  Establishes the current_tenant on the Conn.
  """
  @behaviour Plug

  def init([]), do: []

  # User authenticated
  def call(conn, _opts) when is_struct(conn.assigns.current_user) do
    user =
      Ash.load!(conn.assigns.current_user, [:organizations], actor: conn.assigns.current_user)

    slug = tenant_slug(conn)
    tenant = choose_tenant(user, slug)

    conn
    |> Plug.Conn.assign(:current_tenant, tenant)
    |> Ash.PlugHelpers.set_tenant(tenant)
  end

  # No user
  def call(conn, _opts) do
    Plug.Conn.assign(conn, :current_tenant, nil)
  end

  defp tenant_slug(conn) do
    # Extract the subdomain if there is one
    case String.split(conn.host, ".") do
      [subdomain | rest] when length(rest) >= 2 -> subdomain
      _ -> nil
    end
  end

  # Not on a subdomain
  defp choose_tenant(user, nil) do
    case user.organizations do
      # for convenience, if a user belongs to a single org, use it
      [org] -> org
      # otherwise ambiguous, don't set a tenant until user is on a subdomain
      _ -> nil
    end
  end

  # On a subdomain, use it to set the current tenant if the user is a member
  defp choose_tenant(user, slug) do
    Enum.find(user.organizations, fn org -> org.slug == slug end)
  end
end
