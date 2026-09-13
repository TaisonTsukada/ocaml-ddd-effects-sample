module Dto = User_api_rest.Dto
module User = User_api_domain.Objects.User
open User_api_test_support.Fixture

let parsed_t = Alcotest.result (Alcotest.pair name_t email_t) errors_t
let id_result_t = Alcotest.result id_t errors_t

(* --- DTO -> Domain --- *)

let test_to_domain_ok () =
  Alcotest.check' parsed_t ~msg:"パースできる"
    ~expected:(Ok (name_of "nymphium", email_of "nymphium@example.com"))
    ~actual:
      (Dto.User.to_domain
         { Dto.User.name = "nymphium"; email = "nymphium@example.com" })

let test_to_domain_rejects_name () =
  Alcotest.check' parsed_t ~msg:"空の name は Usecase まで届かない"
    ~expected:(Error (`ConvertError "name"))
    ~actual:
      (Dto.User.to_domain
         { Dto.User.name = ""; email = "nymphium@example.com" })

let test_to_domain_rejects_email () =
  Alcotest.check' parsed_t ~msg:"不正な email は Usecase まで届かない"
    ~expected:(Error (`ConvertError "email"))
    ~actual:(Dto.User.to_domain { Dto.User.name = "nymphium"; email = "nope" })

(* --- Domain -> DTO --- *)

let test_of_domain () =
  let response = Dto.User.of_domain (user ~id:3 ()) in
  Alcotest.check' Alcotest.string ~msg:"JSON になる"
    ~expected:{|{"id":3,"name":"nymphium","email":"nymphium@example.com"}|}
    ~actual:(Yojson.Safe.to_string (Dto.User.yojson_of_response response))

(* --- ボディとパス変数のパース --- *)

let check_body_error raw () =
  match Dto.User.register_request_of_body raw with
  | Ok _ -> Alcotest.failf "%S should not parse" raw
  | Error e ->
      Alcotest.check' errors_t ~msg:"400 相当" ~expected:(`ConvertError "body")
        ~actual:e

let test_body_ok () =
  match
    Dto.User.register_request_of_body
      {|{"name":"nymphium","email":"nymphium@example.com"}|}
  with
  | Error _ -> Alcotest.fail "should parse"
  | Ok dto ->
      Alcotest.check' Alcotest.string ~msg:"name" ~expected:"nymphium"
        ~actual:dto.name;
      Alcotest.check' Alcotest.string ~msg:"email"
        ~expected:"nymphium@example.com" ~actual:dto.email

let test_id_ok () =
  Alcotest.check' id_result_t ~msg:"数値ならパースできる"
    ~expected:(Ok (id_of 12))
    ~actual:(Dto.User.id_of_string "12")

let check_id_error raw () =
  Alcotest.check' id_result_t ~msg:"400 相当"
    ~expected:(Error (`ConvertError "id"))
    ~actual:(Dto.User.id_of_string raw)

(* --- ドメインのエラー -> HTTP --- *)

let check_status e expected_status expected_message () =
  let status, dto = Dto.Error.to_http e in
  Alcotest.check' Alcotest.int ~msg:"status" ~expected:expected_status
    ~actual:(Http.Status.to_int status);
  Alcotest.check' Alcotest.string ~msg:"message" ~expected:expected_message
    ~actual:dto.error

let () =
  Alcotest.run "rest"
    [
      ( "DTO -> Domain",
        [
          Alcotest.test_case "正常系" `Quick test_to_domain_ok;
          Alcotest.test_case "name が不正" `Quick test_to_domain_rejects_name;
          Alcotest.test_case "email が不正" `Quick test_to_domain_rejects_email;
        ] );
      ("Domain -> DTO", [ Alcotest.test_case "レスポンス" `Quick test_of_domain ]);
      ( "body",
        [
          Alcotest.test_case "正常系" `Quick test_body_ok;
          Alcotest.test_case "壊れた JSON" `Quick (check_body_error "{");
          Alcotest.test_case "フィールド不足" `Quick
            (check_body_error {|{"name":"nymphium"}|});
          Alcotest.test_case "型違い" `Quick
            (check_body_error {|{"name":1,"email":"a@b"}|});
        ] );
      ( "path",
        [
          Alcotest.test_case "数値" `Quick test_id_ok;
          Alcotest.test_case "数値でない" `Quick (check_id_error "abc");
          Alcotest.test_case "0 は不可" `Quick (check_id_error "0");
          Alcotest.test_case "負数は不可" `Quick (check_id_error "-1");
        ] );
      ( "エラー -> HTTP",
        [
          Alcotest.test_case "ConvertError -> 400" `Quick
            (check_status (`ConvertError "name") 400 "invalid name");
          Alcotest.test_case "NotFound -> 404" `Quick
            (check_status (`NotFound "user") 404 "user not found");
          Alcotest.test_case "Conflict -> 409" `Quick
            (check_status (`Conflict "email") 409 "email already exists");
          Alcotest.test_case "InternalError -> 500" `Quick
            (check_status (`InternalError "boom") 500 "boom");
        ] );
    ]
