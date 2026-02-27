defmodule CraftplanWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :craftplan

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_craftplan_key",
    signing_salt: "qsdH+y3l",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: {__MODULE__, :session_opts, []}]],
    longpoll: [connect_info: [session: {__MODULE__, :session_opts, []}]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :craftplan,
    gzip: false,
    only: CraftplanWeb.static_paths(),
    headers: {__MODULE__, :static_headers, []}

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :craftplan
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Sentry.PlugContext

  plug Plug.MethodOverride
  plug Plug.Head
  plug :session
  plug :health
  plug :version
  plug CORSPlug
  # Enable Ecto SQL Sandbox for LiveView tests to share the DB connection
  # SQL Sandbox plug not needed with LiveViewTest server: false
  plug CraftplanWeb.Router

  def session(conn, _opts) do
    opts = session_opts()
    Plug.Session.call(conn, Plug.Session.init(opts))
  end

  def session_opts do
    Keyword.put(@session_options, :domain, CraftplanWeb.Endpoint.host())
  end

  def health(conn, _) do
    case conn do
      %{request_path: "/health"} -> conn |> send_resp(200, "OK") |> halt()
      _ -> conn
    end
  end

  def version(conn, _) do
    case conn do
      %{request_path: "/version"} ->
        data = Craftplan.Application.version() |> Map.new() |> Jason.encode!()
        conn |> put_resp_content_type("application/json") |> send_resp(200, data) |> halt()

      %{request_path: "/version/build"} ->
        [app: name] = Craftplan.Application.name()
        [version: version] = Craftplan.Application.version()
        [description: description] = Craftplan.Application.description()
        [build_date: build_date] = Craftplan.Application.build_date()
        [build_hash: build_hash] = Craftplan.Application.build_hash()

        data =
          Map.new()
          |> Map.put(:application, %{
            name: name,
            version: version,
            description: description,
            date: build_date,
            revision: build_hash
          })
          |> Map.put(:runtime, System.build_info())
          |> Jason.encode!()

        conn |> put_resp_content_type("application/json") |> send_resp(200, data) |> halt()

      _ ->
        conn
    end
  end

  def static_headers(conn) do
    case conn.request_path do
      "/assets/serviceworker.js" -> [{"Service-Worker-Allowed", "/"}]
      _ -> []
    end
  end

  #  def content_security_policy(conn, _opts) do
  #    [_, url_host] = String.split(CraftplanWeb.Endpoint.url(), "://", parts: 2)
  #
  #     ContentSecurityPolicy.Plug.Setup.call(conn,
  #      default_policy: %ContentSecurityPolicy.Policy{
  #        default_src: ["'self'"],
  #        script_src: ["'self'"],
  #        connect_src: ["'self'", "wss:"],
  #        style_src: ["'self'", "'unsafe-inline'"],
  #        img_src: ["'self'", "data:"],
  #        font_src: ["'self'"],
  #        form_action: [
  #          "'self'",
  #          # Allow directing to subdomains
  #          "*.#{url_host}"
  #        ],
  #        frame_ancestors: ["'none'"]
  #      }
  #    )
  #  end
end
