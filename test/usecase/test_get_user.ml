module Locator = User_api_port.Locator
module Port = User_api_port.User_repository
module M = User_api_usecase.Get_user
open User_api_test_support.Fixture
module Mock = User_api_test_support.Mock

let result_t = Alcotest.result user_t errors_t

let test_found () =
  let fixture = user ~id:7 () in
  let inject : type a. a Locator.action -> a = function
    | Port.Find_by_id { id } ->
        Alcotest.check' id_t ~msg:"same id" ~expected:(id_of 7) ~actual:id;
        Ok (Some fixture)
    | _ -> failwith "unexpected action"
  in
  let actual = Mock.handle { inject } (fun () -> M.run ~id:(id_of 7)) in
  Alcotest.check' result_t ~msg:"取得できる" ~expected:(Ok fixture) ~actual

let test_not_found () =
  let inject : type a. a Locator.action -> a = function
    | Port.Find_by_id _ -> Ok None
    | _ -> failwith "unexpected action"
  in
  let actual = Mock.handle { inject } (fun () -> M.run ~id:(id_of 404)) in
  Alcotest.check' result_t ~msg:"Port の None はドメインのエラーに翻訳される"
    ~expected:(Error (`NotFound "user"))
    ~actual

let test_failure_is_propagated () =
  let inject : type a. a Locator.action -> a = function
    | Port.Find_by_id _ -> Error (`InternalError "boom")
    | _ -> failwith "unexpected action"
  in
  let actual = Mock.handle { inject } (fun () -> M.run ~id:(id_of 1)) in
  Alcotest.check' result_t ~msg:"そのまま伝播する"
    ~expected:(Error (`InternalError "boom"))
    ~actual

let () =
  Alcotest.run "usecase/get_user"
    [
      ( "get_user",
        [
          Alcotest.test_case "見つかる" `Quick test_found;
          Alcotest.test_case "見つからない" `Quick test_not_found;
          Alcotest.test_case "失敗の伝播" `Quick test_failure_is_propagated;
        ] );
    ]
