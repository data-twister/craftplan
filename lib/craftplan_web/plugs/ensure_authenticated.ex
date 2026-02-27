defmodule CraftplanWeb.EnsureAuthenticated do
  @moduledoc false
  @behaviour Plug

  # Plug Implementation
  @impl Plug
  def init(opts) do
    opts |> Keyword.validate!([:user_required, :tenant_required]) |> Map.new()
  end

  @impl Plug
  def call(conn, opts) do
    with :ok <- user_required(conn.assigns, opts),
         :ok <- tenant_required(conn.assigns, opts) do
      conn
    else
      {:error, :no_user} ->
        redirect(conn, "/sign-in")

      {:error, :no_tenant} ->
        redirect(conn, "/sign-in")
    end
  end

  defp user_required(assigns, %{user_required: true}) do
    if assigns[:current_user], do: :ok, else: {:error, :no_user}
  end

  defp user_required(_conn, _opts) do
    :ok
  end

  defp tenant_required(assigns, %{tenant_required: true}) do
    if assigns[:current_tenant], do: :ok, else: {:error, :no_tenant}
  end

  defp tenant_required(_conn, _opts) do
    :ok
  end

  defp redirect(conn, to) do
    conn
    |> Phoenix.Controller.redirect(to: to)
    |> Plug.Conn.halt()
  end
end
