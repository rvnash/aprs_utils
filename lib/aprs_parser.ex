defmodule AprsUtils.AprsParser do
  @moduledoc """
  Module for parsing APRS packets into components.

  ## Philosopy
  By its own admission, the APRS protocol is complex and shows definate signs of having
  a design which evolved and grew during it's development. This module is designed to abstract
  as much of this away as possible. It reveals only the actual information contained in the packet,
  and as little about the protocol as it can. For example, the module will not return any
  information about the type of packet, or if the positional information was compressed.
  Basically the structure that is returns contains the information the
  packet contains, and `nil` in the information fields that the packet does not contain.

  See this set of documents for the APRS protocol:

  * [APRS 1.0.1 Spec](http://www.aprs.org/doc/APRS101.PDF)
  * [APRS 1.1 Addendum](http://www.aprs.org/aprs11.html)
  * [APRS 1.2 Addendum](http://www.aprs.org/aprs12.html)

  ## Units
  For historical reasons, APRS uses a variety of units. This module will convert all units to this
  set of SI units.

  * latitude, longitude: degrees (float)
  * distance: meters (float)
  * speed: meters per second (float)
  * temperature: degrees Celsius (float)
  * pressure: pascals (float)
  * humidity: relative percent (float)

  ## Time handling
  Some, but not all, APRS packet formats contain timestamps. However all of the formats give only partial time information.
  One of the most common formats, for example, provides the day, hour, and minutes of transmission. It is the receiver's
  responsibility to provide the year and month. This can introduce incorrect interpretation of the time, especially if the
  time between transmission and parsing of the data is long. This module does not attempt to interpret the time, but
  simply returns the time information that is in the packet. Note that most, but not all, timestamp formats are Zulu Time.

  ## Caution on binary data
  Many of the fields described below are returned as binaries taken directly from the APRS packet. These binaries are not
  necessarily valid UTF-8 strings. In fact, it is common for APRS packets to contain non-printable characters, and non-UTF-8.
  If you attempt to use these for in an `iolist` for example, make sure you are prepared to handle non-UTF-8 binaries that
  fail `String.valid?/1`.

  ## Unsupported APRS Features

  This is the set of *Data Type Identifiers* which *are* supported (others will return `{:error, ...}` tuples).
  ``["!",  "=", "@", "/", "'", "`", <<\\x1c>>, <<\\x1d>>, ">", ":", "T", ";", ")", "$", "_" ]``

  This module does not support the "!DAO!" construct in the Mic-E format.

  This module does not recognize the software/device identifiers (APxxxx) in the TO field.


  """
  defstruct raw: nil,
            to: nil,
            from: nil,
            path: [],
            timestamp: nil,
            symbol: nil,
            position: nil,
            course: nil,
            antenna: nil,
            weather: nil,
            telemetry: nil,
            message: nil,
            status: nil,
            device: nil,
            object: nil,
            item: nil,
            raw_gps: nil,
            comment: nil

  # Because of the compile time nature of guards, this check is limitted to the first 9 characters
  @digits ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

  defguardp is_all_digits(term)
            when is_binary(term) and
                   binary_part(term, 0, 1) in @digits and
                   (byte_size(term) < 2 or binary_part(term, 1, 1) in @digits) and
                   (byte_size(term) < 3 or binary_part(term, 2, 1) in @digits) and
                   (byte_size(term) < 4 or binary_part(term, 3, 1) in @digits) and
                   (byte_size(term) < 5 or binary_part(term, 4, 1) in @digits) and
                   (byte_size(term) < 6 or binary_part(term, 5, 1) in @digits) and
                   (byte_size(term) < 7 or binary_part(term, 6, 1) in @digits) and
                   (byte_size(term) < 8 or binary_part(term, 7, 1) in @digits) and
                   (byte_size(term) < 9 or binary_part(term, 8, 1) in @digits) and
                   byte_size(term) < 10

  # Because of the compile time nature of guards, this check is limitted to the first 9 characters
  @float_chars ["-", "." | @digits]
  defguardp is_all_float(term)
            when is_binary(term) and
                   binary_part(term, 0, 1) in @float_chars and
                   (byte_size(term) < 2 or binary_part(term, 1, 1) in @float_chars) and
                   (byte_size(term) < 3 or binary_part(term, 2, 1) in @float_chars) and
                   (byte_size(term) < 4 or binary_part(term, 3, 1) in @float_chars) and
                   (byte_size(term) < 5 or binary_part(term, 4, 1) in @float_chars) and
                   (byte_size(term) < 6 or binary_part(term, 5, 1) in @float_chars) and
                   (byte_size(term) < 7 or binary_part(term, 6, 1) in @float_chars) and
                   (byte_size(term) < 8 or binary_part(term, 7, 1) in @float_chars) and
                   (byte_size(term) < 9 or binary_part(term, 8, 1) in @float_chars) and
                   byte_size(term) < 10

  defp fn_is_all_float(term), do: is_all_float(term)

  @doc """
  Parses an APRS string into components.

  ## Args

  - `aprs_packet` - The APRS packet to parse. Note that this is a binary, but is not necessarily a
  valid String. APRS packets can, and regularly do, contain non-printable characters, and non-UTF-8 sequences.

  ## Successful Returns
   `{:ok, %AprsUtils.AprsParser{}}`

   If an :ok is returned, the APRS packet has been successfully parsed into a struct. The struct contains the
   decoded components of the APRS packet. If the field of the struct is nil, then the packet did not contain
   that information.

   Here is how to interpret each field of the struct:

  | Field | Description |
  | ----- | ----------- |
  | `:raw` | The same binary passed in to the parse function. |
  | `:to` | A binary containing callsign of the station from which the packet is sent. |
  | `:from` | A binary often containing callsign of the station to which the packet is sent. Or, this can be used to encode other information found in the packet. |
  | `:path` | A list of binaries containing the callsigns of the digipeaters or other gateways that the packet has passed through. |
  | `:timestamp` | A map containting a set of the following fields: `:month`, `:day`, `:hour`, `:minute`, `:second`, and `timezone`. The fields are all integers, except for `:timezone`, which is either `:zulu` or `:local_to_sender`. |
  | `:symbol` | A two byte binary containing the symbol table and symbol represented in the packet. If you want to extract the bytes you can match `<<symbol_table::binary-size(1), symbol::binary-size(1)>>` |
  | `:position` | A map, see the table below for the fields. |
  | `:course` | A map, see the table below for the fields. |
  | `:antenna` | A map, see the table below for the fields. |
  | `:weather` | A map, see the table below for the fields. |
  | `:telemetry` | A map containing `:sequence_counter`, `:values`, and `:bits`. `:sequence_counter` is an integer used to order telemetry reports. `:values` and `:bits` are lists. The former contains numeric values, and the later is a sequence of either `1` or `0`. |
  | `:message` | Certain APRS packets are meant to be messages to a specific destination. In this case a message map is returned with the following fields: `:addressee`, `:message`, `:message_no` (which may be missing). `:message` is a textual message. `:message_no` is an integer message sequencer. |
  | `:status` | A binary which is the text from a packet containing a status report. Note, this is distinct from a message or a comment. |
  | `:device` | A binary containing the name of the sending device. This implementation is a bit weak in this area. |
  | `:object` | A map which define's an object which has the fields `:name` and `:state`. `:name` is a binary identifier, and `:state` is either `:killed` or `:alive`. |
  | `:item` | An item is just like an object (above) except that semantically it represents an inanimate thing that are occasionally posted on a map (e.g. marathon checkpoints or first-aid posts). |
  | `:raw_gps` | A binary. A packet can contain the raw GPS information in one of the popular GPS device formats, like an NMEA sentence. |
  | `:comment` | A binary comment on the packet. |


  | Position | |
  | -------- | ----------- |
  | `:latitude` | A tuple in the form `{degrees, precision}` where `degrees` is a float, and `precision` is one of `:hundredth_minute`, `:tenth_minute`, `:minute`, `:tenth_degree`, or `:degree` giving the approximate precision. |
  | `:longitude` | A tuple in the form `{degrees, precision}` where `degrees` is a float, and `precision` is one of `:hundredth_minute`, `:tenth_minute`, `:minute`, `:tenth_degree`, or `:degree` giving the approximate precision. |
  | `:maidenhead` | A string like `IO91SX`. This is given instead of latitude and longitude, but is considered obsolete. |
  | `:altitude` | A floating point number in meters. |

  | Course | |
  | ------ | ----------- |
  | `:direction` | A float in degrees. |
  | `:speed` | A float in meters per second. |
  | `:bearing` | A float in degrees. |
  | `:range` | A float in meters. |
  | `:report_quality` | An integer from 0 to 8 with 8 being the best, or `:manual`. |
  | `:bearing_accuracy` | An integer from 1 to 9 with 9 being the best, or `:useless`. See Chapter 7 of the APRS Spec. if you want to understand report quality and bearing accuracy better. |

  | Antenna | |
  | ------ | ----------- |
  | `:power` | A float in watts. |
  | `:strength` | An integer in S-points from 0 to 9. |
  | `:height` | A float in meters. |
  | `:directivity` | A float in degrees, or `:omnidirectional`. |

  | Weather | |
  | ------ | ----------- |
  | `:temperature` | A float in degrees celsius. |
  | `:wind_speed` | A float in meters per second. |
  | `:wind_direction` | A float in degrees. |
  | `:gust_speed` | A float in meters per second. |
  | `:barometric_pressure` | A float in pascals. |
  | `:humidity` | A float in percent. |
  | `:rainfall_last_hour` | A float in meters. |
  | `:rainfall_last_24_hours` | A float in meters. |
  | `:rainfall_since_midnight` | A float in meters. |
  | `:rain_counts` | A float in counts. |
  | `:luminosity` | A float in watts per square meter. |
  | `:snow_fall` | A float in meters. |
  | `:water_height` | A float in meters. |
  | `:peak_wind_gust` | A float in meters per second. |
  | `:hurricane_winds_radius` | A float in meters. |
  | `:tropical_storm_winds_radius` | A float in meters. |
  | `:gale_force_winds_radius` | A float in meters. |
  | `:software_type` | A binary. Together with `:wx_unit` are meant to describe the weather device reporting. This isn't robustly handled. |
  | `:wx_unit` | A binary. |

  ## Error Returns

  `{:error, Map.t()}`

  | Field |  |
  | ----- | ----------- |
  | `:raw` | The same binary passed in to the parse function. |
  | `:error` | A binary describing the error. |
  | `:near_character_position` | An integer indicating the position in the binary where the error was detected. |

  Note that for many type of errors `:near_character_position` will be nil.

  """

  def parse(aprs_packet) when is_binary(aprs_packet) do
    try do
      {%__MODULE__{}, aprs_packet}
      |> get_raw()
      |> get_from()
      |> get_to()
      |> get_paths()
      |> strip_server_generated_q_constructs()
      |> parse_information_field()
      |> maybe_add_altitude_from_comment()
      |> maybe_add_base_91_telemetry_from_comment()
      |> maybe_add_dao_from_comment()
      |> remove_empty_comment()
      |> validate_strings()
      |> then(&{:ok, elem(&1, 0)})
    catch
      {msg, error_string} -> {:error, throw_to_error_return(aprs_packet, msg, error_string)}
    end
  end

  defp remove_empty_comment({aprs, msg}) do
    if aprs.comment == "" do
      {aprs |> add_info(comment: nil), msg}
    else
      {aprs, msg}
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

  defp get_from({aprs, msg}) do
    case Regex.run(~r/^(.*?)>(.*)/, msg) do
      [_, from, rest] ->
        {add_info(aprs, from: from), rest}

      _ ->
        throw({msg, "Could not parse the FROM"})
    end
  end

  defp get_to({aprs, msg}) do
    case Regex.run(~r/^(.*?)([,:])(.*)/, msg) do
      [_, to, separator, rest] ->
        {add_info(aprs, to: to), separator <> rest}

      _ ->
        throw({msg, "Could not parse the TO"})
    end
  end

  # Extract the PATH, See chapter 4 page 13 of http://www.aprs.org/doc/APRS101.PDF
  defp get_paths({aprs, <<separator::binary-size(1), rest::binary>> = _msg})
       when separator == ":" do
    {add_info(aprs, path: []), rest}
  end

  defp get_paths({aprs, <<separator::binary-size(1), rest::binary>> = msg})
       when separator == "," do
    case parse_comma_separated_string(rest, fn c -> c != ":" end) do
      {path, <<_remove::binary-size(1), rest::binary>>} ->
        {add_info(aprs, path: path), rest}

      _ ->
        throw({msg, "Could not parse the PATH"})
    end
  end

  defp get_paths({_, msg}), do: throw({msg, "Could not parse the PATH"})

  # These are the Q constructs that are generated by the server and are not part of the APRS spec
  # https://www.aprs-is.net/q.aspx
  defp strip_server_generated_q_constructs({aprs, aprs_string}) do
    case Regex.run(~r/^(.*?)(,qA[CXUoSrR],[0-9A-Z\-]{1,8})$/, aprs_string) do
      [_, start, _q_construct] when start != "" ->
        {aprs, start}

      _ ->
        {aprs, aprs_string}
    end
  end

  # Extract the Data Identifier from the Information field and fork using pattern matching
  # to the appropriate parsing function
  defp parse_information_field(
         {aprs, <<data_identifier::binary-size(1), msg::binary>> = _information_field}
       ) do
    parse_w_data_identifier({aprs, msg}, data_identifier)
  end

  defp parse_information_field({_, msg}), do: throw({msg, "No Data Identifier found"})

  # Position Reports - Without timestamp (Chapter 8 page 32 of http://www.aprs.org/doc/APRS101.PDF)
  defp parse_w_data_identifier(
         {aprs, <<first_byte::binary-size(1), _rest::binary>> = msg},
         data_identifier
       )
       when data_identifier in ["!", "="] do
    if is_all_digits(first_byte) do
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
         {aprs, <<time::binary-size(6), time_indicator::binary-size(1), rest::binary>> = msg},
         data_identifier
       )
       when data_identifier in ["@", "/"] do
    if String.match?(time, ~r/^[\d]*$/) do
      {add_info(aprs, timestamp: parse_timestamp(time, time_indicator)), rest}
      |> parse_w_data_identifier("!")
    else
      throw({msg, "Timestamp contains non-digit characters: #{time}"})
    end
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
         {aprs,
          <<name::binary-size(9), object_state_indicator::binary-size(1), rest::binary>> = msg},
         data_identifier
       )
       when data_identifier == ";" do
    {aprs
     |> add_info(:object, %{
       name: name,
       state:
         case object_state_indicator do
           "*" ->
             :alive

           "_" ->
             :killed

           _ ->
             throw({msg, "Object state indicator not recognized: #{object_state_indicator}"})
         end
     }), rest}
    |> parse_w_data_identifier("@")
  end

  # Item reports: Chapter 11 page 57 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_w_data_identifier({aprs, msg}, data_identifier) when data_identifier == ")" do
    case Regex.run(~r/(.{3,9}?)([!_])(.*)/, msg) do
      [_, name, state, rest] when name != "" and state in ["!", "_"] ->
        {aprs
         |> add_info(:item, %{
           name: name,
           state:
             case state do
               "!" ->
                 :alive

               "_" ->
                 :killed
             end
         }), rest}
        |> parse_w_data_identifier("!")

      _ ->
        throw({msg, "Could not parse the item format: #{msg}"})
    end
  end

  # Raw GPS data, not really detailed in the spec, I assume the client
  # is supposed to know what to do with it.
  defp parse_w_data_identifier({aprs, msg}, data_identifier) when data_identifier in ["$"] do
    {aprs |> add_info(raw_gps: msg), ""}
  end

  # Positionless Weather Report: Chapter 12 page 63 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_w_data_identifier(p, data_identifier) when data_identifier in ["_"] do
    parse_positionless_weather_report(p)
    |> extract_comment()
  end

  defp parse_w_data_identifier({_, msg}, data_identifier)
       when data_identifier in ["#", "%", "(", "*", ",", "-", "<", "?", "["] do
    throw({msg, "Unimplemented APRS Data Type Identifier: #{data_identifier}"})
  end

  # APRS Data Identifier not recognized
  defp parse_w_data_identifier({_, msg}, data_identifier) do
    throw(
      {msg,
       "APRS Data Type Identifier is not in the spec. or is unused or reserved: #{data_identifier}"}
    )
  end

  # Look at the strings and throw if they are not valid strings
  defp validate_strings({aprs, msg}) do
    aprs_map = Map.from_struct(aprs)
    validate_string(aprs_map, [:symbol], "Symbol")
    # validate_string(aprs_map, [:message], "Message")
    validate_string(aprs_map, [:from], "From")
    validate_string(aprs_map, [:to], "To")
    # validate_string(aprs_map, [:comment], "Comment")
    # validate_string(aprs_map, [:status], "Status")
    validate_string(aprs_map, [:raw_gps], "Raw GPS")
    validate_string(aprs_map, [:weather, :wx_unit], "WX Unit")
    validate_string(aprs_map, [:weather, :softwary_type], "Software Type")
    validate_string(aprs_map, [:device], "Device")

    if not Enum.all?(aprs.path, &String.valid?/1) do
      throw({nil, "A Path component is not a valid string"})
    end

    {aprs, msg}
  end

  defp validate_string(aprs, field_list, name_of_field) do
    case get_in(aprs, field_list) do
      str when is_binary(str) ->
        if String.valid?(str) do
          :ok
        else
          throw({nil, "#{name_of_field} is not a valid string: #{String.replace_invalid(str)}"})
        end

      _ ->
        nil
    end
  end

  defp parse_telemetry_report({aprs, <<"#MIC,", rest::binary>>}) do
    {aprs, rest} |> add_telemetry_report(nil)
  end

  defp parse_telemetry_report({aprs, <<"#MIC", rest::binary>>}) do
    {aprs, rest} |> add_telemetry_report(nil)
  end

  # aprs.fi is tolernt of 1-5 digits in the sequence number
  defp parse_telemetry_report({aprs, <<"#", sequence_no::binary-size(1), ",", rest::binary>>})
       when is_all_digits(sequence_no) do
    {aprs, rest} |> add_telemetry_report(sequence_no)
  end

  defp parse_telemetry_report({aprs, <<"#", sequence_no::binary-size(2), ",", rest::binary>>})
       when is_all_digits(sequence_no) do
    {aprs, rest} |> add_telemetry_report(sequence_no)
  end

  defp parse_telemetry_report({aprs, <<"#", sequence_no::binary-size(3), ",", rest::binary>>})
       when is_all_digits(sequence_no) do
    {aprs, rest} |> add_telemetry_report(sequence_no)
  end

  defp parse_telemetry_report({aprs, <<"#", sequence_no::binary-size(4), ",", rest::binary>>})
       when is_all_digits(sequence_no) do
    {aprs, rest} |> add_telemetry_report(sequence_no)
  end

  defp parse_telemetry_report({aprs, <<"#", sequence_no::binary-size(5), ",", rest::binary>>})
       when is_all_digits(sequence_no) do
    {aprs, rest} |> add_telemetry_report(sequence_no)
  end

  defp parse_telemetry_report({_, msg}), do: throw({msg, "Badly formatted telemetry report"})

  defp add_telemetry_report({aprs, msg}, sequence_no) do
    {telemetry, rest} =
      parse_comma_separated_string(msg, &fn_is_all_float/1)

    {channels, digital_value} =
      {Enum.take(telemetry, min(5, Enum.count(telemetry) - 1)), List.last(telemetry)}

    if not Enum.all?(String.codepoints(digital_value), &(&1 in ["0", "1"])) do
      throw({msg, "Digital value must be a string of 0's and 1's"})
    end

    telemetry_struct = %{
      values: Enum.filter(channels, fn value -> value != "" end) |> Enum.map(&to_numeric/1),
      bits: String.codepoints(digital_value) |> Enum.map(&String.to_integer/1)
    }

    telemetry_struct =
      if sequence_no != nil,
        do: Map.put(telemetry_struct, :sequence_counter, String.to_integer(sequence_no)),
        else: telemetry_struct

    {aprs |> add_info(:telemetry, telemetry_struct), rest}
  end

  # Message Acknowledgement: Chapter 14 page 72 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_message({aprs, <<addressee::binary-size(9), ":ack", message_no::binary>>}) do
    {aprs
     |> add_info(:message, %{
       addressee: addressee,
       message: "ack",
       message_no: message_no
     }), ""}
  end

  # Message Recjection: Chapter 14 page 72 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_message({aprs, <<addressee::binary-size(9), ":rej", message_no::binary>>}) do
    {aprs
     |> add_info(:message, %{
       addressee: addressee,
       message: "rej",
       message_no: message_no
     }), ""}
  end

  # Extract Message Number: Chapter 14 page 71 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_message({aprs, <<addressee::binary-size(9), ":", rest::binary>>}) do
    case Regex.run(~r/(.*?)\{([\d]*)/, rest) do
      [_, message_text, message_no] when message_no != "" ->
        {aprs
         |> add_info(:message, %{
           addressee: addressee,
           message: message_text,
           message_no: message_no
         }), ""}

      _ ->
        {aprs
         |> add_info(:message, %{
           addressee: addressee,
           message: rest
         }), ""}
    end
  end

  defp parse_message({_, msg}),
    do: throw({msg, "Addressee must be 9 characters followed by a ':'"})

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
    {
      aprs
      |> add_info(message: nil)
      |> add_info(telemetry: %{parm: parse_comma_separated_binary(list), to: aprs.from}),
      ""
    }
  end

  defp parse_telemetry_definition_message({aprs, _msg}, <<"UNIT.", list::binary>>) do
    {aprs
     |> add_info(message: nil)
     |> add_info(telemetry: %{unit: parse_comma_separated_binary(list), to: aprs.from}), ""}
  end

  defp parse_telemetry_definition_message({aprs, msg}, <<"BITS.", bits::binary>>) do
    case Regex.run(~r/([01]*),(.*)/, bits) do
      [_, bits, project_title] when bits != "" ->
        {aprs
         |> add_info(message: nil)
         |> add_info(
           telemetry: %{
             bits: String.split(bits, "", trim: true) |> Enum.map(&String.to_integer/1),
             project_title: project_title,
             to: aprs.from
           }
         ), ""}

      _ ->
        throw({msg, "Badly formatted BITS message"})
    end
  end

  defp parse_telemetry_definition_message({aprs, _msg}, <<"EQNS.", list::binary>>) do
    {values, extras} = String.split(list, ",") |> Enum.split(15)
    extras = Enum.join(extras, ",")
    # Truncate the list to a multiple of 3
    values = Enum.take(values, Enum.count(values) - Integer.mod(Enum.count(values), 3))

    {
      aprs
      |> add_info(message: nil)
      |> add_info(
        telemetry: %{eqns: values |> Enum.map(&to_float/1) |> group_list(3), to: aprs.from}
      ),
      extras
    }
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

  defp parse_status_report({aprs, <<dhm::binary-size(6), "z", msg::binary>>})
       when is_all_digits(dhm) do
    {aprs
     |> add_info(status: msg)
     |> add_info(timestamp: parse_timestamp(dhm, "z")), ""}
  end

  defp parse_status_report(
         {aprs,
          <<major_gg::binary-size(2), nn::binary-size(2), symbol_table_id::binary-size(1),
            symbol_code::binary-size(1)>>}
       ) do
    {aprs
     |> add_info(status: "")
     |> add_info(:position, %{
       maidenhead: major_gg <> nn
     })
     |> add_info(symbol: symbol_table_id <> symbol_code), ""}
  end

  defp parse_status_report(
         {aprs,
          <<major_gg::binary-size(2), nn::binary-size(2), gg::binary-size(2),
            symbol_table_id::binary-size(1), symbol_code::binary-size(1), " ", msg::binary>>}
       ) do
    {aprs
     |> add_info(status: msg)
     |> add_info(:position, %{
       maidenhead: major_gg <> nn <> gg
     })
     |> add_info(symbol: symbol_table_id <> symbol_code), ""}
  end

  defp parse_status_report({aprs, msg}) do
    {aprs |> add_info(status: msg), ""}
  end

  # Altitiude in the Mic-E status message: Page 55, Chapter 10 of http://www.aprs.org/doc/APRS101.PDF
  defp maybe_extract_mic_e_altitude(
         {aprs, <<altitude::binary-size(3), "}", rest::binary>> = _msg}
       ) do
    {add_info(aprs, :position, %{
       altitude: decode_base91_ascii_string(altitude) - 10000.0
     }), rest}
  end

  defp maybe_extract_mic_e_altitude(p), do: p

  # Extract the Mic-E device type: See http://www.aprs.org/aprs12/mic-e-types.txt
  defp extract_mic_e_device({aprs, ""}) do
    {add_info(aprs, device: "Original Mic-E"), ""}
  end

  defp extract_mic_e_device({aprs, <<" ", rest::binary>> = _msg}) do
    {add_info(aprs, device: "Original Mic-E"), rest}
  end

  defp extract_mic_e_device({aprs, <<">", rest::binary>> = _msg}) do
    case String.last(rest) do
      "=" ->
        {add_info(aprs, device: "Kenwood TH-D72"), String.slice(rest, 0, String.length(rest) - 1)}

      "^" ->
        {add_info(aprs, device: "Kenwood TH-D74"), String.slice(rest, 0, String.length(rest) - 1)}

      _ ->
        if String.length(rest) > 1 do
          {add_info(aprs, device: "Kenwood TH-D7A"), rest}
        else
          {add_info(aprs, device: "Kenwood TH-D7A"), ""}
        end
    end
  end

  defp extract_mic_e_device({aprs, <<"]", rest::binary>> = _msg}) when rest != "" do
    case String.last(rest) do
      "=" ->
        {add_info(aprs, device: "Kenwood TM-D710"),
         String.slice(rest, 0, String.length(rest) - 1)}

      _ ->
        {add_info(aprs, device: "Kenwood TM-D700"),
         String.slice(rest, 0, String.length(rest) - 1)}
    end
  end

  defp extract_mic_e_device({aprs, <<"`", rest::binary>> = _msg}) do
    case String.slice(rest, -2, 2) do
      "_ " ->
        {add_info(aprs, device: "Yaesu VX-8"), String.slice(rest, 0, String.length(rest) - 2)}

      "_=" ->
        {add_info(aprs, device: "Yaesu FTM-350"), String.slice(rest, 0, String.length(rest) - 2)}

      "_#" ->
        {add_info(aprs, device: "Yaesu VX-8G"), String.slice(rest, 0, String.length(rest) - 2)}

      "_$" ->
        {add_info(aprs, device: "Yaesu FT1D"), String.slice(rest, 0, String.length(rest) - 2)}

      "_%" ->
        {add_info(aprs, device: "Yaesu FTM-400DR"),
         String.slice(rest, 0, String.length(rest) - 2)}

      "_)" ->
        {add_info(aprs, device: "Yaesu FTM-100D"), String.slice(rest, 0, String.length(rest) - 2)}

      "_(" ->
        {add_info(aprs, device: "Yaesu FT2D"), String.slice(rest, 0, String.length(rest) - 2)}

      "_0" ->
        {add_info(aprs, device: "Yaesu FT3D"), String.slice(rest, 0, String.length(rest) - 2)}

      "_3" ->
        {add_info(aprs, device: "Yaesu FT5D"), String.slice(rest, 0, String.length(rest) - 2)}

      "_1" ->
        {add_info(aprs, device: "Yaesu FTM-300D"), String.slice(rest, 0, String.length(rest) - 2)}

      " X" ->
        {add_info(aprs, device: "AP510"), String.slice(rest, 0, String.length(rest) - 2)}

      "(5" ->
        {add_info(aprs, device: "Anytone D578UV"), String.slice(rest, 0, String.length(rest) - 2)}

      _ ->
        {aprs, rest}
    end
  end

  defp extract_mic_e_device({aprs, <<"'", rest::binary>> = _msg}) do
    case String.slice(rest, -2, 2) do
      "(8" ->
        {add_info(aprs, device: "Anytone D878UV"), String.slice(rest, 0, String.length(rest) - 2)}

      "|3" ->
        {add_info(aprs, device: "Byonics TinyTrack3"),
         String.slice(rest, 0, String.length(rest) - 2)}

      "|4" ->
        {add_info(aprs, device: "Byonics TinyTrack5"),
         String.slice(rest, 0, String.length(rest) - 2)}

      ":4" ->
        {add_info(aprs, device: "SCS GmbH & Co. P4dragon DR-7400 modems"),
         String.slice(rest, 0, String.length(rest) - 2)}

      ":8" ->
        {add_info(aprs, device: "SCS GmbH & Co. P4dragon DR-7800 modems"),
         String.slice(rest, 0, String.length(rest) - 2)}

      _ ->
        {aprs, rest}
    end
  end

  defp extract_mic_e_device(p), do: p

  defp parse_mic_e_data(
         {aprs,
          <<long_degrees::binary-size(1), long_minutes::binary-size(1),
            long_hundredths::binary-size(1), sp::binary-size(1), dc::binary-size(1),
            se::binary-size(1), symbol_code::binary-size(1), sym_table_id::binary-size(1),
            rest::binary>> = _msg}
       ) do
    {lat, long, speed, direction, mic_e_status} =
      parse_mic_e(aprs.to, long_degrees, long_minutes, long_hundredths, sp, dc, se)

    {aprs
     |> add_info(status: mic_e_status)
     |> add_info(:position, %{
       latitude: {lat, :hundredth_minute},
       longitude: {long, :hundredth_minute}
     })
     |> add_info(:course, %{direction: direction, speed: speed})
     |> add_info(symbol: sym_table_id <> symbol_code), rest}
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

  @mic_e_statuses %{
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

  # There is a long list of constraints on valid values for the Mic-E message which are
  # enforced by the unusually long list of if statements
  # See Chapter 10 page 42-44 of http://www.aprs.org/doc/APRS101.PDF
  defp parse_mic_e(
         <<b1::binary-size(1), b2::binary-size(1), b3::binary-size(1), b4::binary-size(1),
           b5::binary-size(1), b6::binary-size(1), _::binary>> = _to,
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

    if dec1 == nil or dec2 == nil or dec3 == nil or dec4 == nil or dec5 == nil or dec6 == nil do
      throw({nil, "Invalid Mic-E destination address #{b1 <> b2 <> b3 <> b4 <> b5 <> b6}"})
    end

    if not Map.has_key?(dec4, :n_s) do
      throw({nil, "Invalid Mic-E destination 4th byte, must indicate N/S direction got: #{b4}"})
    end

    if not Map.has_key?(dec6, :w_e) do
      throw({nil, "Invalid Mic-E destination 6th byte, must indicate E/W direction got: #{b6}"})
    end

    if not Map.has_key?(dec5, :long_offset) do
      throw(
        {nil, "Invalid Mic-E destination 5th byte, must indicate longitude offset got: #{b5}"}
      )
    end

    lat =
      dec1.lat * 10 + dec2.lat +
        (dec3.lat * 10.0 + dec4.lat + dec5.lat / 10.0 + dec6.lat / 100.0) / 60.0

    lat =
      case dec4.n_s do
        :south ->
          -lat

        :north ->
          lat

        _ ->
          throw({nil, "Invalid Mic-E destination 4th byte, must indicate N/S direction"})
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
        :west ->
          -long

        :east ->
          long

        _ ->
          throw({nil, "Invalid Mic-E destination 6th byte, must indicate E/W direction"})
      end

    status_number = dec1.bit * 4 + dec2.bit * 2 + dec3.bit

    status_type =
      case {dec1.custom?, dec2.custom?, dec3.custom?} do
        {true, true, true} -> :custom
        {false, false, false} -> :std
        # If all the bits don't agree, then it is unknown (Note on Page 45)
        _ -> :unknown
      end

    status = Map.get(@mic_e_statuses, {status_type, status_number}, "Unknown")

    dc = byte_val(dc) - 28

    speed = byte_val(sp) - 28
    speed = if speed >= 80, do: speed - 80, else: speed
    speed = speed * 10 + div(dc, 10)
    speed = if speed >= 800, do: speed - 800, else: speed
    speed = speed * @knots_to_meters_per_second

    direction = rem(dc, 10) * 100 + byte_val(se) - 28
    direction = 1.0 * if direction >= 400, do: direction - 400, else: direction

    {lat, long, speed, direction, status}
  end

  defp parse_mic_e(
         to,
         _,
         _,
         _,
         _,
         _,
         _
       ) do
    throw({nil, "Invalid Mic-E destination address #{to}, must be 6 bytes long"})
  end

  defp parse_position_uncompressed(
         {aprs,
          <<lat::binary-size(8), sym_table_id::binary-size(1), long::binary-size(9),
            symbol_code::binary-size(1), rest::binary>> = _msg}
       ) do
    {add_info(aprs, :position, %{
       latitude: parse_lat(lat),
       longitude: parse_long(long)
     })
     |> add_info(symbol: sym_table_id <> symbol_code), rest}
  end

  defp parse_position_uncompressed({_, msg}),
    do: throw({msg, "Badly formatted uncompressed position"})

  defp parse_position_compressed(
         {aprs,
          <<sym_table_id::binary-size(1), lat::binary-size(4), long::binary-size(4),
            symbol_code::binary-size(1), cs::binary-size(2), comp_type::binary-size(1),
            rest::binary>> = _msg}
       ) do
    {add_info(
       aprs,
       :position,
       %{
         latitude: uncompress_lat(lat),
         longitude: uncompress_long(long)
       }
     )
     |> add_info(symbol: sym_table_id <> symbol_code)
     |> parse_cs(cs, comp_type), rest}
  end

  defp parse_position_compressed({_, msg}),
    do: throw({msg, "Badly formatted compressed information"})

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

    add_info(aprs, :position, %{
      altitude: altitude
    })
  end

  defp parse_cs(aprs, <<c::binary-size(1), s::binary-size(1)>> = _cs, _comp_type) when c != " " do
    case :erlang.binary_to_list(c) do
      [c] when c >= 33 and c <= 122 ->
        # Course/Speed (c between ! and z inclusive)
        [s] = :erlang.binary_to_list(s)

        add_info(aprs, :course, %{
          direction: (c - 33) * 4.0,
          speed: (Float.pow(1.08, s - 33) - 1.0) * @knots_to_meters_per_second
        })

      [c] when c == 123 ->
        # Pre-Calculated Radio Range (c equals { )
        [s] = :erlang.binary_to_list(s)

        add_info(aprs, :position, %{
          range: 2.0 * Float.pow(1.08, s - 33) * @meters_per_mile
        })

      _ ->
        aprs
    end
  end

  defp parse_cs(aprs, _cs, _comp_type), do: aprs

  defp parse_positionless_weather_report({aprs, <<mdhm::binary-size(8), weather_data::binary>>}) do
    {add_info(aprs, timestamp: parse_timestamp_mdhm(mdhm)), weather_data}
    |> add_weather_parameters(true)
  end

  defp parse_weather_data(
         {%__MODULE__{symbol: symbol, course: %{direction: direction, speed: speed}} = aprs, msg}
       )
       when symbol in ["/_"] do
    {
      aprs
      |> add_info(course: nil)
      |> add_info(:weather, %{wind_speed: speed, wind_direction: direction}),
      msg
    }
    |> add_weather_parameters()
  end

  defp parse_weather_data(
         {%__MODULE__{symbol: symbol} = aprs,
          <<wind_direction::binary-size(3), "/", wind_speed::binary-size(3), rest::binary>> = _msg}
       )
       when symbol in ["/_"] do
    {aprs, rest}
    |> add_wind_direction(wind_direction)
    |> add_wind_speed(wind_speed)
    |> add_weather_parameters()
  end

  defp parse_weather_data(p), do: p

  defp add_wind_direction({aprs, rest}, wind_direction) when wind_direction in ["...", "   "] do
    {aprs, rest}
  end

  defp add_wind_direction({aprs, rest}, wind_direction) do
    {add_info(aprs, :weather, %{
       wind_direction: to_float(wind_direction)
     }), rest}
  end

  defp add_wind_speed({aprs, rest}, wind_speed) when wind_speed in ["...", "   "] do
    {aprs, rest}
  end

  defp add_wind_speed({aprs, rest}, wind_speed) do
    {add_info(aprs, :weather, %{
       wind_speed: to_float(wind_speed)
     }), rest}
  end

  defp add_weather_parameters(p, positionless? \\ false)

  defp add_weather_parameters(
         {aprs, <<param_code::binary-size(1), rest::binary>>},
         positionless?
       )
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
              "c",
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
          # aprs.fi accepts 3 digits of humidity, but the spec says 2 digits.
          if String.length(rest) > 2 and is_all_digits(String.slice(rest, 2, 1)) do
            add_weather({aprs, rest}, :humidity, 3, 1.0)
          else
            add_weather({aprs, rest}, :humidity, 2, 1.0)
          end

        "b" ->
          # aprs.fi accepts 6 digits of barametric pressure, but the spec says 5 digits.
          if String.length(rest) > 5 and is_all_digits(String.slice(rest, 5, 1)) do
            add_weather({aprs, rest}, :barometric_pressure, 6, 0.1)
          else
            add_weather({aprs, rest}, :barometric_pressure, 5, 0.1)
          end

        "L" ->
          add_weather({aprs, rest}, :luminosity, 3, 1.0)

        "l" ->
          add_weather({aprs, rest}, :luminosity, 3, 1000.0)

        "c" ->
          add_weather({aprs, rest}, :wind_direction, 3, 1.0)

        "s" ->
          # In the case of positionless weather report, 's' parameter means
          # the wind speed. Otherwise, it means the snowfall.
          # See http://www.aprs.org/aprs11/spec-wx.txt
          if positionless? do
            add_weather({aprs, rest}, :wind_speed, 3, @miles_per_hour_to_meters_per_second)
          else
            add_weather({aprs, rest}, :snowfall, 3, @inch_to_meters)
          end

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

        _ ->
          # If we don't recognize the parameter, we just return the APRS message as is.
          {aprs, rest}
      end

    if new_rest == rest do
      {aprs, param_code <> rest}
    else
      add_weather_parameters({new_aprs, new_rest}, positionless?)
    end
  end

  defp add_weather_parameters({aprs, <<s::binary-size(1), wx_unit::binary>>}, _positionless?)
       when not is_all_digits(wx_unit) and byte_size(wx_unit) >= 2 and
              byte_size(wx_unit) <= 4 do
    # APRS Software Version and WX Unit: Chapter 12 page 63 of http://www.aprs.org/doc/APRS101.PDF
    {add_info(aprs, :weather, %{
       software_type:
         case s do
           "d" -> "APRSdos"
           "M" -> "MacAPRS"
           "P" -> "pocketAPRS"
           "S" -> "APRS+SA"
           "W" -> "WinAPRS"
           "X" -> "X-APRS (Linux)"
           _ -> "Unknown '#{s}'"
         end,
       wx_unit:
         case wx_unit do
           "Dvs" -> "Davis"
           "HKT" -> "Heathkit"
           "PIC" -> "PIC Device"
           "RSW" -> "Radio Shack"
           "U-II" -> "Original Ultimeter II (auto mode)"
           "U2R" -> "Original Ultimeter II (remote mode)"
           "U2k" -> "Ultimeter 500/2000"
           "U2kr" -> "Remote Ultimeter logger"
           "U5" -> "Ultimeter 500"
           "Upkm" -> "Remote Ultimeter packet mode"
           _ -> "Unknown '#{wx_unit}'"
         end
     }), ""}
  end

  defp add_weather_parameters({aprs, ""}, _positionless?), do: {aprs, ""}

  defp add_weather_parameters(p, _positionless?) do
    p
  end

  defp add_weather_hurricane({aprs, <<"TS", rest::binary>>}) do
    {add_info(aprs, :weather, %{storm_category: :tropical_stopm}), rest}
    |> add_weather_parameters()
  end

  defp add_weather_hurricane({aprs, <<"HC", rest::binary>>}) do
    {add_info(aprs, :weather, %{storm_category: :hurricane}), rest}
    |> add_weather_parameters()
  end

  defp add_weather_hurricane({aprs, <<"TD", rest::binary>>}) do
    {add_info(aprs, :weather, %{storm_category: :tropical_depression}), rest}
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
        {add_info(aprs, :weather, %{key => convert(to_float(param), factor_or_func)}), new_rest}
      end
    end
  end

  @data_extension_course_speed_bearing_number_range_quality ~r/(\d{3})\/(\d{3})\/(\d{3})\/(\d{3})/
  # Handle 15 byte data extensions (Course/Speed/Bearing,Range/Number,Range,Quality), See Chapter 7 (pg. 30) of http://www.aprs.org/doc/APRS101.PDF
  defp parse_data_extension_15({aprs, <<data_extension::binary-size(15), comment::binary>> = msg}) do
    case Regex.run(@data_extension_course_speed_bearing_number_range_quality, data_extension) do
      [_, direction, speed, bearing, nrq] ->
        <<number::binary-size(1), range::binary-size(1), quality::binary-size(1)>> = nrq
        add_df_report({aprs, comment}, direction, speed, bearing, number, range, quality)

      _ ->
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
      [_, direction, speed] = p
      add_df_report({aprs, msg2}, direction, speed)
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

  defp add_df_report({aprs, msg}, direction, speed) do
    {add_info(aprs, :course, %{
       direction: to_float(direction),
       speed: to_float(speed) * @knots_to_meters_per_second
     }), msg}
  end

  defp add_df_report({aprs, msg}, direction, speed, bearing, number, range, quality) do
    {aprs
     |> add_info(:course, %{
       direction: to_float(direction),
       speed: to_float(speed) * @knots_to_meters_per_second,
       bearing: to_float(bearing),
       report_quality:
         case number do
           "0" -> :useless
           "1" -> 1
           "2" -> 2
           "3" -> 3
           "4" -> 4
           "5" -> 5
           "6" -> 6
           "7" -> 7
           "8" -> 8
           "9" -> :manual
           _ -> :useless
         end,
       bearing_accuracy:
         case quality do
           "0" -> :useless
           "1" -> :less_than_240_degree
           "2" -> :less_than_120_degree
           "3" -> :less_than_64_degree
           "4" -> :less_than_32_degree
           "5" -> :less_than_16_degree
           "6" -> :less_than_8_degree
           "7" -> :less_than_4_degree
           "8" -> :less_than_2_degree
           "9" -> :less_than_1_degree
           _ -> :useless
         end,
       range: Float.pow(2.0, to_float(range)) * @meters_per_mile
     }), msg}
  end

  defp add_phg_report({aprs, msg}, power_code, height_code, gain_code, directivity_code) do
    {add_info(aprs, :antenna, %{
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
           _ -> throw({msg, "power_code #{power_code} unknown"})
         end
     }), msg}
    |> add_hgd_to_report(height_code, gain_code, directivity_code)
  end

  defp add_dfs_report({aprs, msg}, strength_code, height_code, gain_code, directivity_code) do
    {add_info(aprs, :antenna, %{
       strength: to_float(strength_code)
     }), msg}
    |> add_hgd_to_report(height_code, gain_code, directivity_code)
  end

  defp add_hgd_to_report({aprs, msg}, height_code, gain_code, directivity_code) do
    {add_info(aprs, :antenna, %{
       height:
         case height_code do
           "*" -> 2.5 / 16.0
           "+" -> 2.5 / 8.0
           "," -> 2.5 / 4.0
           "-" -> 2.5 / 2.0
           "." -> 2.5
           "/" -> 5.0
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
           "?" -> 163_840.0 * 2.0
           "@" -> 163_840.0 * 4.0
           "A" -> 163_840.0 * 8.0
           "B" -> 163_840.0 * 16.0
           _ -> throw({msg, "Height code #{height_code} unknown"})
         end * @meters_per_foot,
       gain: to_float(gain_code),
       directivity:
         case directivity_code do
           "0" -> :omnidirectional
           "9" -> :omnidirectional
           "1" -> 45.0
           "2" -> 90.0
           "3" -> 135.0
           "4" -> 180.0
           "5" -> 225.0
           "6" -> 270.0
           "7" -> 315.0
           "8" -> 360.0
           _ -> throw({msg, "Directivity code #{directivity_code} unknown"})
         end
     }), msg}
  end

  defp add_rng_report({aprs, msg}, range) do
    {add_info(aprs, :antenna, %{
       range: to_float(range) * @meters_per_mile
     }), msg}
  end

  defp extract_comment({aprs, msg}) do
    {Map.put(aprs, :comment, msg), ""}
  end

  # See Altitude in the comment text: Chapter 6 pg 26 of http://www.aprs.org/doc/APRS101.PDF
  # Note this does not extract the altitude from the comment, it only adds it to the position
  defp maybe_add_altitude_from_comment({%__MODULE__{comment: nil} = aprs, msg}), do: {aprs, msg}

  defp maybe_add_altitude_from_comment({%__MODULE__{comment: comment} = aprs, msg}) do
    case Regex.run(~r/.*A=(\d{6})/, comment) do
      [_, altitude] ->
        {add_info(aprs, :position, %{altitude: to_float(altitude) * @meters_per_foot}), msg}

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
           {
             aprs
             |> add_info(comment: String.trim(pre <> post))
             |> add_info(:telemetry, extract_base91_telemetry(telemetry)),
             msg
           }}

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
        {aprs |> add_info(comment: String.trim(pre <> post)), msg}

      _ ->
        {aprs, msg}
    end
  end

  defp maybe_add_dao_from_comment({aprs, msg}), do: {aprs, msg}

  defp parse_lat(lat) do
    <<lat::binary-size(7), direction::binary-size(1)>> = lat

    if String.match?(lat, ~r/^[\d. ]*$/) do
      {<<degrees::binary-size(2), minutes::binary-size(5)>>, precision} =
        case String.split(lat, " ", parts: 2) do
          [<<_::binary-size(2)>> = l, _] -> {l <> "00.00", :degree}
          [<<_::binary-size(3)>> = l, _] -> {l <> "0.00", :tenth_degree}
          [<<_::binary-size(5)>> = l, _] -> {l <> "00", :minute}
          [<<_::binary-size(6)>> = l, _] -> {l <> "0", :tenth_minute}
          [_] -> {lat, :hundredth_minute}
          _ -> throw({nil, "Could not parse latitude #{lat}"})
        end

      latitude =
        try do
          to_float(String.trim(degrees)) + to_float(String.trim(minutes)) / 60.0
        rescue
          _ ->
            throw({nil, "Could not parse latitude #{lat}"})
        end

      latitude =
        case direction do
          "N" -> latitude
          "n" -> latitude
          "S" -> -latitude
          "s" -> -latitude
          _ -> throw({nil, "Could not parse latitude direction #{direction}"})
        end

      {latitude, precision}
    else
      throw({nil, "Could not parse latitude #{lat}"})
    end
  end

  defp parse_long(long) do
    <<long::binary-size(8), direction::binary-size(1)>> = long

    if String.match?(long, ~r/^[\d. ]*$/) do
      {<<degrees::binary-size(3), minutes::binary-size(5)>>, precision} =
        case String.split(long, " ", parts: 2) do
          [<<_::binary-size(3)>> = l, _] -> {l <> "00.00", :degree}
          [<<_::binary-size(4)>> = l, _] -> {l <> "0.00", :tenth_degree}
          [<<_::binary-size(6)>> = l, _] -> {l <> "00", :minute}
          [<<_::binary-size(7)>> = l, _] -> {l <> "0", :tenth_minute}
          [_] -> {long, :hundredth_minute}
          _ -> throw({nil, "Could not parse longitude #{long}"})
        end

      longitude =
        try do
          to_float(String.trim(degrees)) + to_float(String.trim(minutes)) / 60.0
        rescue
          _ ->
            throw({nil, "Could not parse longitude #{long}"})
        end

      longitude =
        case direction do
          "E" -> longitude
          "e" -> longitude
          "W" -> -longitude
          "w" -> -longitude
          _ -> throw({nil, "Could not parse longitude direction #{direction}"})
        end

      {longitude, precision}
    else
      throw({nil, "Could not parse longitude #{long}"})
    end
  end

  # DHM - Local time
  # Note that only "/" appears in the spec: Chapter 6, Page 22 of http://www.aprs.org/doc/APRS101.PDF
  # It is recommended that Zulu time be used in the future
  defp parse_timestamp(
         <<day::binary-size(2), hour::binary-size(2), minute::binary-size(2)>>,
         time_indicator
       )
       when time_indicator in ["/"] and is_all_digits(day) and is_all_digits(hour) and
              is_all_digits(minute) do
    %{
      day: String.to_integer(day),
      hour: String.to_integer(hour),
      minute: String.to_integer(minute),
      time_zone: :local_to_sender
    }
  end

  # HMS - Zulu time
  defp parse_timestamp(
         <<hour::binary-size(2), minute::binary-size(2), second::binary-size(2)>>,
         time_indicator
       )
       when time_indicator in ["h"] and is_all_digits(hour) and is_all_digits(minute) and
              is_all_digits(second) do
    %{
      hour: String.to_integer(hour),
      minute: String.to_integer(minute),
      second: String.to_integer(second),
      time_zone: :utc
    }
  end

  # DHM - Zulu time
  # Note that only "z" appears in the spec: Chapter 6, Page 22 of http://www.aprs.org/doc/APRS101.PDF
  # But I'm seeing a lot of packets with "a", "Z", " ", and others so I'm just accepting everything as
  # Zulu time
  defp parse_timestamp(
         <<day::binary-size(2), hour::binary-size(2), minute::binary-size(2)>>,
         _time_indicator
       )
       when is_all_digits(day) and is_all_digits(hour) and is_all_digits(minute) do
    %{
      day: String.to_integer(day),
      hour: String.to_integer(hour),
      minute: String.to_integer(minute),
      time_zone: :utc
    }
  end

  defp parse_timestamp(timestamp, _time_indicator),
    do: throw({nil, "Could not parse 'dhm' timestamp #{timestamp}"})

  # MDHM - Zulu time w/o a time indicator (from Positionless Weather Report)
  defp parse_timestamp_mdhm(
         <<month::binary-size(2), day::binary-size(2), hour::binary-size(2),
           minute::binary-size(2)>>
       )
       when is_all_digits(month) and is_all_digits(day) and is_all_digits(hour) and
              is_all_digits(minute) do
    %{
      month: String.to_integer(month),
      day: String.to_integer(day),
      hour: String.to_integer(hour),
      minute: String.to_integer(minute),
      time_zone: :utc
    }
  end

  defp parse_timestamp_mdhm(timestamp),
    do: throw({nil, "Could not parse 'mdhm' timestamp #{timestamp}"})

  defp add_info(%__MODULE__{} = aprs, opts) when is_list(opts) do
    Enum.reduce(opts, aprs, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp add_info(%__MODULE__{} = aprs, key, info) when is_atom(key) and is_map(info) do
    if Map.has_key?(aprs, key) and Map.get(aprs, key) != nil do
      Map.put(aprs, key, Map.merge(Map.get(aprs, key), info))
    else
      Map.put(aprs, key, info)
    end
  end

  defp decode_base91_ascii_string(base91) do
    base91
    # |> String.to_charlist()
    |> :erlang.binary_to_list()
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
      {num, ""} -> num
      _ -> to_float(str)
    end
  end

  defp to_float(""), do: 0.0

  defp to_float(<<".", _::binary>> = str) do
    to_float("0" <> str)
  end

  defp to_float(str) do
    case Float.parse(str) do
      t when is_tuple(t) -> elem(t, 0)
      _ -> throw({nil, "Could not parse float from #{str}"})
    end
  end

  defp byte_val(str) when is_binary(str) do
    :erlang.binary_to_list(str) |> List.first()
  end

  defp throw_to_error_return(raw, nil, error_message) do
    %{
      raw: raw,
      error_message: error_message,
      near_character_position: 0
    }
  end

  defp throw_to_error_return(raw, msg_left, error_message) do
    %{
      raw: raw,
      error_message: error_message,
      near_character_position: String.length(raw) - String.length(msg_left) - 1
    }
  end

  defp fahrenheit_to_celsius(fahrenheit), do: (fahrenheit - 32.0) * (5.0 / 9.0)
  defp convert(value, func) when is_function(func), do: func.(value)
  defp convert(value, factor) when is_float(factor), do: factor * value

  defp parse_comma_separated_string_into(
         <<c::binary-size(1), rest::binary>>,
         [head | tail] = list,
         fn_is_in_set
       ) do
    if c == "," do
      parse_comma_separated_string_into(rest, ["" | list], fn_is_in_set)
    else
      if fn_is_in_set.(c) do
        parse_comma_separated_string_into(rest, [head <> c | tail], fn_is_in_set)
      else
        if head == "" do
          {Enum.reverse(tail), c <> rest}
        else
          {Enum.reverse(list), c <> rest}
        end
      end
    end
  end

  defp parse_comma_separated_string_into("", [head | tail] = _list, _fn_is_in_set)
       when head == "" do
    {Enum.reverse(tail), ""}
  end

  defp parse_comma_separated_string_into("", list, _fn_is_in_set),
    do: {Enum.reverse(list), ""}

  defp parse_comma_separated_string(string, fn_is_in_set)
       when is_binary(string) and is_function(fn_is_in_set) do
    parse_comma_separated_string_into(string, [""], fn_is_in_set)
  end
end
