defmodule CraftplanWeb.OrganizationController do
  use CraftplanWeb, :controller

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
