defmodule APRSUtils.AprsIs do
  use GenServer

  # Implements the APRS-IS protocol: https://www.aprs-is.net/

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    genserver_pid = self()

    with {:ok, socket} <-
           :gen_tcp.connect(String.to_charlist(opts[:host]), opts[:port], [
             :binary,
             :inet,
             active: false,
             packet: :line
           ]),
         :ok <-
           :gen_tcp.send(
             socket,
             "user #{opts[:username]} pass #{opts[:password]} #{opts[:app_name]} #{opts[:app_version]} filter #{opts[:filter]}\r\n"
           ),
         {:ok, <<"# ", server_version::binary>>} <- :gen_tcp.recv(socket, 0),
         :ok <- opts[:client_module].connected(server_version),
         listener <- Process.spawn(fn -> listen(socket, genserver_pid) end, [:link]) do
      {:ok, %{socket: socket, listener: listener, client_module: opts[:client_module]}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  defp listen(socket, genserver_pid) do
    case :gen_tcp.recv(socket, 0) do
      {:error, :closed} ->
        GenServer.cast(genserver_pid, {:disconnected})

      {:error, reason} ->
        GenServer.cast(genserver_pid, {:error, reason})

      {:ok, data} ->
        GenServer.cast(genserver_pid, {:recieved, data})
    end

    listen(socket, genserver_pid)
  end

  @impl true
  def handle_cast({:recieved, <<"# ", str::binary>>}, state) do
    state.client_module.got_comment(String.trim(str))
    {:noreply, state}
  end

  def handle_cast({:recieved, packet}, state) do
    state.client_module.got_packet(String.trim(packet))
    {:noreply, state}
  end

  def handle_cast({:error, reason}, state) do
    state.client_module.got_error(reason)
    {:noreply, state}
  end

  def handle_cast({:disconnected}, state) do
    state.client_module.disconnected()
    {:noreply, state}
  end
end

defmodule APRSUtilsIsClient do
  @callback got_packet(binary()) :: :ok
  @callback connected(binary()) :: :ok
  @callback disconnected() :: :ok
  @callback got_comment(binary()) :: :ok
  @callback got_error(binary()) :: :ok
end
