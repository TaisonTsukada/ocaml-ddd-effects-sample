module Locator = User_api_port.Locator
module User_port = User_api_port.User_port
module M = User_api_usecase.Register_user
module User = User_api_domain.Objects.User
open User_api_test_support.Fixture
module Mock = User_api_test_support.Mock

let outcome_t =
  let pp fmt = function
    | M.Registered user -> Format.fprintf fmt "Registered %a" User.pp user
    | M.Email_taken -> Format.pp_print_string fmt "Email_taken"
  in
  let equal a b =
    match (a, b) with
    | M.Registered a, M.Registered b -> User.equal a b
    | M.Email_taken, M.Email_taken -> true
    | _ -> false
  in
  Alcotest.testable pp equal

let test_ok () =
  let fixture = user () in
  let created = ref false in
  let inject : type a. a Locator.action -> a = function
    | User_port.Find_by_email { email } ->
        Alcotest.check' email_t ~msg:"重複確認は入力のメールで行う"
          ~expected:(email_of "nymphium@example.com")
          ~actual:email;
        None
    | User_port.Create { name; email } ->
        created := true;
        Alcotest.check' name_t ~msg:"same name" ~expected:(name_of "nymphium")
          ~actual:name;
        Alcotest.check' email_t ~msg:"same email"
          ~expected:(email_of "nymphium@example.com")
          ~actual:email;
        fixture
    | _ -> failwith "unexpected action"
  in
  let actual =
    Mock.handle { inject } (fun () ->
        M.run ~name:(name_of "nymphium")
          ~email:(email_of "nymphium@example.com"))
  in
  Alcotest.check' outcome_t ~msg:"登録できる" ~expected:(M.Registered fixture)
    ~actual;
  Alcotest.check' Alcotest.bool ~msg:"Create が呼ばれた" ~expected:true
    ~actual:!created

let test_duplicated_email () =
  let inject : type a. a Locator.action -> a = function
    | User_port.Find_by_email _ -> Some (user ())
    | User_port.Create _ -> Alcotest.fail "重複時に Create を呼んではいけない"
    | _ -> failwith "unexpected action"
  in
  let actual =
    Mock.handle { inject } (fun () ->
        M.run ~name:(name_of "nymphium")
          ~email:(email_of "nymphium@example.com"))
  in
  Alcotest.check' outcome_t ~msg:"重複はエラーではなく結果のひとつ" ~expected:M.Email_taken
    ~actual

(* Driver が落ちたときは result で持ち回らず例外がそのまま外へ抜ける。 *)
let test_lookup_failure_is_not_caught () =
  let inject : type a. a Locator.action -> a = function
    | User_port.Find_by_email _ -> failwith "boom"
    | User_port.Create _ -> Alcotest.fail "失敗後に Create を呼んではいけない"
    | _ -> failwith "unexpected action"
  in
  Alcotest.check_raises "そのまま抜ける" (Failure "boom") (fun () ->
      ignore
        (Mock.handle { inject } (fun () ->
             M.run ~name:(name_of "nymphium")
               ~email:(email_of "nymphium@example.com"))))

let test_create_failure_is_not_caught () =
  let inject : type a. a Locator.action -> a = function
    | User_port.Find_by_email _ -> None
    | User_port.Create _ -> failwith "boom"
    | _ -> failwith "unexpected action"
  in
  Alcotest.check_raises "ストア側の失敗も握りつぶさない" (Failure "boom") (fun () ->
      ignore
        (Mock.handle { inject } (fun () ->
             M.run ~name:(name_of "nymphium")
               ~email:(email_of "nymphium@example.com"))))

let () =
  Alcotest.run "usecase/register_user"
    [
      ( "register_user",
        [
          Alcotest.test_case "正常系" `Quick test_ok;
          Alcotest.test_case "メール重複" `Quick test_duplicated_email;
          Alcotest.test_case "検索失敗は捕まえない" `Quick
            test_lookup_failure_is_not_caught;
          Alcotest.test_case "登録失敗は捕まえない" `Quick
            test_create_failure_is_not_caught;
        ] );
    ]
