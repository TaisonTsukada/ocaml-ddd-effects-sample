module Locator = User_api_port.Locator
module Port = User_api_port.System
module M = User_api_usecase.Health
open User_api_test_support.Fixture
module Mock = User_api_test_support.Mock

let result_t = Alcotest.result Alcotest.unit errors_t

let test_ok () =
  let inject : type a. a Locator.action -> a = function
    | Port.Ping -> Ok ()
    | _ -> failwith "unexpected action"
  in
  let actual = Mock.handle { inject } M.run in
  Alcotest.check' result_t ~msg:"生きている" ~expected:(Ok ()) ~actual

let test_down () =
  let inject : type a. a Locator.action -> a = function
    | Port.Ping -> Error (`InternalError "down")
    | _ -> failwith "unexpected action"
  in
  let actual = Mock.handle { inject } M.run in
  Alcotest.check' result_t ~msg:"落ちている"
    ~expected:(Error (`InternalError "down"))
    ~actual

let () =
  Alcotest.run "usecase/health"
    [
      ( "health",
        [
          Alcotest.test_case "正常" `Quick test_ok;
          Alcotest.test_case "異常" `Quick test_down;
        ] );
    ]
