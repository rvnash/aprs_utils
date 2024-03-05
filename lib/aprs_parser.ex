defmodule APRSUtils.AprsParser do
  @moduledoc """
  Module for parsing APRS strings into components.

  For reference:
    APRS 1.0.1 Spec: http://www.aprs.org/doc/APRS101.PDF
    APRS 1.1 Addendum: http://www.aprs.org/aprs11.html
    APRS 1.2 Addendum: http://www.aprs.org/aprs12.html

  """
  @enforce_keys [:raw, :from, :to, :path]
  defstruct raw: nil,
            # The AX.25 routing information
            to: nil,
            from: nil,
            path: [],
            # The 10 types of APRS data
            position: nil,
            direction_finding: nil,
            object: nil,
            item: nil,
            weather: nil,
            telemetry: nil,
            message: nil,
            queries: nil,
            responses: nil,
            status: nil,
            other: nil,
            comment: nil

  defp init_aprs,
    do: %__MODULE__{
      raw: nil,
      from: nil,
      to: nil,
      path: nil
    }

  @doc """
  Parses an APRS string into components.

  ## Examples


  """
  def parse(aprs_string) do
    try do
      {init_aprs(), aprs_string}
      |> get_raw()
      |> get_paths()
      |> parse_information_field()
      |> maybe_add_local_time()
      |> maybe_add_altitude_from_comment()
      |> maybe_add_base_91_telemetry_from_comment()
      |> maybe_add_dao_from_comment()
      |> then(&{:ok, elem(&1, 0)})
    catch
      {{aprs, msg}, error_string} -> {:error, throw_to_error_return({aprs, msg}, error_string)}
    end
  end

  @meters_per_mile 1609.344
  @meters_per_foot 0.3048
  @knots_to_meters_per_second 0.514444444
  @miles_per_hour_to_meters_per_second 0.44704
  @hundredths_of_inch_to_meters 0.000254
  @inch_to_meters 0.0254
  @feet_to_meters 0.3048
  @knots_to_meters_per_second 0.514444
  @nautical_miles_to_meters 1852.0

  # Grab the input into the raw field
  defp get_raw({aprs, aprs_string}) do
    {Map.put(aprs, :raw, aprs_string), aprs_string}
  end

  @regexs [
    ~r/(.{1,9}?)>(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?):(.*)/,
    ~r/(.{1,9}?)>(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?):(.*)/,
    ~r/(.{1,9}?)>(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?):(.*)/,
    ~r/(.{1,9}?)>(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?):(.*)/,
    ~r/(.{1,9}?)>(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?):(.*)/,
    ~r/(.{1,9}?)>(.{1,9}?),(.{1,9}?),(.{1,9}?),(.{1,9}?):(.*)/,
    ~r/(.{1,9}?)>(.{1,9}?),(.{1,9}?),(.{1,9}?):(.*)/,
    ~r/(.{1,9}?)>(.{1,9}?),(.{1,9}?):(.*)/,
    ~r/(.{1,9}?)>(.{1,9}?):(.*)/
  ]
  # Extract the FROM/TO/PATH, See chapter 4 page 13 of http://www.aprs.org/doc/APRS101.PDF
  defp get_paths({aprs, aprs_string}) do
    case Enum.reduce_while(@regexs, {aprs, aprs_string}, fn regex, {aprs, aprs_string} ->
           case Regex.run(regex, aprs_string) do
             nil ->
               {:cont, {aprs, aprs_string}}

             captures ->
               {_whole_match, captures} = List.pop_at(captures, 0)
               {from, captures} = List.pop_at(captures, 0)
               {to, captures} = List.pop_at(captures, 0)
               {ax25_information, path} = List.pop_at(captures, -1)
               {:halt, {%__MODULE__{aprs | from: from, to: to, path: path}, ax25_information}}
           end
         end) do
      {_aprs, ^aprs_string} ->
        throw({{aprs, aprs_string}, "Could not match the FROM/TO/PATH"})

      result ->
        result
    end
  end

  # Extract the Data Identifier from the Information field and fork using pattern matching
  # to the appropriate parsing function
  defp parse_information_field(
         {aprs, <<data_identifier::binary-size(1), msg::binary>> = _information_field}
       ) do
    parse_w_data_identifier({aprs, msg}, data_identifier)
  end

  # Position Reports - Without timestamp (Chapter 8 page 32 of http://www.aprs.org/doc/APRS101.PDF)
  defp parse_w_data_identifier(
         {aprs, <<first_byte::binary-size(1), _rest::binary>> = msg},
         data_identifier
       )
       when data_identifier in ["!", "="] do
    if first_byte in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] do
      parse_position_uncompressed({aprs, msg})
    else
      parse_position_compressed({aprs, msg})
    end
    |> parse_weather_data()
    |> parse_data_extension_15()
    |> parse_data_extension_7()
    |> extract_comment()
  end

  # Position Reports - With timestamp (Chapter 8 page 32 of http://www.aprs.org/doc/APRS101.PDF)
  defp parse_w_data_identifier(
         {aprs, <<time::binary-size(6), time_indicator::binary-size(1), rest::binary>> = _msg},
         data_identifier
       )
       when data_identifier in ["@", "/"] do
    {add_information(aprs, :position, %{
       timestamp: {parse_timestamp(time, time_indicator), :sender_time}
     }), rest}
    |> parse_w_data_identifier("!")
  end

  # Mic-E: Chapter 10 page 42 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_w_data_identifier({aprs, msg}, data_identifier)
       when data_identifier in ["'", "`", <<0x1C>>, <<0x1D>>] do
    {aprs, msg}
    |> parse_mic_e_data()
    |> extract_mic_e_device()
    |> maybe_extract_mic_e_altitude()
    |> extract_comment()
  end

  # Status Report: Chapter 16 page 80 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_w_data_identifier(arg, data_identifier) when data_identifier == ">" do
    parse_status_report(arg)
  end

  # Message: Chapter 14 page 71 of http://www.aprs.org/doc/APRS101.PDF
  # Could also contain a telemetry definition message: Chapter 13 page 68 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_w_data_identifier(arg, data_identifier) when data_identifier == ":" do
    parse_message(arg) |> check_for_telemetry_definition_message()
  end

  # Telemetry Report Format: Chapter 13 page 68 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_w_data_identifier(arg, data_identifier) when data_identifier == "T" do
    parse_telemetry_report(arg) |> extract_comment()
  end

  # Object reports: Chapter 11 page 57 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_w_data_identifier(
         {aprs, <<name::binary-size(9), object_state_indicator::binary-size(1), rest::binary>>},
         data_identifier
       )
       when data_identifier == ";" do
    {aprs
     |> add_information(:object, %{
       name: name,
       state:
         case object_state_indicator do
           "*" -> :alive
           "_" -> :killed
         end
     }), rest}
    |> parse_w_data_identifier("@")
  end

  # Item reports: Chapter 11 page 57 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_w_data_identifier({aprs, msg}, data_identifier) when data_identifier == ")" do
    case Regex.run(~r/(.{3,9}?)([!_])(.*)/, msg) do
      [_, name, state, rest] when name != "" and state in ["!", "_"] ->
        {aprs
         |> add_information(:item, %{
           name: name,
           state:
             case state do
               "!" -> :alive
               "_" -> :killed
             end
         }), rest}
        |> parse_w_data_identifier("!")

      _ ->
        throw({{aprs, msg}, "Could not parse the item format: #{msg}"})
    end
  end

  defp parse_w_data_identifier(p, data_identifier)
       when data_identifier in ["#", "$", "%", "(", "*", ",", "-", "<", "?", "[", "_"] do
    throw({p, "Unimplemented APRS Data Type Identifier: #{data_identifier}"})
  end

  # APRS Data Identifier not recognized
  defp parse_w_data_identifier(p, data_identifier) do
    throw(
      {p,
       "APRS Data Type Identifier is not in the spec. or is unused or reserved: #{data_identifier}"}
    )
  end

  defp parse_telemetry_report(
         {aprs,
          <<"#MIC,", ch_1::binary-size(3), ",", ch_2::binary-size(3), ",", ch_3::binary-size(3),
            ",", ch_4::binary-size(3), ",", ch_5::binary-size(3), ",",
            digital_value::binary-size(8), rest::binary>>}
       ) do
    {aprs |> add_telemetry_report(nil, ch_1, ch_2, ch_3, ch_4, ch_5, digital_value), rest}
  end

  defp parse_telemetry_report(
         {aprs,
          <<"#MIC", ch_1::binary-size(3), ",", ch_2::binary-size(3), ",", ch_3::binary-size(3),
            ",", ch_4::binary-size(3), ",", ch_5::binary-size(3), ",",
            digital_value::binary-size(8), rest::binary>>}
       ) do
    {aprs |> add_telemetry_report(nil, ch_1, ch_2, ch_3, ch_4, ch_5, digital_value), rest}
  end

  defp parse_telemetry_report(
         {aprs,
          <<"#", sequence_no::binary-size(3), ",", ch_1::binary-size(3), ",",
            ch_2::binary-size(3), ",", ch_3::binary-size(3), ",", ch_4::binary-size(3), ",",
            ch_5::binary-size(3), ",", digital_value::binary-size(8), rest::binary>>}
       ) do
    {aprs |> add_telemetry_report(sequence_no, ch_1, ch_2, ch_3, ch_4, ch_5, digital_value), rest}
  end

  defp parse_telemetry_report(arg), do: throw({arg, "Badly formatted telemetry report"})

  defp add_telemetry_report(
         aprs,
         sequence_no,
         ch_1,
         ch_2,
         ch_3,
         ch_4,
         ch_5,
         <<b0::binary-size(1), b1::binary-size(1), b2::binary-size(1), b3::binary-size(1),
           b4::binary-size(1), b5::binary-size(1), b6::binary-size(1), b7::binary-size(1)>>
       ) do
    telemetry = %{
      values: [
        to_numeric(ch_1),
        to_numeric(ch_2),
        to_numeric(ch_3),
        to_numeric(ch_4),
        to_numeric(ch_5)
      ],
      bits: [
        String.to_integer(b0),
        String.to_integer(b1),
        String.to_integer(b2),
        String.to_integer(b3),
        String.to_integer(b4),
        String.to_integer(b5),
        String.to_integer(b6),
        String.to_integer(b7)
      ]
    }

    telemetry =
      if sequence_no != nil,
        do: Map.put(telemetry, :sequence_counter, String.to_integer(sequence_no)),
        else: telemetry

    aprs
    |> add_information(:telemetry, telemetry)
  end

  # Message Acknowledgement: Chapter 14 page 72 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_message({aprs, <<addressee::binary-size(9), ":ack", message_no::binary>>}) do
    {aprs
     |> add_information(:message, %{
       addressee: addressee,
       message: "ack",
       message_no: String.to_integer(message_no)
     }), ""}
  end

  # Message Recjection: Chapter 14 page 72 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_message({aprs, <<addressee::binary-size(9), ":rej", message_no::binary>>}) do
    {aprs
     |> add_information(:message, %{
       addressee: addressee,
       message: "rej",
       message_no: String.to_integer(message_no)
     }), ""}
  end

  # Extract Message Number: Chapter 14 page 71 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_message({aprs, <<addressee::binary-size(9), ":", rest::binary>>}) do
    case Regex.run(~r/(.*?){(.*)/, rest) do
      [_, message_text, message_no] ->
        {aprs
         |> add_information(:message, %{
           addressee: addressee,
           message: message_text,
           message_no: String.to_integer(message_no)
         }), ""}

      _ ->
        {aprs
         |> add_information(:message, %{
           addressee: addressee,
           message: rest
         }), ""}
    end
  end

  defp parse_message(p), do: throw({p, "Addressee must be 9 characters followed by a ':'"})

  # Message to the originator may be a telemetry definition message
  # Chapter 13 page 68 of http://www.aprs.org/doc/APRS101.PDF
  defp check_for_telemetry_definition_message(
         {%__MODULE__{message: %{addressee: addressee, message: message}} = aprs, msg}
       ) do
    if aprs.from == String.trim(addressee) do
      {aprs, msg} |> parse_telemetry_definition_message(message)
    else
      {aprs, msg}
    end
  end

  # PARA, UNIT, EQNS, BITS.: Chapter 13 page 70 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_telemetry_definition_message({aprs, _msg}, <<"PARM.", list::binary>>) do
    {%__MODULE__{
       aprs
       | message: nil,
         telemetry: %{parm: parse_comma_separated_binary(list), to: aprs.from}
     }, ""}
  end

  defp parse_telemetry_definition_message({aprs, _msg}, <<"UNIT.", list::binary>>) do
    {%__MODULE__{
       aprs
       | message: nil,
         telemetry: %{unit: parse_comma_separated_binary(list), to: aprs.from}
     }, ""}
  end

  defp parse_telemetry_definition_message({aprs, msg}, <<"BITS.", bits::binary>>) do
    case Regex.run(~r/([01]*),(.*)/, bits) do
      [_, bits, project_title] when bits != "" ->
        {%__MODULE__{
           aprs
           | message: nil,
             telemetry: %{
               bits: String.split(bits, "", trim: true) |> Enum.map(&String.to_integer/1),
               project_title: project_title,
               to: aprs.from
             }
         }, ""}

      _ ->
        throw({{aprs, msg}, "Badly formatted BITS message"})
    end
  end

  defp parse_telemetry_definition_message({aprs, _msg}, <<"EQNS.", list::binary>>) do
    {%__MODULE__{
       aprs
       | message: nil,
         telemetry: %{
           eqns: parse_comma_separated_binary(list) |> Enum.map(&to_float/1) |> group_list(3),
           to: aprs.from
         }
     }, ""}
  end

  defp parse_telemetry_definition_message({aprs, msg}, _) do
    {aprs, msg}
  end

  defp group_list(l, n) do
    case Enum.split(l, n) do
      {a, []} -> [a]
      {a, b} -> [a | group_list(b, n)]
    end
  end

  defp parse_status_report({aprs, <<dhm::binary-size(6), "z", msg::binary>>}) do
    {%__MODULE__{aprs | status: msg}
     |> add_information(:position, %{
       timestamp: {parse_timestamp(dhm, "z"), :sender_time}
     }), ""}
  end

  defp parse_status_report(
         {aprs,
          <<major_gg::binary-size(2), nn::binary-size(2), symbol_table_id::binary-size(1),
            symbol_code::binary-size(1)>>}
       ) do
    {%__MODULE__{aprs | status: ""}
     |> add_information(:position, %{
       maidenhead: major_gg <> nn,
       symbol: symbol_table_id <> symbol_code
     }), ""}
  end

  defp parse_status_report(
         {aprs,
          <<major_gg::binary-size(2), nn::binary-size(2), gg::binary-size(2),
            symbol_table_id::binary-size(1), symbol_code::binary-size(1), " ", msg::binary>>}
       ) do
    {%__MODULE__{aprs | status: msg}
     |> add_information(:position, %{
       maidenhead: major_gg <> nn <> gg,
       symbol: symbol_table_id <> symbol_code
     }), ""}
  end

  defp parse_status_report({aprs, msg}) do
    {%__MODULE__{aprs | status: msg}, ""}
  end

  @mic_e_byte_decode_table %{
    "0" => %{lat: 0, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "1" => %{lat: 1, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "2" => %{lat: 2, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "3" => %{lat: 3, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "4" => %{lat: 4, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "5" => %{lat: 5, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "6" => %{lat: 6, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "7" => %{lat: 7, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "8" => %{lat: 8, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "9" => %{lat: 9, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "A" => %{lat: 0, bit: 1, custom?: true},
    "B" => %{lat: 1, bit: 1, custom?: true},
    "C" => %{lat: 2, bit: 1, custom?: true},
    "D" => %{lat: 3, bit: 1, custom?: true},
    "E" => %{lat: 4, bit: 1, custom?: true},
    "F" => %{lat: 5, bit: 1, custom?: true},
    "G" => %{lat: 6, bit: 1, custom?: true},
    "H" => %{lat: 7, bit: 1, custom?: true},
    "I" => %{lat: 8, bit: 1, custom?: true},
    "J" => %{lat: 9, bit: 1, custom?: true},
    "K" => %{lat: 0, bit: 1, custom?: true},
    "L" => %{lat: 0, bit: 0, custom?: false, n_s: :south, long_offset: 0, w_e: :east},
    "P" => %{lat: 0, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west},
    "Q" => %{lat: 1, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west},
    "R" => %{lat: 2, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west},
    "S" => %{lat: 3, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west},
    "T" => %{lat: 4, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west},
    "U" => %{lat: 5, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west},
    "V" => %{lat: 6, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west},
    "W" => %{lat: 7, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west},
    "X" => %{lat: 8, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west},
    "Y" => %{lat: 9, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west},
    "Z" => %{lat: 0, bit: 1, custom?: false, n_s: :north, long_offset: 100, w_e: :west}
  }

  @mic_e_msgs %{
    {:std, 0} => "Off Duty",
    {:std, 1} => "En Route",
    {:std, 2} => "In Service",
    {:std, 3} => "Returning",
    {:std, 4} => "Committed",
    {:std, 5} => "Special",
    {:std, 6} => "Priority",
    {:std, 7} => "Emergency",
    {:custom, 0} => "Custom-0",
    {:custom, 1} => "Custom-1",
    {:custom, 2} => "Custom-2",
    {:custom, 3} => "Custom-3",
    {:custom, 4} => "Custom-4",
    {:custom, 5} => "Custom-5",
    {:custom, 6} => "Custom-6",
    {:custom, 7} => "Custom Emergency"
  }

  # Altitiude in the Mic-E status message: Page 55, Chapter 10 of http://www.aprs.org/doc/APRS101.PDF
  def maybe_extract_mic_e_altitude({aprs, <<altitude::binary-size(3), "}", rest::binary>> = _msg}) do
    {add_information(aprs, :position, %{
       altitude: decode_base91_ascii_string(altitude) - 10000.0
     }), rest}
  end

  def maybe_extract_mic_e_altitude(p), do: p

  # Extract the Mic-E device type: See http://www.aprs.org/aprs12/mic-e-types.txt
  defp extract_mic_e_device({aprs, <<" ", rest::binary>> = _msg}) do
    {add_information(aprs, :other, %{device: "Original Mic-E"}), rest}
  end

  defp extract_mic_e_device({aprs, <<">", rest::binary>> = _msg}) do
    case String.last(rest) do
      "=" ->
        {add_information(aprs, :other, %{device: "Kenwood TH-D72"}),
         String.slice(rest, 0, String.length(rest) - 1)}

      "^" ->
        {add_information(aprs, :other, %{device: "Kenwood TH-D74"}),
         String.slice(rest, 0, String.length(rest) - 1)}

      _ ->
        {add_information(aprs, :other, %{device: "Kenwood TH-D7A"}), rest}
    end
  end

  defp extract_mic_e_device({aprs, <<"]", rest::binary>> = _msg}) do
    case String.last(rest) do
      "=" ->
        {add_information(aprs, :other, %{device: "Kenwood TM-D710"}),
         String.slice(rest, 0, String.length(rest) - 1)}

      _ ->
        {add_information(aprs, :other, %{device: "Kenwood TH-D700"}), rest}
    end
  end

  defp extract_mic_e_device({aprs, <<"`", rest::binary>> = _msg}) do
    case String.slice(rest, -2, 2) do
      "_ " ->
        {add_information(aprs, :other, %{device: "Yaesu VX-8"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "_\=" ->
        {add_information(aprs, :other, %{device: "Yaesu FTM-350"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "_#" ->
        {add_information(aprs, :other, %{device: "Yaesu VX-8G"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "_$" ->
        {add_information(aprs, :other, %{device: "Yaesu FT1D"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "_%" ->
        {add_information(aprs, :other, %{device: "Yaesu FTM-400DR"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "_)" ->
        {add_information(aprs, :other, %{device: "Yaesu FTM-100D"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "_(" ->
        {add_information(aprs, :other, %{device: "Yaesu FT2D"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "_0" ->
        {add_information(aprs, :other, %{device: "Yaesu FT3D"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "_3" ->
        {add_information(aprs, :other, %{device: "Yaesu FT5D"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "_1" ->
        {add_information(aprs, :other, %{device: "Yaesu FTM-300D"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      " X" ->
        {add_information(aprs, :other, %{device: "AP510"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "(5" ->
        {add_information(aprs, :other, %{device: "Anytone D578UV"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      _ ->
        {aprs, rest}
    end
  end

  defp extract_mic_e_device({aprs, <<"'", rest::binary>> = _msg}) do
    case String.slice(rest, -2, 2) do
      "(8" ->
        {add_information(aprs, :other, %{device: "Anytone D878UV"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "|3" ->
        {add_information(aprs, :other, %{device: "Byonics TinyTrack3"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "|4" ->
        {add_information(aprs, :other, %{device: "Byonics TinyTrack5"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      ":4" ->
        {add_information(aprs, :other, %{device: "SCS GmbH & Co. P4dragon DR-7400 modems"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      ":8" ->
        {add_information(aprs, :other, %{device: "SCS GmbH & Co. P4dragon DR-7800 modems"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      _ ->
        {aprs, rest}
    end
  end

  defp extract_mic_e_device({aprs, <<_::binary-size(1), rest::binary>> = _msg}) do
    case String.slice(rest, -2, 2) do
      "\\\\" <> v ->
        {add_information(aprs, :other, %{device: "Hamhud #{v}"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "/" <> v ->
        {add_information(aprs, :other, %{device: "Argent #{v}"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "^" <> v ->
        {add_information(aprs, :other, %{device: "HinzTec anyfrog #{v}"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "*" <> v ->
        {add_information(aprs, :other, %{device: "APOZxxx www.KissOK.dk Tracker #{v}"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      "~" <> v ->
        {add_information(aprs, :other, %{device: "OTHER #{v}"}),
         String.slice(rest, 0, String.length(rest) - 2)}

      _ ->
        {aprs, rest}
    end
  end

  defp parse_mic_e_data(
         {aprs,
          <<long_degrees::binary-size(1), long_minutes::binary-size(1),
            long_hundredths::binary-size(1), sp::binary-size(1), dc::binary-size(1),
            se::binary-size(1), symbol_code::binary-size(1), sym_table_id::binary-size(1),
            kenwood_extra_char::binary-size(1), rest::binary>> = _msg}
       ) do
    rest =
      if kenwood_extra_char != ">" or kenwood_extra_char != "]" do
        kenwood_extra_char <> rest
      else
        rest
      end

    {lat, long, speed, course, mic_e_message} =
      parse_mic_e(aprs.to, long_degrees, long_minutes, long_hundredths, sp, dc, se)

    {add_information(%__MODULE__{aprs | message: mic_e_message}, :position, %{
       latitude: {lat, :hundredth_minute},
       longitude: {long, :hundredth_minute},
       course: course,
       speed: speed,
       symbol: sym_table_id <> symbol_code
     }), rest}
  end

  defp parse_mic_e(
         <<b1::binary-size(1), b2::binary-size(1), b3::binary-size(1), b4::binary-size(1),
           b5::binary-size(1), b6::binary-size(1)>> = _to,
         long_degrees,
         long_minutes,
         long_hundredths,
         sp,
         dc,
         se
       ) do
    dec1 = Map.get(@mic_e_byte_decode_table, b1)
    dec2 = Map.get(@mic_e_byte_decode_table, b2)
    dec3 = Map.get(@mic_e_byte_decode_table, b3)
    dec4 = Map.get(@mic_e_byte_decode_table, b4)
    dec5 = Map.get(@mic_e_byte_decode_table, b5)
    dec6 = Map.get(@mic_e_byte_decode_table, b6)

    lat =
      dec1.lat * 10 + dec2.lat +
        (dec3.lat * 10.0 + dec4.lat + dec5.lat / 10.0 + dec6.lat / 100.0) / 60.0

    lat =
      case dec4.n_s do
        :south -> -lat
        :north -> lat
      end

    long_degrees = byte_val(long_degrees) - 28 + dec5.long_offset

    long_degrees =
      if long_degrees <= 189 and long_degrees >= 180 do
        long_degrees - 100
      else
        if long_degrees <= 199 and long_degrees >= 190 do
          long_degrees - 100
        else
          long_degrees
        end
      end

    long_minutes = byte_val(long_minutes) - 28
    long_minutes = if long_minutes >= 60, do: long_minutes - 60, else: long_minutes

    long_hundredths = byte_val(long_hundredths) - 28

    long = long_degrees + (long_minutes + long_hundredths / 100.0) / 60.0

    long =
      case dec6.w_e do
        :west -> -long
        :east -> long
      end

    msg_number = dec1.bit * 4 + dec2.bit * 2 + dec3.bit

    msg_type =
      case {dec1.custom?, dec2.custom?, dec3.custom?} do
        {true, true, true} -> :custom
        {false, false, false} -> :std
        _ -> :unknown
      end

    msg = Map.get(@mic_e_msgs, {msg_type, msg_number}, "Unknown")

    dc = byte_val(dc) - 28

    speed = byte_val(sp) - 28
    speed = if speed >= 80, do: speed - 80, else: speed
    speed = speed * 10 + div(dc, 10)
    speed = if speed >= 800, do: speed - 800, else: speed
    speed = speed * @knots_to_meters_per_second

    course = rem(dc, 10) * 100 + byte_val(se) - 28
    course = 1.0 * if course >= 400, do: course - 400, else: course

    {lat, long, speed, course, msg}
  end

  defp parse_position_uncompressed(
         {aprs,
          <<lat::binary-size(8), sym_table_id::binary-size(1), long::binary-size(9),
            symbol_code::binary-size(1), rest::binary>> = _msg}
       ) do
    {add_information(aprs, :position, %{
       latitude: parse_lat(lat),
       longitude: parse_long(long),
       symbol: sym_table_id <> symbol_code
     }), rest}
  end

  defp parse_position_compressed(
         {aprs,
          <<sym_table_id::binary-size(1), lat::binary-size(4), long::binary-size(4),
            symbol_code::binary-size(1), cs::binary-size(2), comp_type::binary-size(1),
            rest::binary>> = _msg}
       ) do
    {add_information(
       aprs,
       :position,
       %{
         latitude: uncompress_lat(lat),
         longitude: uncompress_long(long),
         symbol: sym_table_id <> symbol_code
       }
     )
     |> parse_cs(cs, comp_type), rest}
  end

  defp uncompress_lat(lat) do
    {90.0 - decode_base91_ascii_string(lat) / 380_926.0, :hundredth_minute}
  end

  defp uncompress_long(long) do
    {-180.0 + decode_base91_ascii_string(long) / 190_463.0, :hundredth_minute}
  end

  defp parse_cs(
         aprs,
         cs,
         <<_::1, _::1, _::1, 1::1, 0::1, _::1, _::1, _::1>> = _comp_type
       ) do
    # Compressed Altitude
    altitude = Float.pow(1.002, decode_base91_ascii_string(cs)) * @meters_per_foot

    add_information(aprs, :position, %{
      altitude: altitude
    })
  end

  defp parse_cs(aprs, <<c::binary-size(1), s::binary-size(1)>> = _cs, _comp_type) when c != " " do
    case String.to_charlist(c) do
      [c] when c >= 33 and c <= 122 ->
        # Course/Speed (c between ! and z inclusive)
        [s] = String.to_charlist(s)

        add_information(aprs, :position, %{
          course: (c - 33) * 4.0,
          speed: (Float.pow(1.08, s - 33) - 1.0) * @knots_to_meters_per_second
        })

      [c] when c == 123 ->
        # Pre-Calculated Radio Range (c equals { )
        [s] = String.to_charlist(s)

        add_information(aprs, :position, %{
          range: 2.0 * Float.pow(1.08, s - 33) * @meters_per_mile
        })

      _ ->
        aprs
    end
  end

  defp parse_cs(aprs, _cs, _comp_type), do: aprs

  defp parse_weather_data(
         {%__MODULE__{position: %{symbol: symbol, course: course, speed: speed}} = aprs, msg}
       )
       when symbol in ["/_"] do
    {add_information(
       %__MODULE__{aprs | position: aprs.position |> Map.drop([:course, :speed])},
       :weather,
       %{
         wind_speed: speed,
         wind_direction: course
       }
     ), msg}
    |> add_weather_parameters()
  end

  defp parse_weather_data(
         {%__MODULE__{position: %{symbol: symbol}} = aprs,
          <<wind_direction::binary-size(3), "/", wind_speed::binary-size(3), rest::binary>> = _msg}
       )
       when symbol in ["/_"] do
    {aprs, rest}
    |> add_wind_direction(wind_direction)
    |> add_wind_speed(wind_speed)
    |> add_weather_parameters()
  end

  defp parse_weather_data(p), do: p

  def add_wind_direction({aprs, rest}, wind_direction) when wind_direction in ["...", "   "] do
    {aprs, rest}
  end

  def add_wind_direction({aprs, rest}, wind_direction) do
    {add_information(aprs, :weather, %{
       wind_direction: to_float(wind_direction)
     }), rest}
  end

  def add_wind_speed({aprs, rest}, wind_speed) when wind_speed in ["...", "   "] do
    {aprs, rest}
  end

  def add_wind_speed({aprs, rest}, wind_speed) do
    {add_information(aprs, :weather, %{
       wind_speed: to_float(wind_speed)
     }), rest}
  end

  defp add_weather_parameters({aprs, <<param_code::binary-size(1), rest::binary>>})
       when param_code in [
              "g",
              "t",
              "r",
              "p",
              "P",
              "h",
              "b",
              "L",
              "l",
              "s",
              "#",
              "F",
              "f",
              "^",
              ">",
              "&",
              "%",
              "/"
            ] do
    {new_aprs, new_rest} =
      case param_code do
        "g" ->
          add_weather({aprs, rest}, :gust_speed, 3, @miles_per_hour_to_meters_per_second)

        "t" ->
          add_weather({aprs, rest}, :temperature, 3, &fahrenheit_to_celsius/1)

        "r" ->
          add_weather({aprs, rest}, :rainfall_last_hour, 3, @hundredths_of_inch_to_meters)

        "p" ->
          add_weather({aprs, rest}, :rainfall_last_24_hours, 3, @hundredths_of_inch_to_meters)

        "P" ->
          add_weather({aprs, rest}, :rainfall_since_midnight, 3, @hundredths_of_inch_to_meters)

        "h" ->
          add_weather({aprs, rest}, :humidity, 2, 1.0)

        "b" ->
          add_weather({aprs, rest}, :barometric_pressure, 5, 0.1)

        "L" ->
          add_weather({aprs, rest}, :luminosity, 3, 1.0)

        "l" ->
          add_weather({aprs, rest}, :luminosity, 3, 1000.0)

        "s" ->
          add_weather({aprs, rest}, :snowfall, 3, @inch_to_meters)

        "#" ->
          add_weather({aprs, rest}, :rain_counts, 3, 1.0)

        "F" ->
          add_weather({aprs, rest}, :water_height, 3, @feet_to_meters)

        "f" ->
          add_weather({aprs, rest}, :water_height, 3, 1.0)

        "^" ->
          add_weather({aprs, rest}, :peak_wind_gust, 3, @knots_to_meters_per_second)

        ">" ->
          add_weather({aprs, rest}, :hurricane_winds_radius, 3, @nautical_miles_to_meters)

        "&" ->
          add_weather({aprs, rest}, :tropical_storm_winds_radius, 3, @nautical_miles_to_meters)

        "%" ->
          add_weather({aprs, rest}, :gale_force_winds_radius, 3, @nautical_miles_to_meters)

        "/" ->
          add_weather_hurricane({aprs, rest})
      end

    if new_rest == rest do
      {aprs, param_code <> rest}
    else
      add_weather_parameters({new_aprs, new_rest})
    end
  end

  defp add_weather_parameters({aprs, msg}) do
    # APRS Software Version and WX Unit: Chapter 12 page 63 of http://www.aprs.org/doc/APRS101.PDF
    if String.length(msg) <= 5 and String.length(msg) >= 3 do
      {add_information(aprs, :weather, %{device_type: msg}), ""}
    else
      {aprs, msg}
    end
  end

  defp add_weather_hurricane({aprs, <<"TS", rest::binary>>}) do
    {add_information(aprs, :weather, %{storm_category: :tropical_stopm}), rest}
    |> add_weather_parameters()
  end

  defp add_weather_hurricane({aprs, <<"HC", rest::binary>>}) do
    {add_information(aprs, :weather, %{storm_category: :hurricane}), rest}
    |> add_weather_parameters()
  end

  defp add_weather_hurricane({aprs, <<"TD", rest::binary>>}) do
    {add_information(aprs, :weather, %{storm_category: :tropical_depression}), rest}
    |> add_weather_parameters()
  end

  defp add_weather_hurricane({aprs, msg}), do: {aprs, msg}

  defp add_weather({aprs, rest}, key, size, factor_or_func) do
    size = min(size, String.length(rest))
    <<param::binary-size(size), new_rest::binary>> = rest

    if param == String.duplicate(".", size) or param == String.duplicate(" ", size) do
      {aprs, new_rest}
    else
      if not String.match?(param, ~r/^[\d.-]*$/) do
        {aprs, rest}
      else
        {add_information(aprs, :weather, %{key => convert(to_float(param), factor_or_func)}),
         new_rest}
      end
    end
  end

  @data_extension_course_speed_bearing_number_range_quality ~r/(\d{3})\/(\d{3})\/(\d{3})\/(\d{3})/
  # Handle 15 byte data extensions (Course/Speed/Bearing,Range/Number,Range,Quality), See Chapter 7 (pg. 30) of http://www.aprs.org/doc/APRS101.PDF
  defp parse_data_extension_15({aprs, <<data_extension::binary-size(15), comment::binary>> = msg}) do
    case Regex.run(@data_extension_course_speed_bearing_number_range_quality, data_extension) do
      [_, course, speed, bearing, nrq] ->
        <<number::binary-size(1), range::binary-size(1), quality::binary-size(1)>> = nrq
        add_df_report({aprs, comment}, course, speed, bearing, number, range, quality)

      nil ->
        {aprs, msg}
    end
  end

  defp parse_data_extension_15(info), do: info

  @data_extension_course_speed ~r/(\d{3})\/(\d{3})/
  @data_extension_phg ~r/PHG(\d)(.)(\d)(\d)/
  @data_extension_dfs ~r/DFS(\d)(.)(\d)(\d)/
  @data_extension_rng ~r/RNG(\d{4})/
  # Handle 7 byte data extensions (PHG, DFS, RNG, Course/Speed), See Chapter 7 (pg. 27) of http://www.aprs.org/doc/APRS101.PDF
  defp parse_data_extension_7({aprs, <<data_extension::binary-size(7), msg2::binary>> = msg}) do
    if p = Regex.run(@data_extension_course_speed, data_extension) do
      [_, course, speed] = p
      add_df_report({aprs, msg2}, course, speed)
    else
      if p = Regex.run(@data_extension_phg, data_extension) do
        [_, power_code, height_code, gain_code, directivity_code] = p
        add_phg_report({aprs, msg2}, power_code, height_code, gain_code, directivity_code)
      else
        if p = Regex.run(@data_extension_dfs, data_extension) do
          [_, strength_code, height_code, gain_code, directivity_code] = p
          add_dfs_report({aprs, msg2}, strength_code, height_code, gain_code, directivity_code)
        else
          if p = Regex.run(@data_extension_rng, data_extension) do
            [_, range] = p
            add_rng_report({aprs, msg2}, range)
          else
            {aprs, msg}
          end
        end
      end
    end
  end

  defp parse_data_extension_7(info), do: info

  defp add_df_report({aprs, msg}, course, speed) do
    {add_information(aprs, :position, %{
       course: to_float(course),
       speed: to_float(speed) * @knots_to_meters_per_second
     }), msg}
  end

  defp add_df_report({aprs, msg}, course, speed, bearing, number, range, quality) do
    {add_information(aprs, :position, %{
       course: to_float(course),
       speed: to_float(speed) * @knots_to_meters_per_second,
       bearing: to_float(bearing),
       N: Integer.parse(number) |> elem(0),
       range: Float.pow(2.0, to_float(range)) * @meters_per_mile,
       bearing_accuracy:
         case quality do
           "0" -> :useless
           "1" -> :less_240
           "2" -> :less_120
           "3" -> :less_64
           "4" -> :less_32
           "5" -> :less_16
           "6" -> :less_8
           "7" -> :less_4
           "8" -> :less_2
           "9" -> :less_1
           _ -> :useless
         end
     }), msg}
  end

  defp add_phg_report({aprs, msg}, power_code, height_code, gain_code, directivity_code) do
    {add_information(aprs, :position, %{
       power:
         case power_code do
           "0" -> 0.0
           "1" -> 1.0
           "2" -> 4.0
           "3" -> 9.0
           "4" -> 16.0
           "5" -> 25.0
           "6" -> 36.0
           "7" -> 49.0
           "8" -> 64.0
           "9" -> 81.0
           _ -> throw({{aprs, msg}, "power_code #{power_code} unknown"})
         end
     }), msg}
    |> add_hgd_to_report(height_code, gain_code, directivity_code)
  end

  defp add_dfs_report({aprs, msg}, strength_code, height_code, gain_code, directivity_code) do
    {add_information(aprs, :position, %{
       strength: to_float(strength_code)
     }), msg}
    |> add_hgd_to_report(height_code, gain_code, directivity_code)
  end

  defp add_hgd_to_report({aprs, msg}, height_code, gain_code, directivity_code) do
    {add_information(aprs, :position, %{
       height:
         case height_code do
           "0" -> 10.0
           "1" -> 20.0
           "2" -> 40.0
           "3" -> 80.0
           "4" -> 160.0
           "5" -> 320.0
           "6" -> 640.0
           "7" -> 1280.0
           "8" -> 2560.0
           "9" -> 5120.0
           ":" -> 10240.0
           ";" -> 20480.0
           "<" -> 40960.0
           "=" -> 81920.0
           ">" -> 163_840.0
           _ -> throw({{aprs, msg}, "Height code #{height_code} unknown"})
         end * @meters_per_foot,
       gain: to_float(gain_code),
       directivity:
         case directivity_code do
           "0" -> :omnidirectional
           "1" -> 45.0
           "2" -> 90.0
           "3" -> 135.0
           "4" -> 180.0
           "5" -> 225.0
           "6" -> 270.0
           "7" -> 315.0
           "8" -> 360.0
           _ -> throw({{aprs, msg}, "Directivity code #{directivity_code} unknown"})
         end
     }), msg}
  end

  defp add_rng_report({aprs, msg}, range) do
    {add_information(aprs, :position, %{
       range: to_float(range) * @meters_per_mile
     }), msg}
  end

  defp extract_comment({aprs, msg}) do
    {Map.put(aprs, :comment, msg), ""}
  end

  # If parsing didn't come up w/ a timestamp for this message, add the local time
  # in case the client wants to use it
  defp maybe_add_local_time({aprs, msg}) do
    if aprs.position != nil and Map.has_key?(aprs.position, :timestamp) do
      {aprs, msg}
    else
      {add_information(aprs, :position, %{
         timestamp: {NaiveDateTime.local_now(), :receiver_time}
       }), msg}
    end
  end

  # See Altitude in the comment text: Chapter 6 pg 26 of http://www.aprs.org/doc/APRS101.PDF
  # Note this does not extract the altitude from the comment, it only adds it to the position
  defp maybe_add_altitude_from_comment({%__MODULE__{comment: nil} = aprs, msg}), do: {aprs, msg}

  defp maybe_add_altitude_from_comment({%__MODULE__{comment: comment} = aprs, msg}) do
    case Regex.run(~r/.*A=(\d{6})/, comment) do
      [_, altitude] ->
        {add_information(aprs, :position, %{altitude: to_float(altitude) * @meters_per_foot}),
         msg}

      _ ->
        {aprs, msg}
    end
  end

  defp maybe_add_altitude_from_comment(p), do: p

  # See Base91 encoded telemetry in the comment text: http://he.fi/doc/aprs-base91-comment-telemetry.txt
  # Note, this removes the telemetry from the comment
  defp maybe_add_base_91_telemetry_from_comment({%__MODULE__{comment: nil} = aprs, msg}),
    do: {aprs, msg}

  @base91_telemetry_regex [
    ~r/(.*?)\|(.{12})\|(.*)/,
    ~r/(.*?)\|(.{10})\|(.*)/,
    ~r/(.*?)\|(.{8})\|(.*)/,
    ~r/(.*?)\|(.{6})\|(.*)/,
    ~r/(.*?)\|(.{4})\|(.*)/
  ]
  defp maybe_add_base_91_telemetry_from_comment({%__MODULE__{comment: comment} = aprs, msg}) do
    Enum.reduce_while(@base91_telemetry_regex, {aprs, msg}, fn regex, {aprs, msg} ->
      case Regex.run(regex, comment) do
        [_, pre, telemetry, post] when telemetry != "" ->
          {:halt,
           {add_information(
              %__MODULE__{aprs | comment: String.trim(pre <> post)},
              :telemetry,
              extract_base91_telemetry(telemetry)
            ), msg}}

        _ ->
          {:cont, {aprs, msg}}
      end
    end)
  end

  defp maybe_add_base_91_telemetry_from_comment(p), do: p

  defp extract_base91_telemetry(telemetry) do
    %{
      sequence_counter: decode_base91_ascii_string(String.slice(telemetry, 0, 2)),
      values: get_base91_channels(String.slice(telemetry, 2, String.length(telemetry)))
    }
  end

  defp get_base91_channels(telemetry) do
    for i <- 0..(String.length(telemetry) - 1)//2 do
      decode_base91_ascii_string(String.slice(telemetry, i, 2))
    end
  end

  # See DAO comments in http://he.fi/doc/aprs-base91-comment-telemetry.txt
  # This is unimplemented, it just strips it out
  defp maybe_add_dao_from_comment({%__MODULE__{comment: nil} = aprs, msg}), do: {aprs, msg}

  defp maybe_add_dao_from_comment({%__MODULE__{comment: comment} = aprs, msg}) do
    case Regex.run(~r/(.*?)!(.)(.)(.)!(.*)/, comment) do
      [_, pre, d, a, o, post] when d != "" and a != "" and o != "" ->
        {%__MODULE__{aprs | comment: String.trim(pre <> post)}, msg}

      _ ->
        {aprs, msg}
    end
  end

  defp maybe_add_dao_from_comment({aprs, msg}), do: {aprs, msg}

  defp parse_lat(lat) do
    <<lat::binary-size(7), direction::binary-size(1)>> = lat

    {<<degrees::binary-size(2), minutes::binary-size(5)>>, precision} =
      case String.split(lat, " ", parts: 2) do
        [<<_::binary-size(2)>> = l, _] -> {l <> "00.00", :degree}
        [<<_::binary-size(3)>> = l, _] -> {l <> "0.00", :tenth_degree}
        [<<_::binary-size(5)>> = l, _] -> {l <> "00", :minute}
        [<<_::binary-size(6)>> = l, _] -> {l <> "0", :tenth_minute}
        [_] -> {lat, :hundredth_minute}
        _ -> throw({{nil, nil}, "Could not parse latitude #{lat}"})
      end

    latitude =
      to_float(String.trim(degrees)) + to_float(String.trim(minutes)) / 60.0

    latitude =
      case direction do
        "N" -> latitude
        "S" -> -latitude
      end

    {latitude, precision}
  end

  defp parse_long(long) do
    <<long::binary-size(8), direction::binary-size(1)>> = long

    {<<degrees::binary-size(3), minutes::binary-size(5)>>, precision} =
      case String.split(long, " ", parts: 2) do
        [<<_::binary-size(3)>> = l, _] -> {l <> "00.00", :degree}
        [<<_::binary-size(4)>> = l, _] -> {l <> "0.00", :tenth_degree}
        [<<_::binary-size(6)>> = l, _] -> {l <> "00", :minute}
        [<<_::binary-size(7)>> = l, _] -> {l <> "0", :tenth_minute}
        [_] -> {long, :hundredth_minute}
        _ -> throw({{nil, nil}, "Could not parse longitude #{long}"})
      end

    longitude =
      to_float(String.trim(degrees)) + to_float(String.trim(minutes)) / 60.0

    longitude =
      case direction do
        "E" -> longitude
        "W" -> -longitude
      end

    {longitude, precision}
  end

  # DHM - Zulu time
  defp parse_timestamp(
         <<day::binary-size(2), hour::binary-size(2), minute::binary-size(2)>>,
         time_indicator
       )
       when time_indicator in ["z"] do
    now = NaiveDateTime.utc_now()

    NaiveDateTime.new(
      now.year,
      now.month,
      String.to_integer(day),
      String.to_integer(hour),
      String.to_integer(minute),
      0,
      0
    )
    |> elem(1)
  end

  # DHM - Local time
  defp parse_timestamp(
         <<day::binary-size(2), hour::binary-size(2), minute::binary-size(2)>>,
         time_indicator
       )
       when time_indicator in ["/", "#"] do
    now = NaiveDateTime.local_now()

    NaiveDateTime.new(
      now.year,
      now.month,
      String.to_integer(day),
      String.to_integer(hour),
      String.to_integer(minute),
      0,
      0
    )
    |> elem(1)
  end

  # HMS - Zulu time
  defp parse_timestamp(
         <<hour::binary-size(2), minute::binary-size(2), second::binary-size(2)>>,
         time_indicator
       )
       when time_indicator in ["h"] do
    now = NaiveDateTime.utc_now()

    NaiveDateTime.new(
      now.year,
      now.month,
      now.day,
      String.to_integer(hour),
      String.to_integer(minute),
      String.to_integer(second),
      0
    )
    |> elem(1)
  end

  defp add_information(%__MODULE__{} = aprs, key, info) when is_atom(key) and is_map(info) do
    if Map.has_key?(aprs, key) and Map.get(aprs, key) != nil do
      Map.put(aprs, key, Map.merge(Map.get(aprs, key), info))
    else
      Map.put(aprs, key, info)
    end
  end

  defp decode_base91_ascii_string(base91) do
    base91
    |> String.to_charlist()
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {char, index}, acc ->
      acc + (char - 33) * Integer.pow(91, index)
    end)
  end

  #
  defp parse_comma_separated_binary(string) when is_binary(string),
    do: parse_comma_separated_binary([], string)

  defp parse_comma_separated_binary(l, string) do
    case Regex.run(~r/^(.*?),(.*)/, string) do
      [_, first, rest] ->
        parse_comma_separated_binary([first | l], rest)

      _ ->
        Enum.reverse([string | l])
    end
  end

  defp to_numeric(str) do
    case Integer.parse(str) do
      {num, _} -> num
      :error -> to_float(str)
    end
  end

  defp to_float(str), do: Float.parse(str) |> elem(0)

  defp byte_val(str) when is_binary(str), do: String.to_charlist(str) |> List.first()

  defp throw_to_error_return({aprs, msg_left}, error_message) do
    %{
      raw: aprs.raw,
      error_message: error_message,
      near_character_position: String.length(aprs.raw) - String.length(msg_left) - 1
    }
  end

  defp fahrenheit_to_celsius(fahrenheit), do: (fahrenheit - 32.0) * (5.0 / 9.0)
  defp convert(value, func) when is_function(func), do: func.(value)
  defp convert(value, factor) when is_float(factor), do: factor * value
end
