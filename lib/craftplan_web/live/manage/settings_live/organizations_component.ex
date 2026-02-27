defmodule CraftplanWeb.SettingsLive.OrganizationsComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Organization Memberships
        <:subtitle>List of Organization Memberships</:subtitle>
      </.header>
    </div>
    """
  end

  @impl true
  def handle_event("save", %{"org" => _org_slug}, socket) do
    socket
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def choose(conn, %{"org" => org_slug}) do
    url =
      conn
      |> url(~p"/")
      |> subdomain(org_slug)

    redirect(conn, external: url)
  end

  defp subdomain(url, slug) do
    uri = URI.parse(url)
    host_parts = String.split(uri.host, ".")
    domain = host_parts |> Enum.take(-2) |> Enum.join(".")
    URI.to_string(%{uri | host: "#{slug}.#{domain}"})
  end
end
