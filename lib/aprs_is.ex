defmodule APRSUtils.AprsIs do
  @moduledoc """
  A module to connect to an APRS-IS server and listen for packets.

  These functions implement a client for the APRS-IS server. To use this module, you must implement a
  client module that implements the APRSUtils.AprsIsClient behaviour. The client module will be called
  when packets are recieved from the APRS-IS server.

  ## Example

      defmodule Client do
        @behaviour APRSUtilsIsClient
        alias APRSUtils.AprsParser

        def got_packet(_aprs_is_pid, packet, packet_count) do
          IO.puts("Got packet: \#{String.replace_invalid(packet)}")
        end

        def got_comment(_aprs_is_pid, comment) do
          IO.puts("Got comment: \#{String.replace_invalid(comment)}")
        end

        def disconnected(_aprs_is_pid, reason) do
          IO.puts("Disconnected: \#{reason}")
        end
      end

      {:ok, aprs_is_pid} =
        AprsIs.connect(
          username: "my_call_sign",
          password: "my_aprs_is_password",
          app_name: "MyAppName",
          app_version: "0.1",
          client_module: Client
        )

  Note to connect to APRS-IS take a look at [Connecting to APRS-IS](http://www.aprs-is.net/Connecting.aspx). Also, please
  follow the [rules and guidelines](https://www.aprs-is.net/Default.aspx) for using APRS-IS.

  """

  @doc """
  Connects to the APRS-IS server and starts listening for packets.

  `opts` may contain the following fields:

  - :host - The hostname of the APRS-IS server. Defaults to "rotate.aprs.net".
  - :port - The port of the APRS-IS server. Defaults to 14580.
  - :username - The username (typically your CALLSIGN) to connect to the APRS-IS server.
  - :password - The password to connect to the APRS-IS server.
  - :app_name - The name of your application.
  - :app_version - The version of your application.
  - :filter - The [filter](https://www.aprs-is.net/javAPRSFilter.aspx) to use for the APRS-IS server. Defaults to "t/poimqstunw".
  - :client_module - The module that implements the APRSUtilsIsClient behaviour.

  All of the fields are required except for `:host`, `:port`, and `:filter` which have defaults.

  Returns `{:ok, pid}` if the connection is successful. The `pid` is the pid of the listener process that is spawned by a successful call.

  Returns `{:error, reason}` if the connection fails. `reason` is a binary describing the error.

  > Note that only one connection can be made to the APRS-IS server. It was intended that multiple connections could be made to the APRS-IS server, but this does
  > not work as of this release.

  """
  def connect(opts) do
    case validate_opts(opts) do
      {:ok,
       %{
         host: host,
         port: port,
         username: username,
         password: password,
         app_name: app_name,
         app_version: app_version,
         filter: filter,
         client_module: client_module
       }} ->
        start_server(host, port, username, password, app_name, app_version, filter, client_module)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns true if the APRS-IS server is connected, false otherwise. The `aprs_is_pid` is the pid returned by `connect`.
  """
  def is_connected?(aprs_is_pid) do
    Process.alive?(aprs_is_pid)
  end

  @doc """
  Closes the connection to the APRS-IS server. The `aprs_is_pid` is the pid returned by `connect`. Note that calling this does not
  cause a call to the `disconnected` callback in the client module.
  """
  def close(aprs_is_pid) do
    Process.exit(aprs_is_pid, :kill)
  end

  # Private functions

  defp validate_opts(opts) do
    {host, opts} = Keyword.pop(opts, :host, "rotate.aprs.net")
    {port, opts} = Keyword.pop(opts, :port, 14580)
    {username, opts} = Keyword.pop(opts, :username)
    {password, opts} = Keyword.pop(opts, :password)
    {app_name, opts} = Keyword.pop(opts, :app_name)
    {app_version, opts} = Keyword.pop(opts, :app_version)
    {filter, opts} = Keyword.pop(opts, :filter, "t/poimqstunw")
    {client_module, opts} = Keyword.pop(opts, :client_module)

    try do
      if opts != [], do: throw("Unknown options: #{inspect(opts)}")
      if username == nil, do: throw("Username is required")
      if password == nil, do: throw("Password is required")
      if app_name == nil, do: throw("App name is required")
      if app_version == nil, do: throw("App version is required")
      if client_module == nil, do: throw("Client module is required")

      {:ok,
       %{
         host: host,
         port: port,
         username: username,
         password: password,
         app_name: app_name,
         app_version: app_version,
         filter: filter,
         client_module: client_module
       }}
    catch
      reason -> {:error, reason}
    end
  end

  defp start_server(host, port, username, password, app_name, app_version, filter, client_module) do
    case :gen_tcp.connect(
           String.to_charlist(host),
           port,
           [
             :binary,
             :inet,
             active: false,
             packet: :line
           ],
           3000
         ) do
      {:ok, socket} ->
        with :ok <-
               :gen_tcp.send(
                 socket,
                 "user #{username} pass #{password} #{app_name} #{app_version} filter #{filter}\r\n"
               ),
             {:ok, <<"# ", _server_version::binary>>} <- :gen_tcp.recv(socket, 0, 3000),
             {:ok, login_response} <- :gen_tcp.recv(socket, 0, 3000),
             true <-
               (if String.starts_with?(login_response, "# logresp #{username} verified") do
                  true
                else
                  {:error, "username/password not recognized"}
                end) do
          listener = spawn(fn -> listen(socket, client_module) end)
          {:ok, listener}
        else
          {:error, reason} ->
            :gen_tcp.close(socket)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp listen(socket, client_module), do: listen(socket, client_module, 0)

  defp listen(socket, client_module, packet_count) do
    case :gen_tcp.recv(socket, 0) do
      {:error, reason} ->
        client_module.disconnected(reason)

      {:ok, data} ->
        got(data, client_module, packet_count + 1)
        listen(socket, client_module, packet_count + 1)
    end
  end

  defp got(<<"# ", str::binary>>, client_module, _packet_count) do
    client_module.got_comment(String.trim(str))
  end

  defp got(str, client_module, packet_count) do
    client_module.got_packet(String.trim(str), packet_count)
  end
end

defmodule APRSUtilsIsClient do
  @moduledoc """
  Callbacks for the APRSUtils.AprsIs client module
  """

  @doc """
  Called when a packet is recieved from the APRS-IS server. Note that `packet` is
  a binary, but not necessarily a valid `String`. `packet_count` is the number of packets
  recieved since the connection was established. The return value is ignored.
  """
  @callback got_packet(packet :: binary(), packet_count :: integer()) :: :ok

  @doc """
  Called when a comment is recieved from the APRS-IS server. Note that `comment` is
  a binary, but not necessarily a valid `String`. The return value is ignored.
  """
  @callback got_comment(comment :: binary()) :: :ok

  @doc """
  Called when the connection to the APRS-IS server is disconnected. `reason` is a term
  describing the reason for the disconnection. The return value is ignored.
  """
  @callback disconnected(reason :: term()) :: :ok
end
