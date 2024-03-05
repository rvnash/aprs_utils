defmodule Balloons.Utils.AprsIsTest do
  use ExUnit.Case
  alias APRSUtils.AprsIs
  alias APRSUtils.AprsParser

  test "start_link/1 starts the GenServer" do
    {:ok, pid} =
      AprsIs.start_link(
        host: "noam.aprs2.net",
        port: 14580,
        username: "KC3ARY",
        password: "22969",
        app_name: "Balloons",
        app_version: "0.1",
        filter: "t/poimqstunw",
        client_module: Client
      )

    assert is_pid(pid)

    Process.sleep(50000)
  end
end

defmodule Client do
  alias APRSUtils.AprsParser
  @behaviour APRSUtilsIsClient
  def got_packet(packet) do
    IO.puts("Got packet #{String.replace_invalid(packet)}")
    IO.puts(inspect(AprsParser.parse(packet), label: "Packet", pretty: true))
    :ok
  end

  def got_comment(str) do
    IO.puts("Got comment: #{String.replace_invalid(str)}")
    :ok
  end

  def got_error(reason) do
    IO.puts("Got error: #{reason}")
    :ok
  end

  def connected do
    IO.puts("Connected")
    :ok
  end

  def disconnected do
    IO.puts("Disconnected")
    :ok
  end
end
