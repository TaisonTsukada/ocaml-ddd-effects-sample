module Locator = User_api_port.Locator
module User_port = User_api_port.User_port
module M = User_api_usecase.Get_user
module User = User_api_domain.Objects.User
open User_api_test_support.Fixture
module Mock = User_api_test_support.Mock

let outcome_t =
  let pp fmt = function
    | M.Found user -> Format.fprintf fmt "Found %a" User.pp user
    | M.Missing -> Format.pp_print_string fmt "Missing"
  in
  let equal a b =
    match (a, b) with
    | M.Found a, M.Found b -> User.equal a b
    | M.Missing, M.Missing -> true
    | _ -> false
  in
  Alcotest.testable pp equal

let test_found () =
  let fixture = user ~id:7 () in
  let inject : type a. a Locator.action -> a = function
    | User_port.Find_by_id { id } ->
        Alcotest.check' id_t ~msg:"same id" ~expected:(id_of 7) ~actual:id;
        Some fixture
    | _ -> failwith "unexpected action"
  in
  let actual = Mock.handle { inject } (fun () -> M.run ~id:(id_of 7)) in
  Alcotest.check' outcome_t ~msg:"取得できる" ~expected:(M.Found fixture) ~actual

let test_not_found () =
  let inject : type a. a Locator.action -> a = function
    | User_port.Find_by_id _ -> None
    | _ -> failwith "unexpected action"
  in
  let actual = Mock.handle { inject } (fun () -> M.run ~id:(id_of 404)) in
  Alcotest.check' outcome_t ~msg:"Port の None はこのユースケースの Missing になる"
    ~expected:M.Missing ~actual

(* Driver が落ちたときは result で持ち回らず例外がそのまま外へ抜ける。 *)
let test_failure_is_not_caught () =
  let inject : type a. a Locator.action -> a = function
    | User_port.Find_by_id _ -> failwith "boom"
    | _ -> failwith "unexpected action"
  in
  Alcotest.check_raises "そのまま抜ける" (Failure "boom") (fun () ->
      ignore (Mock.handle { inject } (fun () -> M.run ~id:(id_of 1))))

let () =
  Alcotest.run "usecase/get_user"
    [
      ( "get_user",
        [
          Alcotest.test_case "見つかる" `Quick test_found;
          Alcotest.test_case "見つからない" `Quick test_not_found;
          Alcotest.test_case "失敗は捕まえない" `Quick test_failure_is_not_caught;
        ] );
    ]
