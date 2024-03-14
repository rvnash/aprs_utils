defmodule Utils.AprsIsTest do
  use ExUnit.Case
  alias APRSUtils.AprsIs
  alias APRSUtils.AprsParser

  test "Can connect and unconnect" do
    # user TESTER pass 12705 Balloons 0.1 filter t/poimqstunw
    {:ok, pid} =
      AprsIs.connect(
        username: "TESTER",
        password: "12705",
        app_name: "Balloons",
        app_version: "0.1",
        client_module: Client
      )

    assert AprsIs.is_connected?(pid)

    AprsIs.close(pid)
    refute AprsIs.is_connected?(pid)
  end

  @tag timeout: :infinity
  test "Open a connection and process live data for a few a while" do
    # Note this test just runs for a while printing out bad packets
    # and then stops. Feel free to disable it.
    {:ok, pid} =
      AprsIs.connect(
        username: "TESTER",
        password: "12705",
        app_name: "Balloons",
        app_version: "0.1",
        client_module: Client
      )

    assert AprsIs.is_connected?(pid)
    Process.sleep(60_000)
  end

  test "connect fails bad user name." do
    {:error, _reason} =
      AprsIs.connect(
        username: "TEST",
        password: "12705",
        app_name: "Balloons",
        app_version: "0.1"
      )
  end

  test "connect fails bad host" do
    {:error, _reason} =
      AprsIs.connect(
        host: "foo.foo.foo",
        username: "TESTER",
        password: "12705",
        app_name: "Balloons",
        app_version: "0.1",
        client_module: Client
      )
  end

  test "connect fails host not running service" do
    {:error, _reason} =
      AprsIs.connect(
        host: "www.apple.com",
        username: "TESTER",
        password: "12705",
        app_name: "Balloons",
        app_version: "0.1",
        client_module: Client
      )
  end

  test "connect fails bad password" do
    {:error, _reason} =
      AprsIs.connect(
        username: "TESTER",
        password: "12704",
        app_name: "Balloons",
        app_version: "0.1",
        client_module: Client
      )
  end
end

defmodule Client do
  @moduledoc false
  alias APRSUtils.AprsParser
  @behaviour APRSUtilsIsClient
  def got_packet(packet, packet_count) do
    try do
      case AprsParser.parse(packet) do
        {:ok, %AprsParser{} = _parsed} ->
          :ok

        {:error, reason} ->
          IO.puts(
            "\nError parsing packet (#{packet_count}): #{String.replace_invalid(reason.error_message)}"
          )

          IO.puts("Packet: #{String.replace_invalid(packet)}")
          puts_link(packet)
      end
    rescue
      e ->
        IO.puts(
          "\nException raised parsing packet (#{packet_count}): #{String.replace_invalid(packet)}"
        )

        puts_link(packet)
        reraise e, __STACKTRACE__
    end

    :ok
  end

  defp puts_link(packet) do
    case Regex.run(~r/^(.*?)>.*/, packet) do
      [_, call] ->
        IO.puts("Link: https://aprs.fi/?c=raw&call=#{call}&limit=25&view=normal")

      nil ->
        IO.puts("No call found in packet")
    end
  end

  def got_comment(str) do
    IO.puts("Got comment: #{String.replace_invalid(str)}")
    :ok
  end

  def disconnected(reason) do
    IO.puts("Disconnected: #{reason}")

    :ok
  end
end
