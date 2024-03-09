defmodule Balloons.Utils.AprsIsTest do
  use ExUnit.Case
  alias APRSUtils.AprsIs
  alias APRSUtils.AprsParser

  @tag timeout: :infinity
  test "start_link/1 starts the GenServer" do
    {:ok, pid} =
      AprsIs.start_link(
        host: "rotate.aprs.net",
        port: 14580,
        username: "KC3ARY",
        password: "22969",
        app_name: "Balloons",
        app_version: "0.1",
        filter: "t/poimqstunw",
        client_module: Client
      )

    assert is_pid(pid)

    Process.sleep(5_000_000)
  end
end

defmodule Client do
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

    # IO.puts(inspect(AprsParser.parse(packet), label: "Packet", pretty: true))
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

  def got_error(reason) do
    IO.puts("Got error: #{reason}")
    :ok
  end

  def connected(server_version) do
    IO.puts("Connected to server: #{server_version}")
    :ok
  end

  def disconnected do
    IO.puts("Disconnected")
    :ok
  end
end
