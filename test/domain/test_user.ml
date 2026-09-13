module User = User_api_domain.Objects.User
open User_api_test_support.Fixture

let check_ok_name raw () =
  match User.Name.from raw with
  | Ok name ->
      Alcotest.check' Alcotest.string ~msg:"round trip" ~expected:raw
        ~actual:(User.Name.to_ name)
  | Error _ -> Alcotest.failf "%S should be a valid name" raw

let check_invalid_name raw () =
  Alcotest.check'
    (Alcotest.result name_t errors_t)
    ~msg:"rejected"
    ~expected:(Error (`ConvertError "name"))
    ~actual:(User.Name.from raw)

let check_ok_email raw () =
  match User.Email.from raw with
  | Ok email ->
      Alcotest.check' Alcotest.string ~msg:"round trip" ~expected:raw
        ~actual:(User.Email.to_ email)
  | Error _ -> Alcotest.failf "%S should be a valid email" raw

let check_invalid_email raw () =
  Alcotest.check'
    (Alcotest.result email_t errors_t)
    ~msg:"rejected"
    ~expected:(Error (`ConvertError "email"))
    ~actual:(User.Email.from raw)

let test_id_is_isomorphic () =
  Alcotest.check' Alcotest.int ~msg:"round trip" ~expected:42
    ~actual:(User.Id.to_ (User.Id.from 42))

let test_accessors () =
  let u = user ~id:7 ~name:"nymphium" ~email:"nymphium@example.com" () in
  Alcotest.check' Alcotest.int ~msg:"id" ~expected:7 ~actual:(User.id u);
  Alcotest.check' Alcotest.string ~msg:"name" ~expected:"nymphium"
    ~actual:(User.name u);
  Alcotest.check' Alcotest.string ~msg:"email" ~expected:"nymphium@example.com"
    ~actual:(User.email u)

let () =
  Alcotest.run "domain"
    [
      ( "name",
        [
          Alcotest.test_case "1 文字は通る" `Quick (check_ok_name "a");
          Alcotest.test_case "50 文字は通る" `Quick
            (check_ok_name (String.make 50 'a'));
          Alcotest.test_case "空文字は落ちる" `Quick (check_invalid_name "");
          Alcotest.test_case "51 文字は落ちる" `Quick
            (check_invalid_name (String.make 51 'a'));
        ] );
      ( "email",
        [
          Alcotest.test_case "通常のアドレス" `Quick
            (check_ok_email "nymphium@example.com");
          Alcotest.test_case "@ が無いと落ちる" `Quick (check_invalid_email "nope");
          Alcotest.test_case "@ が 2 つだと落ちる" `Quick (check_invalid_email "a@b@c");
          Alcotest.test_case "ローカル部が空だと落ちる" `Quick
            (check_invalid_email "@example.com");
          Alcotest.test_case "ドメイン部が空だと落ちる" `Quick
            (check_invalid_email "nymphium@");
        ] );
      ( "object",
        [
          Alcotest.test_case "Id は同型変換" `Quick test_id_is_isomorphic;
          Alcotest.test_case "アクセサは素の値を返す" `Quick test_accessors;
        ] );
    ]
