module Locator = User_api_port.Locator
module Port = User_api_port.User_repository
module M = User_api_usecase.Register_user
open User_api_test_support.Fixture
module Mock = User_api_test_support.Mock

let result_t = Alcotest.result user_t errors_t

let test_ok () =
  let fixture = user () in
  let created = ref false in
  let inject : type a. a Locator.action -> a = function
    | Port.Find_by_email { email } ->
        Alcotest.check' email_t ~msg:"重複確認は入力のメールで行う"
          ~expected:(email_of "nymphium@example.com")
          ~actual:email;
        Ok None
    | Port.Create { name; email } ->
        created := true;
        Alcotest.check' name_t ~msg:"same name" ~expected:(name_of "nymphium")
          ~actual:name;
        Alcotest.check' email_t ~msg:"same email"
          ~expected:(email_of "nymphium@example.com")
          ~actual:email;
        Ok fixture
    | _ -> failwith "unexpected action"
  in
  let actual =
    Mock.handle { inject } (fun () ->
        M.run ~name:(name_of "nymphium")
          ~email:(email_of "nymphium@example.com"))
  in
  Alcotest.check' result_t ~msg:"登録できる" ~expected:(Ok fixture) ~actual;
  Alcotest.check' Alcotest.bool ~msg:"Create が呼ばれた" ~expected:true
    ~actual:!created

let test_duplicated_email () =
  let inject : type a. a Locator.action -> a = function
    | Port.Find_by_email _ -> Ok (Some (user ()))
    | Port.Create _ -> Alcotest.fail "重複時に Create を呼んではいけない"
    | _ -> failwith "unexpected action"
  in
  let actual =
    Mock.handle { inject } (fun () ->
        M.run ~name:(name_of "nymphium")
          ~email:(email_of "nymphium@example.com"))
  in
  Alcotest.check' result_t ~msg:"409 相当"
    ~expected:(Error (`Conflict "email"))
    ~actual

let test_repository_failure_is_propagated () =
  let inject : type a. a Locator.action -> a = function
    | Port.Find_by_email _ -> Error (`InternalError "boom")
    | Port.Create _ -> Alcotest.fail "失敗後に Create を呼んではいけない"
    | _ -> failwith "unexpected action"
  in
  let actual =
    Mock.handle { inject } (fun () ->
        M.run ~name:(name_of "nymphium")
          ~email:(email_of "nymphium@example.com"))
  in
  Alcotest.check' result_t ~msg:"そのまま伝播する"
    ~expected:(Error (`InternalError "boom"))
    ~actual

let test_create_failure_is_propagated () =
  let inject : type a. a Locator.action -> a = function
    | Port.Find_by_email _ -> Ok None
    | Port.Create _ -> Error (`Conflict "email")
    | _ -> failwith "unexpected action"
  in
  let actual =
    Mock.handle { inject } (fun () ->
        M.run ~name:(name_of "nymphium")
          ~email:(email_of "nymphium@example.com"))
  in
  Alcotest.check' result_t ~msg:"ストア側の一意制約違反も伝播する"
    ~expected:(Error (`Conflict "email"))
    ~actual

let () =
  Alcotest.run "usecase/register_user"
    [
      ( "register_user",
        [
          Alcotest.test_case "正常系" `Quick test_ok;
          Alcotest.test_case "メール重複" `Quick test_duplicated_email;
          Alcotest.test_case "検索失敗の伝播" `Quick
            test_repository_failure_is_propagated;
          Alcotest.test_case "登録失敗の伝播" `Quick test_create_failure_is_propagated;
        ] );
    ]
