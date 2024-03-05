defmodule AprsParserTest do
  use ExUnit.Case
  alias APRSUtils.AprsParser

  describe "AprsParser" do
    # ---------------------------------------------------------------
    test "Position w/o timestamp, no path" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:!4903.50N/07201.75W-Test /A=001234")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:!4903.50N/07201.75W-Test /A=001234",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute},
                 altitude: 376.1232,
                 symbol: "/-"
               },
               comment: "Test /A=001234"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, 8 path elements" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "FROMCALL>TOCALL,1,2,3,4,5,6,7,8:/092345z4903.50N/07201.75W>Test1234"
               )

      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("09"),
          String.to_integer("23"),
          String.to_integer("45"),
          0,
          0
        )
        |> elem(1)

      assert %AprsParser{
               raw: "FROMCALL>TOCALL,1,2,3,4,5,6,7,8:/092345z4903.50N/07201.75W>Test1234",
               from: "FROMCALL",
               to: "TOCALL",
               path: ["1", "2", "3", "4", "5", "6", "7", "8"],
               position: %{
                 timestamp: {expected_time, :sender_time},
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute},
                 symbol: "/>"
               },
               comment: "Test1234"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, and Data Extension: Course/Speed" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:/092345z4903.50N/07201.75W>123/456")

      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("09"),
          String.to_integer("23"),
          String.to_integer("45"),
          0,
          0
        )
        |> elem(1)

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:/092345z4903.50N/07201.75W>123/456",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {expected_time, :sender_time},
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute},
                 course: 123.0,
                 speed: 234.586464,
                 symbol: "/>"
               },
               comment: ""
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, and Data Extension: Course/Speed Bearing and Number/Range/Quality" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:/092345z4903.50N/07201.75W>088/036/270/729")

      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("09"),
          String.to_integer("23"),
          String.to_integer("45"),
          0,
          0
        )
        |> elem(1)

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:/092345z4903.50N/07201.75W>088/036/270/729",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {expected_time, :sender_time},
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute},
                 course: 88.0,
                 speed: 18.519984,
                 bearing: 270.0,
                 bearing_accuracy: :less_1,
                 N: 7,
                 range: 6437.376,
                 symbol: "/>"
               },
               comment: ""
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, and Data Extension: PHG" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:/092345z4903.50N/07201.75W>PHG5132")

      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("09"),
          String.to_integer("23"),
          String.to_integer("45"),
          0,
          0
        )
        |> elem(1)

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:/092345z4903.50N/07201.75W>PHG5132",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {expected_time, :sender_time},
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute},
                 power: 25.0,
                 height: 6.096,
                 gain: 3.0,
                 directivity: 90.0,
                 symbol: "/>"
               },
               comment: ""
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, and Data Extension: RNG" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:/092345z4903.50N/07201.75W>RNG0050")

      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("09"),
          String.to_integer("23"),
          String.to_integer("45"),
          0,
          0
        )
        |> elem(1)

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:/092345z4903.50N/07201.75W>RNG0050",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {expected_time, :sender_time},
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute},
                 range: 80467.2,
                 symbol: "/>"
               },
               comment: ""
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, and Data Extension: DFS" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:/092345z4903.50N/07201.75W>DFS2132")

      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("09"),
          String.to_integer("23"),
          String.to_integer("45"),
          0,
          0
        )
        |> elem(1)

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:/092345z4903.50N/07201.75W>DFS2132",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {expected_time, :sender_time},
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute},
                 strength: 2.0,
                 height: 6.096,
                 gain: 3.0,
                 directivity: 90.0,
                 symbol: "/>"
               },
               comment: ""
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ambiguity" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:!491 .  N/07201.1 W-Test /A=001234")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:!491 .  N/07201.1 W-Test /A=001234",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 latitude: {49.166666666666664, :tenth_degree},
                 longitude: {-72.01833333333333, :tenth_minute},
                 altitude: 376.1232,
                 symbol: "/-"
               },
               comment: "Test /A=001234"
             } == expected_result

      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:!49  .  N/07201.  W-Test /A=001234")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:!49  .  N/07201.  W-Test /A=001234",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 latitude: {49.0, :degree},
                 longitude: {-72.01666666666667, :minute},
                 altitude: 376.1232,
                 symbol: "/-"
               },
               comment: "Test /A=001234"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Compressed" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "M0XER-4>APRS64,TF3RPF,WIDE2*,qAR,TF3SUT-2:!/.(M4I^C,O `DXa/A=040849|#B>@\"v90!+|h"
               )

      assert %AprsParser{
               raw:
                 "M0XER-4>APRS64,TF3RPF,WIDE2*,qAR,TF3SUT-2:!/.(M4I^C,O `DXa/A=040849|#B>@\"v90!+|h",
               from: "M0XER-4",
               to: "APRS64",
               path: ["TF3RPF", "WIDE2*", "qAR", "TF3SUT-2"],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 latitude: {64.11987367625208, :hundredth_minute},
                 longitude: {-19.070654142799384, :hundredth_minute},
                 altitude: 12450.7752,
                 symbol: "/O"
               },
               telemetry: %{values: [2670, 176, 2199, 10], sequence_counter: 215},
               comment: "Xa/A=040849h"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Compressed w/ CS report" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "M0XER-4>APRS64,TF3RPF,WIDE2*,qAR,TF3SUT-2:!/.(M4I^C,O7PDXa/A=040849|#B>@\"v90!+|h"
               )

      assert %AprsParser{
               raw:
                 "M0XER-4>APRS64,TF3RPF,WIDE2*,qAR,TF3SUT-2:!/.(M4I^C,O7PDXa/A=040849|#B>@\"v90!+|h",
               from: "M0XER-4",
               to: "APRS64",
               path: ["TF3RPF", "WIDE2*", "qAR", "TF3SUT-2"],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 latitude: {64.11987367625208, :hundredth_minute},
                 longitude: {-19.070654142799384, :hundredth_minute},
                 altitude: 12450.7752,
                 course: 88.0,
                 speed: 18.63934126818573,
                 symbol: "/O"
               },
               telemetry: %{values: [2670, 176, 2199, 10], sequence_counter: 215},
               comment: "Xa/A=040849h"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Compressed w/ Pre-calculated radio range" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "M0XER-4>APRS64,TF3RPF,WIDE2*,qAR,TF3SUT-2:!/.(M4I^C,O{?DXa/A=040849|#B>@\"v90!+|h"
               )

      assert %AprsParser{
               raw:
                 "M0XER-4>APRS64,TF3RPF,WIDE2*,qAR,TF3SUT-2:!/.(M4I^C,O{?DXa/A=040849|#B>@\"v90!+|h",
               from: "M0XER-4",
               to: "APRS64",
               path: ["TF3RPF", "WIDE2*", "qAR", "TF3SUT-2"],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 latitude: {64.11987367625208, :hundredth_minute},
                 longitude: {-19.070654142799384, :hundredth_minute},
                 altitude: 12450.7752,
                 range: 32388.552976978044,
                 symbol: "/O"
               },
               telemetry: %{values: [2670, 176, 2199, 10], sequence_counter: 215},
               comment: "Xa/A=040849h"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Compressed w/ altitude in csT bytes" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "M0XER-4>APRS64,TF3RPF,WIDE2*,qAR,TF3SUT-2:!/.(M4I^C,OS]PXa/|#B>@\"v90!+|h"
               )

      assert %AprsParser{
               raw: "M0XER-4>APRS64,TF3RPF,WIDE2*,qAR,TF3SUT-2:!/.(M4I^C,OS]PXa/|#B>@\"v90!+|h",
               from: "M0XER-4",
               to: "APRS64",
               path: ["TF3RPF", "WIDE2*", "qAR", "TF3SUT-2"],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 latitude: {64.11987367625208, :hundredth_minute},
                 longitude: {-19.070654142799384, :hundredth_minute},
                 altitude: 3049.3777114537656,
                 symbol: "/O"
               },
               telemetry: %{values: [2670, 176, 2199, 10], sequence_counter: 215},
               comment: "Xa/h"
             } == expected_result
    end

    # ---------------------------------------------------------------
    @doc """
    Actual data from aprs.fi on this packet
    Comment:	MT-RTG 50
    Mic-E message:	In service
    Last status:	MicroTrak FA v1.42
    Location:	40°20.86' N 79°49.36' W - locator FN00CI13GK
    Last position:	2024-02-20 15:06:51 EST (20h25m ago)
    2024-02-20 15:06:51 EST local time at White Oak, United States [?]
    Altitude:	1086 ft
    Course:	177°
    Speed:	9 MPH
    Last telemetry:	2024-02-20 15:06:51 EST (20h25m ago) – show telemetry
    Ch 1: 495, Ch 2: 629, Ch 3: 0, Ch 4: 0, Ch 5: 0
    Device:	Byonics: TinyTrak3 (tracker)
    Last path:	KB3FDA-9>T0RP8U via KB3FCZ-2,WIDE1*,WIDE2-1,qAO,KC3VKP-1 (good)
    """
    test "Mic-E w/ altitude, course, speed, and telemetry" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "KB3FDA-9>S32U6T,KB3FCZ-2,WIDE1*,WIDE2-1,qAO,KC3VKP-1:`(_fn\"O>/'\"4T}|!(&I't|!wY[!|3"
               )

      assert %AprsParser{
               raw:
                 "KB3FDA-9>S32U6T,KB3FCZ-2,WIDE1*,WIDE2-1,qAO,KC3VKP-1:`(_fn\"O>/'\"4T}|!(&I't|!wY[!|3",
               from: "KB3FDA-9",
               to: "S32U6T",
               path: ["KB3FCZ-2", "WIDE1*", "WIDE2-1", "qAO", "KC3VKP-1"],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 latitude: {33.42733333333334, :hundredth_minute},
                 longitude: {-12.129, :hundredth_minute},
                 altitude: 61.0,
                 course: 251.0,
                 speed: 10.28888,
                 symbol: "/>"
               },
               telemetry: %{sequence_counter: 7, values: [495, 629]},
               message: "Committed",
               comment: "",
               other: %{device: "Byonics TinyTrack3"}
             } == expected_result
    end

    # ---------------------------------------------------------------
    @doc """

    """
    test "Mic-E w/ a comment" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "KB3FDA-9>T0RQ0V,KB3FCZ-2,WIDE1*,WIDE2-1,qAR,WA3YMM-1:`kM5nK+>/'\"6z}MT-RTG 50|!&&G'r|!w{F!|3"
               )

      assert %AprsParser{
               raw:
                 "KB3FDA-9>T0RQ0V,KB3FCZ-2,WIDE1*,WIDE2-1,qAR,WA3YMM-1:`kM5nK+>/'\"6z}MT-RTG 50|!&&G'r|!w{F!|3",
               from: "KB3FDA-9",
               to: "T0RQ0V",
               other: %{device: "Byonics TinyTrack3"},
               path: ["KB3FCZ-2", "WIDE1*", "WIDE2-1", "qAR", "WA3YMM-1"],
               position: %{
                 latitude: {40.351, :hundredth_minute},
                 longitude: {-79.82083333333334, :hundredth_minute},
                 altitude: 281.0,
                 course: 315.0,
                 speed: 12.346656,
                 symbol: "/>",
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               message: "Special",
               telemetry: %{sequence_counter: 5, values: [493, 627]},
               comment: "MT-RTG 50"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Mic-E" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>SUSUR1:`CF\"l#![/`\"3z}_ ")

      assert %AprsParser{
               raw: "FROMCALL>SUSUR1:`CF\"l#![/`\"3z}_ ",
               from: "FROMCALL",
               to: "SUSUR1",
               path: [],
               position: %{
                 latitude: {35.58683333333333, :hundredth_minute},
                 longitude: {139.701, :hundredth_minute},
                 altitude: 8.0,
                 course: 305.0,
                 speed: 0.0,
                 symbol: "/[",
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               other: %{device: "Yaesu VX-8"},
               message: "Emergency",
               comment: ""
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Object" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:;LEADER   *092345z4903.50N/07201.75W>088/036")

      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("09"),
          String.to_integer("23"),
          String.to_integer("45"),
          0,
          0
        )
        |> elem(1)

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:;LEADER   *092345z4903.50N/07201.75W>088/036",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute},
                 course: 88.0,
                 speed: 18.519984,
                 symbol: "/>",
                 timestamp: {expected_time, :sender_time}
               },
               object: %{
                 state: :alive,
                 name: "LEADER   "
               },
               comment: ""
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Item" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:)ITEM_4903.50N/07201.75W>088/036")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:)ITEM_4903.50N/07201.75W>088/036",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute},
                 course: 88.0,
                 speed: 18.519984,
                 symbol: "/>",
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               item: %{
                 state: :killed,
                 name: "ITEM"
               },
               comment: ""
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Status Report" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:>status text")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:>status text",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               status: "status text"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Status Report w/ Maidenhead" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:>IO91SX/- status text")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:>IO91SX/- status text",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 maidenhead: "IO91SX",
                 symbol: "/-"
               },
               status: "status text"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Status Report w/ Timestamp" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:>092345zstatus text")

      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("09"),
          String.to_integer("23"),
          String.to_integer("45"),
          0,
          0
        )
        |> elem(1)

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:>092345zstatus text",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {expected_time, :sender_time}
               },
               status: "status text"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Message Regular" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL::ADDRCALL :message text")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL::ADDRCALL :message text",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               message: %{
                 addressee: "ADDRCALL ",
                 message: "message text"
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Message w/ message number" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL::ADDRCALL :message text{001")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL::ADDRCALL :message text{001",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               message: %{
                 addressee: "ADDRCALL ",
                 message: "message text",
                 message_no: 1
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Message ack message number" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL::ADDRCALL :ack001")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL::ADDRCALL :ack001",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               message: %{
                 addressee: "ADDRCALL ",
                 message: "ack",
                 message_no: 1
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Message rej message number" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL::ADDRCALL :rej001")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL::ADDRCALL :rej001",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               message: %{
                 addressee: "ADDRCALL ",
                 message: "rej",
                 message_no: 1
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    # Location:	40°32.53' N 79°57.36' W
    # A1: 1263
    # A2: 4376
    # A3: 3842
    # A4: 18
    # A5: 4097

    test "Compressed Telemetry" do
      assert {:ok, expected_result} =
               AprsParser.parse("KC3ARY>APDW16,TCPIP*,qAC,T2TEXAS:!I:!&N:;\")#  !|,7.qQ)K5!3N#|")

      assert %AprsParser{
               raw: "KC3ARY>APDW16,TCPIP*,qAC,T2TEXAS:!I:!&N:;\")#  !|,7.qQ)K5!3N#|",
               from: "KC3ARY",
               to: "APDW16",
               path: ["TCPIP*", "qAC", "T2TEXAS"],
               position: %{
                 latitude: {40.54216566997265, :hundredth_minute},
                 longitude: {-79.95600195313526, :hundredth_minute},
                 symbol: "I#",
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               comment: "",
               telemetry: %{
                 sequence_counter: 1023,
                 values: [1263, 4376, 3842, 18, 4097]
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Telemetry UNIT" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "FROMCALL>TOCALL::FROMCALL :UNIT.Volt,Pkt,Pkt,Pcnt,None,On,On,On,On,Hi,Hi,Hi,Hi"
               )

      assert %AprsParser{
               raw:
                 "FROMCALL>TOCALL::FROMCALL :UNIT.Volt,Pkt,Pkt,Pcnt,None,On,On,On,On,Hi,Hi,Hi,Hi",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               telemetry: %{
                 to: "FROMCALL",
                 unit: [
                   "Volt",
                   "Pkt",
                   "Pkt",
                   "Pcnt",
                   "None",
                   "On",
                   "On",
                   "On",
                   "On",
                   "Hi",
                   "Hi",
                   "Hi",
                   "Hi"
                 ]
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Telemetry BITS" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL::FROMCALL :BITS.11001010,My Big Balloon")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL::FROMCALL :BITS.11001010,My Big Balloon",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               telemetry: %{
                 to: "FROMCALL",
                 bits: [1, 1, 0, 0, 1, 0, 1, 0],
                 project_title: "My Big Balloon"
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Telemetry PARM" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "FROMCALL>TOCALL::FROMCALL :PARM.Vin,Rx1h,Dg1h,Eff1h,A5,O1,O2,O3,O4,I1,I2,I3,I4"
               )

      assert %AprsParser{
               raw:
                 "FROMCALL>TOCALL::FROMCALL :PARM.Vin,Rx1h,Dg1h,Eff1h,A5,O1,O2,O3,O4,I1,I2,I3,I4",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               telemetry: %{
                 to: "FROMCALL",
                 parm: [
                   "Vin",
                   "Rx1h",
                   "Dg1h",
                   "Eff1h",
                   "A5",
                   "O1",
                   "O2",
                   "O3",
                   "O4",
                   "I1",
                   "I2",
                   "I3",
                   "I4"
                 ]
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Telemetry EQNS" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "FROMCALL>TOCALL::FROMCALL :EQNS.0,0.075,0,0,10,0,0,10,0,0,1,0,0,0,0"
               )

      assert %AprsParser{
               raw: "FROMCALL>TOCALL::FROMCALL :EQNS.0,0.075,0,0,10,0,0,10,0,0,1,0,0,0,0",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               telemetry: %{
                 to: "FROMCALL",
                 eqns: [
                   [0.0, 0.075, 0.0],
                   [0.0, 10.0, 0.0],
                   [0.0, 10.0, 0.0],
                   [0.0, 1.0, 0.0],
                   [0.0, 0.0, 0.0]
                 ]
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Telemetry Report" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:T#123,456,789,012,345,678,10101100Comment")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:T#123,456,789,012,345,678,10101100Comment",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               telemetry: %{
                 values: [456, 789, 12, 345, 678],
                 bits: [1, 0, 1, 0, 1, 1, 0, 0],
                 sequence_counter: 123
               },
               comment: "Comment"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Telemetry Report MIC" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:T#MIC,456,789,012,345,678,10101100Comment")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:T#MIC,456,789,012,345,678,10101100Comment",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               telemetry: %{
                 values: [456, 789, 12, 345, 678],
                 bits: [1, 0, 1, 0, 1, 1, 0, 0]
               },
               comment: "Comment"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Telemetry Report MIC w/o comma" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:T#MIC456,789,012,345,678,10101100Comment")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:T#MIC456,789,012,345,678,10101100Comment",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               telemetry: %{
                 values: [456, 789, 12, 345, 678],
                 bits: [1, 0, 1, 0, 1, 1, 0, 0]
               },
               comment: "Comment"
             } == expected_result
    end

    # ---------------------------------------------------------------
    # Location:	40°35.94' N 79°54.84' W
    # 2024-03-03 07:15:44 EST
    # Temperature:	44 °F
    # Humidity:	94 %
    # Pressure:	1020.5 mbar
    # Wind:	South 168° 0.0 MPH
    # Rain:	0.0 inches since midnight
    # Luminosity:	9 W/m²
    # ---------------------------------------------------------------
    test "Complete Weather Report" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "DW4636>APRS,TCPXX*,qAX,CWOP-5:@031215z4035.94N/07954.84W_168/000g...t044r...p...P000h94b10205L009.DsIP"
               )

      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("03"),
          String.to_integer("12"),
          String.to_integer("15"),
          0,
          0
        )
        |> elem(1)

      assert %AprsParser{
               raw:
                 "DW4636>APRS,TCPXX*,qAX,CWOP-5:@031215z4035.94N/07954.84W_168/000g...t044r...p...P000h94b10205L009.DsIP",
               from: "DW4636",
               to: "APRS",
               path: ["TCPXX*", "qAX", "CWOP-5"],
               position: %{
                 latitude: {40.599, :hundredth_minute},
                 longitude: {-79.914, :hundredth_minute},
                 timestamp: {expected_time, :sender_time},
                 symbol: "/_"
               },
               weather: %{
                 wind_direction: 168.0,
                 wind_speed: 0.0,
                 temperature: 6.666666666666667,
                 humidity: 94.0,
                 barometric_pressure: 1020.5,
                 rainfall_since_midnight: 0.0,
                 luminosity: 9.0,
                 device_type: ".DsIP"
               },
               comment: ""
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Complete Weather Report w/ compressed position" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "DW4636>APRS,TCPXX*,qAX,CWOP-5:!/:_z:6\'MX_22Kg...t029P000h46b10322"
               )

      assert %AprsParser{
               raw: "DW4636>APRS,TCPXX*,qAX,CWOP-5:!/:_z:6\'MX_22Kg...t029P000h46b10322",
               from: "DW4636",
               to: "APRS",
               path: ["TCPXX*", "qAX", "CWOP-5"],
               position: %{
                 latitude: {39.1743251970199, :hundredth_minute},
                 longitude: {-96.63086268724109, :hundredth_minute},
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 symbol: "/_"
               },
               weather: %{
                 wind_direction: 68.0,
                 wind_speed: 1.3890080881839764,
                 temperature: -1.6666666666666667,
                 humidity: 46.0,
                 barometric_pressure: 1032.2,
                 rainfall_since_midnight: 0.0
               },
               comment: ""
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 1: Weather report" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "EA5JMY-13>APRS,TCPIP*,qAC,T2UKRAINE:=3929.52N/00022.44W_.../...g...t063r...p...P...h43b10184"
               )

      assert %AprsParser{
               raw:
                 "EA5JMY-13>APRS,TCPIP*,qAC,T2UKRAINE:=3929.52N/00022.44W_.../...g...t063r...p...P...h43b10184",
               from: "EA5JMY-13",
               to: "APRS",
               path: ["TCPIP*", "qAC", "T2UKRAINE"],
               comment: "",
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 symbol: "/_",
                 latitude: {39.492, :hundredth_minute},
                 longitude: {-0.374, :hundredth_minute}
               },
               weather: %{
                 temperature: 17.22222222222222,
                 humidity: 43.0,
                 barometric_pressure: 1018.4000000000001
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 2: Unknown time indicator" do
      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("05"),
          String.to_integer("01"),
          String.to_integer("13"),
          0,
          0
        )
        |> elem(1)

      assert {:ok, expected_result} =
               AprsParser.parse(
                 "KE5JJC-10>APMI06,TUNKMT*,WIDE2-1,qAO,N7JCT-3:@050113#4849.53N/11839.03W-StorybookMtRanch,T=??.?F"
               )

      assert %AprsParser{
               raw:
                 "KE5JJC-10>APMI06,TUNKMT*,WIDE2-1,qAO,N7JCT-3:@050113#4849.53N/11839.03W-StorybookMtRanch,T=??.?F",
               from: "KE5JJC-10",
               to: "APMI06",
               path: ["TUNKMT*", "WIDE2-1", "qAO", "N7JCT-3"],
               comment: "StorybookMtRanch,T=??.?F",
               position: %{
                 timestamp: {expected_time, :sender_time},
                 symbol: "/-",
                 latitude: {48.8255, :hundredth_minute},
                 longitude: {-118.6505, :hundredth_minute}
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 3: Not a hurricane after /" do
      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("05"),
          String.to_integer("01"),
          String.to_integer("42"),
          0,
          0
        )
        |> elem(1)

      assert {:ok, expected_result} =
               AprsParser.parse(
                 "EA1GGY-1>APU25N,TCPIP*,qAS,EA1GGY:@050142z4250.99N/00618.85W_236/003g010t040r001p014P001h99b10022/ {UIV32N}"
               )

      assert %AprsParser{
               raw:
                 "EA1GGY-1>APU25N,TCPIP*,qAS,EA1GGY:@050142z4250.99N/00618.85W_236/003g010t040r001p014P001h99b10022/ {UIV32N}",
               from: "EA1GGY-1",
               to: "APU25N",
               path: ["TCPIP*", "qAS", "EA1GGY"],
               comment: "/ {UIV32N}",
               position: %{
                 latitude: {42.849833333333336, :hundredth_minute},
                 longitude: {-6.314166666666667, :hundredth_minute},
                 symbol: "/_",
                 timestamp: {expected_time, :sender_time}
               },
               weather: %{
                 wind_speed: 3.0,
                 wind_direction: 236.0,
                 gust_speed: 4.4704,
                 temperature: 4.444444444444445,
                 rainfall_last_hour: 2.54e-4,
                 rainfall_last_24_hours: 0.003556,
                 rainfall_since_midnight: 2.54e-4,
                 humidity: 99.0,
                 barometric_pressure: 1002.2
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 4: barometric pressure problem" do
      now = NaiveDateTime.utc_now()

      expected_time =
        NaiveDateTime.new(
          now.year,
          now.month,
          String.to_integer("05"),
          String.to_integer("01"),
          String.to_integer("51"),
          0,
          0
        )
        |> elem(1)

      assert {:ok, expected_result} =
               AprsParser.parse(
                 "VK3ARH-13>APRS,TCPIP*,qAS,VK3ARH:@050151z/aRhPrr5u_j/Cg007t080h22b9640"
               )

      assert %AprsParser{
               raw: "VK3ARH-13>APRS,TCPIP*,qAS,VK3ARH:@050151z/aRhPrr5u_j/Cg007t080h22b9640",
               from: "VK3ARH-13",
               to: "APRS",
               path: ["TCPIP*", "qAS", "VK3ARH"],
               position: %{
                 latitude: {-37.69099772659257, :hundredth_minute},
                 longitude: {144.00999669227093, :hundredth_minute},
                 symbol: "/_",
                 timestamp: {expected_time, :sender_time}
               },
               comment: "",
               weather: %{
                 barometric_pressure: 964.0,
                 gust_speed: 3.12928,
                 humidity: 22.0,
                 temperature: 26.666666666666668,
                 wind_direction: 292.0,
                 wind_speed: 0.9965776368376071
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 5: Telemetry not an integer problem" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "NS8C-6>APRX29,TCPIP*,qAS,NS8C-1:T#234,0.0,0.0,0.0,0.0,0.0,00000000"
               )

      assert %AprsParser{
               raw: "NS8C-6>APRX29,TCPIP*,qAS,NS8C-1:T#234,0.0,0.0,0.0,0.0,0.0,00000000",
               from: "NS8C-6",
               to: "APRX29",
               path: ["TCPIP*", "qAS", "NS8C-1"],
               position: %{timestamp: {NaiveDateTime.local_now(), :receiver_time}},
               comment: "",
               telemetry: %{
                 values: [0, 0, 0, 0, 0],
                 bits: [0, 0, 0, 0, 0, 0, 0, 0],
                 sequence_counter: 234
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 6: Seems to be inappropriately looking for a timestamp" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "SR9NDJ>APRX28,TCPIP*,qAC,T2RADOM:!5033.45NI01927.02E&PHG3280 Digi & IGate Jurajski W2,SPn by SQ9NFI on Linux operator SP9JKL ==> http://sq9nfi.pzk.pl"
               )

      assert %AprsParser{
               raw:
                 "SR9NDJ>APRX28,TCPIP*,qAC,T2RADOM:!5033.45NI01927.02E&PHG3280 Digi & IGate Jurajski W2,SPn by SQ9NFI on Linux operator SP9JKL ==> http://sq9nfi.pzk.pl",
               from: "SR9NDJ",
               to: "APRX28",
               path: ["TCPIP*", "qAC", "T2RADOM"],
               comment:
                 " Digi & IGate Jurajski W2,SPn by SQ9NFI on Linux operator SP9JKL ==> http://sq9nfi.pzk.pl",
               position: %{
                 timestamp: {NaiveDateTime.local_now(), :receiver_time},
                 directivity: :omnidirectional,
                 gain: 8.0,
                 height: 12.192,
                 latitude: {50.5575, :hundredth_minute},
                 longitude: {19.450333333333333, :hundredth_minute},
                 power: 9.0,
                 symbol: "I&"
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 7: Bad float in weather information" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "S59MA-6>APE4S1,WIDE1-1,WIDE2-1,qAR,S52SX:!4608.69N/01425.76E_248/000g000t044r000p999b09982h89PIC  WS-2300 Medvode"
               )

      assert %AprsParser{
               raw:
                 "S59MA-6>APE4S1,WIDE1-1,WIDE2-1,qAR,S52SX:!4608.69N/01425.76E_248/000g000t044r000p999b09982h89PIC  WS-2300 Medvode",
               from: "S59MA-6",
               to: "APE4S1",
               path: ["WIDE1-1", "WIDE2-1", "qAR", "S52SX"],
               comment: "PIC  WS-2300 Medvode",
               position: %{
                 latitude: {46.14483333333333, :hundredth_minute},
                 longitude: {14.429333333333334, :hundredth_minute},
                 symbol: "/_",
                 timestamp: {NaiveDateTime.local_now(), :receiver_time}
               },
               weather: %{
                 wind_direction: 248.0,
                 wind_speed: 0.0,
                 temperature: 6.666666666666667,
                 humidity: 89.0,
                 barometric_pressure: 998.2,
                 gust_speed: 0.0,
                 rainfall_last_hour: 0.0,
                 rainfall_last_24_hours: 0.25374599999999997
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Invalid paths" do
      assert {:error, _str} = AprsParser.parse("INVALID APRS DATA")
    end

    # ---------------------------------------------------------------
    test "Invalid ident byte" do
      assert {:error, _str} =
               AprsParser.parse("FROMCALL>TOCALL:~4903.50N/07201.75W-Test /A=001234")
    end
  end
end