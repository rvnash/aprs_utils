defmodule AprsParserTest do
  use ExUnit.Case
  alias APRSUtils.AprsParser

  defp now do
    NaiveDateTime.utc_now(:second)
  end

  defp local_now do
    now = NaiveDateTime.local_now()

    NaiveDateTime.new(now.year, now.month, now.day, now.hour, now.minute, now.second, 0)
    |> elem(1)
  end

  defp expected_time(month, day, hour, minute) do
    now = now()
    NaiveDateTime.new(now.year, month, day, hour, minute, 0, 0) |> elem(1)
  end

  defp expected_time(day, hour, minute) do
    now = now()
    NaiveDateTime.new(now.year, now.month, day, hour, minute, 0, 0) |> elem(1)
  end

  defp local_expected_time(day, hour, minute) do
    now = local_now()
    NaiveDateTime.new(now.year, now.month, day, hour, minute, 0, 0) |> elem(1)
  end

  describe "Tests trying to get best coverage of all packet types and variants" do
    # ---------------------------------------------------------------
    test "Position w/o timestamp, no path" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:!4903.50N/07201.75W-Test /A=001234")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:!4903.50N/07201.75W-Test /A=001234",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               timestamp: {now(), :receiver_time},
               symbol: "/-",
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute},
                 altitude: 376.1232
               },
               comment: "Test /A=001234"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, 8 path elements and local time" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "FROMCALL>TOCALL,1,2,3,4,5,6,7,8:/092345/4903.50N/07201.75W>Test1234"
               )

      assert %AprsParser{
               raw: "FROMCALL>TOCALL,1,2,3,4,5,6,7,8:/092345/4903.50N/07201.75W>Test1234",
               from: "FROMCALL",
               to: "TOCALL",
               path: ["1", "2", "3", "4", "5", "6", "7", "8"],
               timestamp: {local_expected_time(9, 23, 45), :sender_time},
               symbol: "/>",
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute}
               },
               comment: "Test1234"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, and Data Extension: Course/Speed" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:/092345z4903.50N/07201.75W>123/456")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:/092345z4903.50N/07201.75W>123/456",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               timestamp: {expected_time(9, 23, 45), :sender_time},
               symbol: "/>",
               course: %{
                 direction: 123.0,
                 speed: 234.586464
               },
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute}
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, and Data Extension: Course/Speed Bearing and Number/Range/Quality" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:/092345z4903.50N/07201.75W>088/036/270/729")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:/092345z4903.50N/07201.75W>088/036/270/729",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               timestamp: {expected_time(9, 23, 45), :sender_time},
               symbol: "/>",
               course: %{
                 direction: 88.0,
                 speed: 18.519984,
                 bearing: 270.0,
                 range: 6437.376,
                 bearing_accuracy: :less_than_1_degree,
                 report_quality: 7
               },
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute}
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, and Data Extension: PHG" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:/092345z4903.50N/07201.75W>PHG5132")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:/092345z4903.50N/07201.75W>PHG5132",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               timestamp: {expected_time(9, 23, 45), :sender_time},
               symbol: "/>",
               antenna: %{power: 25.0, height: 6.096, gain: 3.0, directivity: 90.0},
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute}
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, and Data Extension: RNG" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:/092345z4903.50N/07201.75W>RNG0050")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:/092345z4903.50N/07201.75W>RNG0050",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               timestamp: {expected_time(9, 23, 45), :sender_time},
               symbol: "/>",
               antenna: %{range: 80467.2},
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute}
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Position w/ timestamp, and Data Extension: DFS" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:/092345z4903.50N/07201.75W>DFS2132")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:/092345z4903.50N/07201.75W>DFS2132",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               timestamp: {expected_time(9, 23, 45), :sender_time},
               symbol: "/>",
               antenna: %{strength: 2.0, height: 6.096, gain: 3.0, directivity: 90.0},
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute}
               }
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
               timestamp: {now(), :receiver_time},
               symbol: "/-",
               position: %{
                 latitude: {49.166666666666664, :tenth_degree},
                 longitude: {-72.01833333333333, :tenth_minute},
                 altitude: 376.1232
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
               timestamp: {now(), :receiver_time},
               symbol: "/-",
               position: %{
                 latitude: {49.0, :degree},
                 longitude: {-72.01666666666667, :minute},
                 altitude: 376.1232
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
               timestamp: {now(), :receiver_time},
               symbol: "/O",
               position: %{
                 latitude: {64.11987367625208, :hundredth_minute},
                 longitude: {-19.070654142799384, :hundredth_minute},
                 altitude: 12450.7752
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
               timestamp: {now(), :receiver_time},
               symbol: "/O",
               course: %{
                 direction: 88.0,
                 speed: 18.63934126818573
               },
               position: %{
                 latitude: {64.11987367625208, :hundredth_minute},
                 longitude: {-19.070654142799384, :hundredth_minute},
                 altitude: 12450.7752
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
               timestamp: {now(), :receiver_time},
               symbol: "/O",
               position: %{
                 latitude: {64.11987367625208, :hundredth_minute},
                 longitude: {-19.070654142799384, :hundredth_minute},
                 altitude: 12450.7752,
                 range: 32388.552976978044
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
               timestamp: {now(), :receiver_time},
               symbol: "/O",
               position: %{
                 latitude: {64.11987367625208, :hundredth_minute},
                 longitude: {-19.070654142799384, :hundredth_minute},
                 altitude: 3049.3777114537656
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
               timestamp: {now(), :receiver_time},
               symbol: "/>",
               course: %{
                 direction: 251.0,
                 speed: 10.28888
               },
               position: %{
                 latitude: {33.42733333333334, :hundredth_minute},
                 longitude: {-12.129, :hundredth_minute},
                 altitude: 61.0
               },
               telemetry: %{sequence_counter: 7, values: [495, 629]},
               message: "Committed",
               device: "Byonics TinyTrack3"
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
               device: "Byonics TinyTrack3",
               path: ["KB3FCZ-2", "WIDE1*", "WIDE2-1", "qAR", "WA3YMM-1"],
               symbol: "/>",
               timestamp: {now(), :receiver_time},
               course: %{direction: 315.0, speed: 12.346656},
               position: %{
                 latitude: {40.351, :hundredth_minute},
                 longitude: {-79.82083333333334, :hundredth_minute},
                 altitude: 281.0
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
               symbol: "/[",
               timestamp: {now(), :receiver_time},
               course: %{direction: 305.0, speed: 0.0},
               position: %{
                 latitude: {35.58683333333333, :hundredth_minute},
                 longitude: {139.701, :hundredth_minute},
                 altitude: 8.0
               },
               device: "Yaesu VX-8",
               message: "Emergency"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Object" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:;LEADER   *092345z4903.50N/07201.75W>088/036")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:;LEADER   *092345z4903.50N/07201.75W>088/036",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               symbol: "/>",
               timestamp: {expected_time(9, 23, 45), :sender_time},
               course: %{direction: 88.0, speed: 18.519984},
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute}
               },
               object: %{
                 state: :alive,
                 name: "LEADER   "
               }
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
               symbol: "/>",
               timestamp: {now(), :receiver_time},
               course: %{direction: 88.0, speed: 18.519984},
               position: %{
                 latitude: {49.05833333333333, :hundredth_minute},
                 longitude: {-72.02916666666667, :hundredth_minute}
               },
               item: %{
                 state: :killed,
                 name: "ITEM"
               }
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
               timestamp: {now(), :receiver_time},
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
               timestamp: {now(), :receiver_time},
               symbol: "/-",
               position: %{
                 maidenhead: "IO91SX"
               },
               status: "status text"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Status Report w/ Timestamp" do
      assert {:ok, expected_result} =
               AprsParser.parse("FROMCALL>TOCALL:>092345zstatus text")

      assert %AprsParser{
               raw: "FROMCALL>TOCALL:>092345zstatus text",
               from: "FROMCALL",
               to: "TOCALL",
               path: [],
               timestamp: {expected_time(9, 23, 45), :sender_time},
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
               timestamp: {now(), :receiver_time},
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
               timestamp: {now(), :receiver_time},
               message: %{
                 addressee: "ADDRCALL ",
                 message: "message text",
                 message_no: "001"
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
               timestamp: {now(), :receiver_time},
               message: %{
                 addressee: "ADDRCALL ",
                 message: "ack",
                 message_no: "001"
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
               timestamp: {now(), :receiver_time},
               message: %{
                 addressee: "ADDRCALL ",
                 message: "rej",
                 message_no: "001"
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
               symbol: "I#",
               timestamp: {now(), :receiver_time},
               position: %{
                 latitude: {40.54216566997265, :hundredth_minute},
                 longitude: {-79.95600195313526, :hundredth_minute}
               },
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
               timestamp: {now(), :receiver_time},
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
               timestamp: {now(), :receiver_time},
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
               timestamp: {now(), :receiver_time},
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
               timestamp: {now(), :receiver_time},
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
               timestamp: {now(), :receiver_time},
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
               timestamp: {now(), :receiver_time},
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
               timestamp: {now(), :receiver_time},
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

      assert %AprsParser{
               raw:
                 "DW4636>APRS,TCPXX*,qAX,CWOP-5:@031215z4035.94N/07954.84W_168/000g...t044r...p...P000h94b10205L009.DsIP",
               from: "DW4636",
               to: "APRS",
               path: ["TCPXX*", "qAX", "CWOP-5"],
               timestamp: {expected_time(3, 12, 15), :sender_time},
               symbol: "/_",
               position: %{
                 latitude: {40.599, :hundredth_minute},
                 longitude: {-79.914, :hundredth_minute}
               },
               weather: %{
                 wind_direction: 168.0,
                 wind_speed: 0.0,
                 temperature: 6.666666666666667,
                 humidity: 94.0,
                 barometric_pressure: 1020.5,
                 rainfall_since_midnight: 0.0,
                 luminosity: 9.0,
                 software_type: "Unknown '.'",
                 wx_unit: "Unknown 'DsIP'"
               }
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
               timestamp: {now(), :receiver_time},
               symbol: "/_",
               position: %{
                 latitude: {39.1743251970199, :hundredth_minute},
                 longitude: {-96.63086268724109, :hundredth_minute}
               },
               weather: %{
                 wind_direction: 68.0,
                 wind_speed: 1.3890080881839764,
                 temperature: -1.6666666666666667,
                 humidity: 46.0,
                 barometric_pressure: 1032.2,
                 rainfall_since_midnight: 0.0
               }
             } == expected_result
    end
  end

  describe "Tests of error cases, expected to return errors" do
    # ---------------------------------------------------------------
    test "Invalid paths" do
      assert {:error, _str} = AprsParser.parse("INVALID APRS DATA")
    end

    # ---------------------------------------------------------------
    test "Invalid ident byte" do
      assert {:error, _str} =
               AprsParser.parse("FROMCALL>TOCALL:~4903.50N/07201.75W-Test /A=001234")
    end

    # ---------------------------------------------------------------
    test "Invalid object state identifier" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "WW4BSA-9>APBPQ1,TCPIP*,qAC,T2SJC:;WW4BSA*111111z3008.76N/08144.86W"
               )
    end

    # ---------------------------------------------------------------
    test "Error parsing latitude direction 'B'?" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "W1YK-1>APRS,WIDE,qAR,KY1U-2:!4216.47B/07148.43W#PHG5350 W2, WIDE1-1, WPIWA"
               )
    end

    # ---------------------------------------------------------------
    test "Error parsing longitude direction 'B'?" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "W1YK-1>APRS,WIDE,qAR,KY1U-2:!4216.47N/07148.43B#PHG5350 W2, WIDE1-1, WPIWA"
               )
    end

    # ---------------------------------------------------------------
    test "Error parsing latitude" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "DB0HWR-5>APNW01,F1ZJG-2*,F1ZRP-10*,WIDE2*,qAO,DB0UT-12:@052018z9!33.76N/10647.02E#DB0JWR APRS Digi Q21 Hochwald - Saar"
               )
    end

    # ---------------------------------------------------------------
    test "Error parsing longitude" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "DB0HWR-5>APNW01,F1ZJG-2*,F1ZRP-10*,WIDE2*,qAO,DB0UT-12:@052018z4933.76N/\x90\x90647.02E#DB0JWR APRS Digi Q21 Hochwald - Saar"
               )
    end

    # ---------------------------------------------------------------
    test "Non-numeric in time" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "IU4RXM>APBM1D,IR6UDA,DMR*,qAR,IR6UDA:@1601.0h4414.47N/01222.16E(238/000Simone"
               )
    end

    # ---------------------------------------------------------------
    test "Malformed packet, truncated in the middle of the longitude" do
      assert {:error, _reason} =
               AprsParser.parse("YM9ERZ>APRS,LOCAL,qAR,TA9A-12:!3949.98NW04118.")
    end

    # ---------------------------------------------------------------
    test "Invalid uncompressed position (not numbers)" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "NJ3T-3>APN382,WIDE1-1,qAR,N3DXC:;444.475-R*111111z40.13.58NE079.06.07W0SOMERSET CO ACS Group"
               )
    end

    # ---------------------------------------------------------------
    test "MIC-E parse issue" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "WIDE2>KD4PBS-3,qAR,N4JJS-1:`i.) #/ W2 APRS.RATS.NET Prince George,VA"
               )
    end

    test "Malformed uncompressed location" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "E22WWZ-13>APRX20,qAR,E24MSQ-13:!1400.24N/09932.97��AIa�WRT54GL&VP-DigiTNC > https://project.aprsindy.org"
               )

      assert {:error, _reason} =
               AprsParser.parse(
                 "E22WWZ-13>APRX20,qAR,E24MSQ-13:!1400.24N/09932.97\xa2\xaeAIa\x81WRT54GL&VP-DigiTNC > https://project.aprsindy.org"
               )
    end

    # ---------------------------------------------------------------
    test "Wacky Telemetry that aprs.fi actually parses in some way, seems nuts." do
      assert {:error, _reason} =
               AprsParser.parse(
                 "F1ZRP-13>APRS,F1ZRP-10*,WIDE1*,WIDE2-1,qAO,DB0UT-12:T#862,13.3,STHU,090,"
               )
    end

    # ---------------------------------------------------------------
    test "Invalid symbol crashes" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "9W2WBP-9>P3PRT9,9M2RKK-3*,WIDE2-1,qAR,9W2UUE-2:`m>4\"P\xaa\xbd]\"43}="
               )
    end

    # ---------------------------------------------------------------
    test "Crashes, but should just be invalid" do
      assert {:error, _reason} =
               AprsParser.parse(
                 "YM4KDI>APMI03,YM4KFT*,WIDE2-1,qAR,YM4KFE-10:@0\x9cL\x9a\x82\xd2\xcd647.94N/02900.25E# Batt U=12.7V.  Temp.=8.6 C"
               )
    end

    # ---------------------------------------------------------------
    test "Too short Mic-e TO field" do
      assert {:error, _reason} =
               AprsParser.parse("WB5LIV>K5PEW,WIDE1*,WIDE2-1,qAo,N5UKZ:`vTom6F>/`\"4\"}_%")
    end

    # ---------------------------------------------------------------
    test "Too long Mic-e TO field" do
      assert {:error, _reason} =
               AprsParser.parse("WB5LIV>K5PEWWW,WIDE1*,WIDE2-1,qAo,N5UKZ:`vTom6F>/`\"4\"}_%")
    end
  end

  describe "Tests of real packets picked up from APRS-IS which caused crashes" do
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
               timestamp: {now(), :receiver_time},
               symbol: "/_",
               position: %{
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
               timestamp: {expected_time(5, 1, 13), :sender_time},
               symbol: "/-",
               position: %{
                 latitude: {48.8255, :hundredth_minute},
                 longitude: {-118.6505, :hundredth_minute}
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 3: Not a hurricane after /" do
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
               symbol: "/_",
               timestamp: {expected_time(5, 1, 42), :sender_time},
               position: %{
                 latitude: {42.849833333333336, :hundredth_minute},
                 longitude: {-6.314166666666667, :hundredth_minute}
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
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "VK3ARH-13>APRS,TCPIP*,qAS,VK3ARH:@050151z/aRhPrr5u_j/Cg007t080h22b9640"
               )

      assert %AprsParser{
               raw: "VK3ARH-13>APRS,TCPIP*,qAS,VK3ARH:@050151z/aRhPrr5u_j/Cg007t080h22b9640",
               from: "VK3ARH-13",
               to: "APRS",
               path: ["TCPIP*", "qAS", "VK3ARH"],
               symbol: "/_",
               timestamp: {expected_time(5, 1, 51), :sender_time},
               position: %{
                 latitude: {-37.69099772659257, :hundredth_minute},
                 longitude: {144.00999669227093, :hundredth_minute}
               },
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
               timestamp: {now(), :receiver_time},
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
               timestamp: {now(), :receiver_time},
               antenna: %{power: 9.0, height: 12.192, gain: 8.0, directivity: :omnidirectional},
               position: %{
                 latitude: {50.5575, :hundredth_minute},
                 longitude: {19.450333333333333, :hundredth_minute}
               },
               symbol: "I&"
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
               symbol: "/_",
               timestamp: {now(), :receiver_time},
               position: %{
                 latitude: {46.14483333333333, :hundredth_minute},
                 longitude: {14.429333333333334, :hundredth_minute}
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
    test "Live test crash 8: Mic-e issu w/ the destination address" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "OE9IMJ-14>TW1VU8-2,WIDE1-1,WIDE2-1,qAR,OE9IMJ-10:`\dBvl\x1FC//\"8a}mou CT3863 S6 11.3C  959hPa 3.4V"
               )

      assert %AprsParser{
               raw:
                 "OE9IMJ-14>TW1VU8-2,WIDE1-1,WIDE2-1,qAR,OE9IMJ-10:`\dBvl\x1FC//\"8a}mou CT3863 S6 11.3C  959hPa 3.4V",
               from: "OE9IMJ-14",
               to: "TW1VU8-2",
               path: ["WIDE1-1", "WIDE2-1", "qAR", "OE9IMJ-10"],
               comment: "mou CT3863 S6 11.3C  959hPa 3.4V",
               message: "Priority",
               symbol: "//",
               timestamp: {now(), :receiver_time},
               course: %{direction: 339.0, speed: 0.0},
               position: %{
                 latitude: {47.27633333333333, :hundredth_minute},
                 longitude: {99.64833333333333, :hundredth_minute},
                 altitude: 438.0
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 9: Looks like a comment that is getting interpretted because it has a } in it" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "YO3FVR>APWW11,TCPIP*,qAC,T2SYDNEY::ANSRVR   :K SOTA SKYWARN SATELLITE BALLOONS WX WEATHER{DQ}"
               )

      assert %AprsParser{
               raw:
                 "YO3FVR>APWW11,TCPIP*,qAC,T2SYDNEY::ANSRVR   :K SOTA SKYWARN SATELLITE BALLOONS WX WEATHER{DQ}",
               from: "YO3FVR",
               to: "APWW11",
               path: ["TCPIP*", "qAC", "T2SYDNEY"],
               message: %{
                 message: "K SOTA SKYWARN SATELLITE BALLOONS WX WEATHER{DQ}",
                 addressee: "ANSRVR   "
               },
               timestamp: {now(), :receiver_time}
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 10: Empty EQNS" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "XE2MBE-10>APMI01,TCPIP*,qAS,XE2MBE::XE2MBE-10:EQNS.,,,,,,,,,,,,,,"
               )

      assert %AprsParser{
               raw: "XE2MBE-10>APMI01,TCPIP*,qAS,XE2MBE::XE2MBE-10:EQNS.,,,,,,,,,,,,,,",
               from: "XE2MBE-10",
               to: "APMI01",
               path: ["TCPIP*", "qAS", "XE2MBE"],
               timestamp: {now(), :receiver_time},
               telemetry: %{
                 to: "XE2MBE-10",
                 eqns: [
                   [0.0, 0.0, 0.0],
                   [0.0, 0.0, 0.0],
                   [0.0, 0.0, 0.0],
                   [0.0, 0.0, 0.0],
                   [0.0, 0.0, 0.0]
                 ]
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 11: Message number isn't always a number" do
      assert {:ok, expected_result} =
               AprsParser.parse("NWS-WARN>APRS,qAS,OE7XGR-10::SHVFLS   :rejJ00AA")

      assert %AprsParser{
               raw: "NWS-WARN>APRS,qAS,OE7XGR-10::SHVFLS   :rejJ00AA",
               from: "NWS-WARN",
               to: "APRS",
               path: ["qAS", "OE7XGR-10"],
               message: %{message: "rej", addressee: "SHVFLS   ", message_no: "J00AA"},
               timestamp: {now(), :receiver_time}
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 12: Mic-E problem w/ parsing to address encoded" do
      assert {:ok, expected_result} =
               AprsParser.parse("DL9OBG-9>UR5RW7,WIDE1-1,WIDE2-2,qAU,DL9OBG-11:`~3qofb>/")

      assert %AprsParser{
               raw: "DL9OBG-9>UR5RW7,WIDE1-1,WIDE2-2,qAU,DL9OBG-11:`~3qofb>/",
               from: "DL9OBG-9",
               to: "UR5RW7",
               path: ["WIDE1-1", "WIDE2-2", "qAU", "DL9OBG-11"],
               message: "Priority",
               device: "Original Mic-E",
               timestamp: {now(), :receiver_time},
               symbol: "/>",
               course: %{direction: 70.0, speed: 19.034428000000002},
               position: %{
                 latitude: {52.8795, :hundredth_minute},
                 longitude: {98.3975, :hundredth_minute}
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 13: Timestamp character 'a' is unrecognized" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "LX1CU-13>APMI06,TCPIP*,qAC,T2GYOR:@051739a4948.24ND00559.92E-WX3in1Plus2.0 U=12.1V,T=28.3C"
               )

      assert %AprsParser{
               raw:
                 "LX1CU-13>APMI06,TCPIP*,qAC,T2GYOR:@051739a4948.24ND00559.92E-WX3in1Plus2.0 U=12.1V,T=28.3C",
               from: "LX1CU-13",
               to: "APMI06",
               path: ["TCPIP*", "qAC", "T2GYOR"],
               comment: "WX3in1Plus2.0 U=12.1V,T=28.3C",
               symbol: "D-",
               timestamp: {expected_time(5, 17, 39), :sender_time},
               position: %{
                 latitude: {49.804, :hundredth_minute},
                 longitude: {5.998666666666667, :hundredth_minute}
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 14: .001 is not float" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "KX4O-13>APMI06,TCPIP*,qAS,KX4O::KX4O-13  :EQNS.0,0.075,0,0,1,0,0,1,0,0,1,0,0,.001,0"
               )

      assert %AprsParser{
               raw:
                 "KX4O-13>APMI06,TCPIP*,qAS,KX4O::KX4O-13  :EQNS.0,0.075,0,0,1,0,0,1,0,0,1,0,0,.001,0",
               from: "KX4O-13",
               to: "APMI06",
               path: ["TCPIP*", "qAS", "KX4O"],
               timestamp: {now(), :receiver_time},
               telemetry: %{
                 to: "KX4O-13",
                 eqns: [
                   [0.0, 0.075, 0.0],
                   [0.0, 1.0, 0.0],
                   [0.0, 1.0, 0.0],
                   [0.0, 1.0, 0.0],
                   [0.0, 0.001, 0.0]
                 ]
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 15: Get rid of pesky q constructs" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "DO7BTR-10>APLC13,qAS,DO9FK-3::DO7BTR-10:EQNS.0,0.1,0,0,0.1,0,0,0.1,0,qAR,DO9FK-3"
               )

      assert %AprsParser{
               raw:
                 "DO7BTR-10>APLC13,qAS,DO9FK-3::DO7BTR-10:EQNS.0,0.1,0,0,0.1,0,0,0.1,0,qAR,DO9FK-3",
               from: "DO7BTR-10",
               to: "APLC13",
               path: ["qAS", "DO9FK-3"],
               timestamp: {now(), :receiver_time},
               telemetry: %{
                 eqns: [[0.0, 0.1, 0.0], [0.0, 0.1, 0.0], [0.0, 0.1, 0.0]],
                 to: "DO7BTR-10"
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 16: Problem parsing Telemetry with a sixth channel" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "AG1T-20>APRS,TCPIP*,qAC,SIXTH:T#336,134,241,142,036,000,000,01100000"
               )

      assert %AprsParser{
               raw: "AG1T-20>APRS,TCPIP*,qAC,SIXTH:T#336,134,241,142,036,000,000,01100000",
               from: "AG1T-20",
               to: "APRS",
               path: ["TCPIP*", "qAC", "SIXTH"],
               timestamp: {now(), :receiver_time},
               telemetry: %{
                 bits: [0, 1, 1, 0, 0, 0, 0, 0],
                 sequence_counter: 336,
                 values: [134, 241, 142, 36, 0]
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test crash 17: Status report issue" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "SP2PMK>APN100,TCPIP*,qAC,T2POLAND:>Zapraszamy w ka\xc5\xbcdy poniedzia\xc5\x82ek o 18:00 "
               )

      assert %AprsParser{
               raw: "SP2PMK>APN100,TCPIP*,qAC,T2POLAND:>Zapraszamy w każdy poniedziałek o 18:00 ",
               from: "SP2PMK",
               to: "APN100",
               path: ["TCPIP*", "qAC", "T2POLAND"],
               timestamp: {now(), :receiver_time},
               status: "Zapraszamy w każdy poniedziałek o 18:00 "
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test 18: Should process this Telemetry report" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "EL-IK8TGH>RXTLM-1,TCPIP,qAR,IK8TGH:T#342,1.50,0.00,0,1,0.0,00000000,ORP_SimplexLogic_Port1"
               )

      assert %AprsParser{
               raw:
                 "EL-IK8TGH>RXTLM-1,TCPIP,qAR,IK8TGH:T#342,1.50,0.00,0,1,0.0,00000000,ORP_SimplexLogic_Port1",
               from: "EL-IK8TGH",
               to: "RXTLM-1",
               path: ["TCPIP", "qAR", "IK8TGH"],
               comment: "ORP_SimplexLogic_Port1",
               timestamp: {now(), :receiver_time},
               telemetry: %{
                 values: [1.5, 0.0, 0, 1, 0.0],
                 bits: [0, 0, 0, 0, 0, 0, 0, 0],
                 sequence_counter: 342
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test 19: Should process TO/FROM/PATH" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "IW3SRV-5>T5TV82,S53UAN-10*,WIDE1*,WIDE2-1,qAR,S58W-10:`)?\x1fl \x1cs/>\"3v}"
               )

      assert %AprsParser{
               raw: "IW3SRV-5>T5TV82,S53UAN-10*,WIDE1*,WIDE2-1,qAR,S58W-10:`)?\x1Fl \x1Cs/>\"3v}",
               from: "IW3SRV-5",
               to: "T5TV82",
               path: ["S53UAN-10*", "WIDE1*", "WIDE2-1", "qAR", "S58W-10"],
               message: "Special",
               timestamp: {now(), :receiver_time},
               symbol: "/s",
               course: %{direction: 0.0, speed: 0.0},
               position: %{
                 altitude: 4.0,
                 latitude: {45.78033333333333, :hundredth_minute},
                 longitude: {13.583833333333333, :hundredth_minute}
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test 20: aprs.fi seems to be very flexible about parsing out of spec telemetry reports" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "IR1UFB>APMI06,TCPIP*,qAC,T2CSNGRAD:T#027,233,130,017,00154,081,00000000"
               )

      assert %AprsParser{
               raw: "IR1UFB>APMI06,TCPIP*,qAC,T2CSNGRAD:T#027,233,130,017,00154,081,00000000",
               from: "IR1UFB",
               to: "APMI06",
               path: ["TCPIP*", "qAC", "T2CSNGRAD"],
               timestamp: {now(), :receiver_time},
               telemetry: %{
                 values: [233, 130, 17, 154, 81],
                 bits: [0, 0, 0, 0, 0, 0, 0, 0],
                 sequence_counter: 27
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test 21: Apparently Lat/Long directions can be lower case" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "LAGRNG>APN391,qAR,KA5WMY-5:!2952.51NS09653.75w#PHG5370 LaGrange, TX Digipeater - KA5WMY"
               )

      assert %AprsParser{
               raw:
                 "LAGRNG>APN391,qAR,KA5WMY-5:!2952.51NS09653.75w#PHG5370 LaGrange, TX Digipeater - KA5WMY",
               from: "LAGRNG",
               to: "APN391",
               path: ["qAR", "KA5WMY-5"],
               comment: " LaGrange, TX Digipeater - KA5WMY",
               timestamp: {now(), :receiver_time},
               antenna: %{
                 directivity: :omnidirectional,
                 gain: 7.0,
                 power: 25.0,
                 height: 24.384
               },
               position: %{
                 latitude: {29.875166666666665, :hundredth_minute},
                 longitude: {-96.89583333333333, :hundredth_minute}
               },
               symbol: "S#"
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test 22: Unimplemented Data Type identifier _ for weather" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "KB2TSV>APW280,WIDE2-1,qAR,W3ZO-10:_03062214c000s255g255t076r000p000P000h00b00000wDVP"
               )

      assert %AprsParser{
               raw:
                 "KB2TSV>APW280,WIDE2-1,qAR,W3ZO-10:_03062214c000s255g255t076r000p000P000h00b00000wDVP",
               from: "KB2TSV",
               to: "APW280",
               path: ["WIDE2-1", "qAR", "W3ZO-10"],
               timestamp: {expected_time(3, 6, 22, 14), :sender_time},
               weather: %{
                 wind_speed: 113.9952,
                 wind_direction: 0.0,
                 gust_speed: 113.9952,
                 temperature: 24.444444444444446,
                 rainfall_last_hour: 0.0,
                 rainfall_last_24_hours: 0.0,
                 rainfall_since_midnight: 0.0,
                 humidity: 0.0,
                 barometric_pressure: 0.0,
                 wx_unit: "Unknown 'DVP'",
                 software_type: "Unknown 'w'"
               }
             } == expected_result
    end

    # ---------------------------------------------------------------
    test "Live test 23: Raw gps data" do
      assert {:ok, expected_result} =
               AprsParser.parse(
                 "NE4SC-12>APRS,WIDE2-2,qAR,KW4BET-3:$ULTW0000000000FD00002805000E8938000103710165045B00000000"
               )

      assert %AprsParser{
               raw:
                 "NE4SC-12>APRS,WIDE2-2,qAR,KW4BET-3:$ULTW0000000000FD00002805000E8938000103710165045B00000000",
               from: "NE4SC-12",
               to: "APRS",
               path: ["WIDE2-2", "qAR", "KW4BET-3"],
               timestamp: {now(), :receiver_time},
               raw_gps: "ULTW0000000000FD00002805000E8938000103710165045B00000000"
             } == expected_result
    end
  end

  # ---------------------------------------------------------------
  test "Live test 24: aprs.fi allows empty fields in telemetry reports (and fewer than 8 bits in the digital value field)" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "VU2IB-13>APRS,TCPIP*,qAC,T2CS:T#050,250,055,000,045,,1110,Solar Power WX Station"
             )

    assert %AprsParser{
             raw:
               "VU2IB-13>APRS,TCPIP*,qAC,T2CS:T#050,250,055,000,045,,1110,Solar Power WX Station",
             from: "VU2IB-13",
             to: "APRS",
             path: ["TCPIP*", "qAC", "T2CS"],
             comment: "Solar Power WX Station",
             timestamp: {now(), :receiver_time},
             telemetry: %{
               values: [250, 55, 0, 45],
               bits: [1, 1, 1, 0],
               sequence_counter: 50
             }
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 25: Weather parsing is still rejecting too many parameter lists 1" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "DB0BIN>APGE01,TCPIP*,qAC,T2CSNGRAD:!4818.27N/00845.69E_180/000g...t038r...p000h100b10155"
             )

    assert %AprsParser{
             raw:
               "DB0BIN>APGE01,TCPIP*,qAC,T2CSNGRAD:!4818.27N/00845.69E_180/000g...t038r...p000h100b10155",
             from: "DB0BIN",
             to: "APGE01",
             path: ["TCPIP*", "qAC", "T2CSNGRAD"],
             timestamp: {now(), :receiver_time},
             symbol: "/_",
             position: %{
               latitude: {48.3045, :hundredth_minute},
               longitude: {8.7615, :hundredth_minute}
             },
             weather: %{
               wind_direction: 180.0,
               wind_speed: 0.0,
               temperature: 3.3333333333333335,
               humidity: 100.0,
               barometric_pressure: 1015.5,
               rainfall_last_24_hours: 0.0
             }
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 26: aprs.fi accepts 3 digits for humidity" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "OK1IRG-6>APRSWX,TCPIP*,qAC,T2CZECH:=5022.73N/01345.88E_045/006g010t041h057b101332P000"
             )

    assert %AprsParser{
             raw:
               "OK1IRG-6>APRSWX,TCPIP*,qAC,T2CZECH:=5022.73N/01345.88E_045/006g010t041h057b101332P000",
             to: "APRSWX",
             from: "OK1IRG-6",
             path: ["TCPIP*", "qAC", "T2CZECH"],
             timestamp: {now(), :receiver_time},
             symbol: "/_",
             position: %{
               latitude: {50.37883333333333, :hundredth_minute},
               longitude: {13.764666666666667, :hundredth_minute}
             },
             weather: %{
               wind_direction: 45.0,
               wind_speed: 6.0,
               temperature: 5.0,
               humidity: 57.0,
               gust_speed: 4.4704,
               barometric_pressure: 10133.2,
               rainfall_since_midnight: 0.0
             }
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 27: Weather parsing is still rejecting too many parameter lists 3" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "9M8ZAL-12>APRS,TCPIP*,qAC,T2LAUSITZ:=0139.24N/11012.10E_.../...g...t088r...p...P...h99b10082L000APRSuWX 0.1.7h | Malaysia microWX Node | KV50S| AC-powered: 5.00 volts"
             )

    assert %AprsParser{
             raw:
               "9M8ZAL-12>APRS,TCPIP*,qAC,T2LAUSITZ:=0139.24N/11012.10E_.../...g...t088r...p...P...h99b10082L000APRSuWX 0.1.7h | Malaysia microWX Node | KV50S| AC-powered: 5.00 volts",
             from: "9M8ZAL-12",
             to: "APRS",
             path: ["TCPIP*", "qAC", "T2LAUSITZ"],
             comment: "APRSuWX 0.1.7h | Malaysia microWX Node  AC-powered: 5.00 volts",
             timestamp: {now(), :receiver_time},
             symbol: "/_",
             position: %{
               latitude: {1.654, :hundredth_minute},
               longitude: {110.20166666666667, :hundredth_minute}
             },
             raw_gps: nil,
             status: nil,
             telemetry: %{values: [4843, 1415], sequence_counter: -49},
             weather: %{
               temperature: 31.111111111111114,
               humidity: 99.0,
               barometric_pressure: 1008.2,
               luminosity: 0.0
             }
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 28: Weather parsing is still rejecting too many parameter lists 4" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "HB9SZU-6>APYSNR,TCPIP*,qAS,HB9SZU:@071558z4611.51N/00901.48E_.../...g...t056r000P000b10182h52Node-RED WX Station Bellinzona"
             )

    assert %AprsParser{
             comment: "Node-RED WX Station Bellinzona",
             raw:
               "HB9SZU-6>APYSNR,TCPIP*,qAS,HB9SZU:@071558z4611.51N/00901.48E_.../...g...t056r000P000b10182h52Node-RED WX Station Bellinzona",
             from: "HB9SZU-6",
             to: "APYSNR",
             path: ["TCPIP*", "qAS", "HB9SZU"],
             timestamp: {expected_time(7, 15, 58), :sender_time},
             symbol: "/_",
             position: %{
               latitude: {46.191833333333335, :hundredth_minute},
               longitude: {9.024666666666667, :hundredth_minute}
             },
             weather: %{
               temperature: 13.333333333333334,
               rainfall_last_hour: 0.0,
               rainfall_since_midnight: 0.0,
               humidity: 52.0,
               barometric_pressure: 1018.2
             }
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 29: Bad weather data, 't' parameter too long in this case, so it is extracted as a comment" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "KB2TSV>APW280,WIDE2-1,qAR,W3ZO-10:_03062214c000s255g255t3276r000p000P000h00b00000wDVP"
             )

    assert %AprsParser{
             raw:
               "KB2TSV>APW280,WIDE2-1,qAR,W3ZO-10:_03062214c000s255g255t3276r000p000P000h00b00000wDVP",
             from: "KB2TSV",
             to: "APW280",
             path: ["WIDE2-1", "qAR", "W3ZO-10"],
             comment: "6r000p000P000h00b00000wDVP",
             timestamp: {expected_time(3, 6, 22, 14), :sender_time},
             weather: %{
               temperature: 163.88888888888889,
               gust_speed: 113.9952,
               wind_direction: 0.0,
               wind_speed: 113.9952
             }
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 30: aprs.fi allows no digital data at all in the telemetry" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "IZ1DNG-10>WIDE1-1,WIDE2-2,qAR,IR1UFB:T#55,184,130,165,126,1>/A=10731"
             )

    assert %AprsParser{
             raw: "IZ1DNG-10>WIDE1-1,WIDE2-2,qAR,IR1UFB:T#55,184,130,165,126,1>/A=10731",
             comment: ">/A=10731",
             from: "IZ1DNG-10",
             to: "WIDE1-1",
             path: ["WIDE2-2", "qAR", "IR1UFB"],
             timestamp: {now(), :receiver_time},
             telemetry: %{bits: [1], sequence_counter: 55, values: [184, 130, 165, 126]}
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 31: Telemetry issue to take care of" do
    assert {:ok, expected_result} =
             AprsParser.parse("DK9CL-10>APZES,TCPIP*,qAC,T2PERTH:T#52,0,0,0,0,0,00000000")

    assert %AprsParser{
             raw: "DK9CL-10>APZES,TCPIP*,qAC,T2PERTH:T#52,0,0,0,0,0,00000000",
             from: "DK9CL-10",
             to: "APZES",
             path: ["TCPIP*", "qAC", "T2PERTH"],
             timestamp: {now(), :receiver_time},
             telemetry: %{
               bits: [0, 0, 0, 0, 0, 0, 0, 0],
               sequence_counter: 52,
               values: [0, 0, 0, 0, 0]
             }
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 32: Don't use String.to_charlist, use :erlang.binary_to_list" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "2E1GRY-9>UQTXYS,WIDE1-1,qAR,M1DYP:`v(Ol?s</\"5/}Hello 3.92V  24.6C X|\x82r!')3%=!,|"
             )

    assert %AprsParser{
             raw:
               "2E1GRY-9>UQTXYS,WIDE1-1,qAR,M1DYP:`v(Ol?s</\"5/}Hello 3.92V  24.6C X|\x82r!')3%=!,|",
             from: "2E1GRY-9",
             to: "UQTXYS",
             path: ["WIDE1-1", "qAR", "M1DYP"],
             message: "Emergency",
             comment: "Hello 3.92V  24.6C X",
             course: %{direction: 187.0, speed: 1.543332},
             position: %{
               latitude: {51.8155, :hundredth_minute},
               longitude: {-90.2085, :hundredth_minute},
               altitude: 115.0
             },
             symbol: "/<",
             telemetry: %{sequence_counter: 8908, values: [6, 746, 392, 11]},
             timestamp: {now(), :receiver_time}
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 33: Two : screw things up" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "W7PMA-9>T3STVQ,WAREAG,WIDE1*,WIDE2-1,qAR,KK7NWN-1:`,1hl :R/'|\"R&*'9|!w`{!|3"
             )

    assert %AprsParser{
             raw: "W7PMA-9>T3STVQ,WAREAG,WIDE1*,WIDE2-1,qAR,KK7NWN-1:`,1hl :R/'|\"R&*'9|!w`{!|3",
             from: "W7PMA-9",
             to: "T3STVQ",
             path: ["WAREAG", "WIDE1*", "WIDE2-1", "qAR", "KK7NWN-1"],
             device: "Byonics TinyTrack3",
             message: "Special",
             course: %{direction: 30.0, speed: 0.0},
             position: %{
               latitude: {43.57683333333333, :hundredth_minute},
               longitude: {-116.36266666666667, :hundredth_minute}
             },
             symbol: "/R",
             telemetry: %{sequence_counter: 140, values: [464, 570]},
             timestamp: {now(), :receiver_time}
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 34: aprs.fi parses this" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "VK6HGR-1>APRS,TCPIP*,qAC,T2SYDNEY::VK6HGR-1 :EQNS.0,1,0,0,1,0,0,1,0,,,,,a"
             )

    assert %AprsParser{
             raw: "VK6HGR-1>APRS,TCPIP*,qAC,T2SYDNEY::VK6HGR-1 :EQNS.0,1,0,0,1,0,0,1,0,,,,,a",
             from: "VK6HGR-1",
             to: "APRS",
             path: ["TCPIP*", "qAC", "T2SYDNEY"],
             telemetry: %{
               eqns: [[0.0, 1.0, 0.0], [0.0, 1.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 0.0]],
               to: "VK6HGR-1"
             },
             timestamp: {now(), :receiver_time}
           } == expected_result
  end

  # ---------------------------------------------------------------
  test "Live test 35: Really long addresses paths. aprs.fi seems to have no limit, spec says 0 .. 8" do
    assert {:ok, expected_result} =
             AprsParser.parse(
               "OV5BBS>U5RU27,OZ9DIE-2,WIDE1,OV7B-1,OZ6HR-2,OZ7CER-1,WIDE1*,QAR,OZ4DIC-2,qAR,OZ7GZ:`&5al <0x1c>n\>PACKET BBS I ODENSE"
             )

    assert %AprsParser{
             raw:
               "OV5BBS>U5RU27,OZ9DIE-2,WIDE1,OV7B-1,OZ6HR-2,OZ7CER-1,WIDE1*,QAR,OZ4DIC-2,qAR,OZ7GZ:`&5al <0x1c>n>PACKET BBS I ODENSE",
             from: "OV5BBS",
             to: "U5RU27",
             path: [
               "OZ9DIE-2",
               "WIDE1",
               "OV7B-1",
               "OZ6HR-2",
               "OZ7CER-1",
               "WIDE1*",
               "QAR",
               "OZ4DIC-2",
               "qAR",
               "OZ7GZ"
             ],
             message: "Special",
             comment: "1c>n>PACKET BBS I ODENSE",
             course: %{speed: 0.0, direction: 32.0},
             position: %{
               latitude: {55.421166666666664, :hundredth_minute},
               longitude: {10.428166666666666, :hundredth_minute}
             },
             symbol: "x0",
             timestamp: {now(), :receiver_time}
           } == expected_result
  end
end
