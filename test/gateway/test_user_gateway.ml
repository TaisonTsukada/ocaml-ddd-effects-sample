module User_gateway = User_api_gateway.User_gateway
module Store = User_api_driver.Memory.User_store
module User = User_api_domain.Objects.User
open User_api_test_support.Fixture

let result_t = Alcotest.result user_t errors_t
let option_result_t = Alcotest.result (Alcotest.option user_t) errors_t

(* --- 腐敗防止層としての変換 --- *)

let test_to_domain () =
  let row =
    { Store.id = 3; name = "nymphium"; email = "nymphium@example.com" }
  in
  Alcotest.check' result_t ~msg:"row からドメインを復元できる"
    ~expected:(Ok (user ~id:3 ()))
    ~actual:(User_gateway.to_domain row)

let test_to_domain_rejects_broken_row () =
  (* Driver はドメインを知らないので、壊れた値が返ってくることはあり得る。
     ACL はそれを検証して弾き、不正な値をドメインに入れない。 *)
  let row = { Store.id = 3; name = "nymphium"; email = "not-an-email" } in
  Alcotest.check' result_t ~msg:"壊れた row は InternalError になる"
    ~expected:(Error (`InternalError "broken user row: id=3"))
    ~actual:(User_gateway.to_domain row)

let test_of_domain_round_trip () =
  let u = user ~id:5 ~name:"びしょ〜じょ" ~email:"bishojo@example.com" () in
  Alcotest.check' result_t ~msg:"domain -> row -> domain で戻る" ~expected:(Ok u)
    ~actual:(User_gateway.to_domain (User_gateway.of_domain u))

let test_translate_error () =
  Alcotest.check' errors_t ~msg:"一意制約違反は Conflict" ~expected:(`Conflict "email")
    ~actual:(User_gateway.translate_error (Store.Unique_violation "email"));
  Alcotest.check' errors_t ~msg:"一時障害は InternalError"
    ~expected:(`InternalError "connection refused")
    ~actual:
      (User_gateway.translate_error (Store.Unavailable "connection refused"))

(* --- Port の実装としての振る舞い (実 Driver との結合) --- *)

let test_create_and_find () =
  let store = Store.create () in
  let created =
    User_gateway.create ~store ~name:(name_of "nymphium")
      ~email:(email_of "nymphium@example.com")
  in
  Alcotest.check' result_t ~msg:"採番された id が入る"
    ~expected:(Ok (user ~id:1 ()))
    ~actual:created;
  Alcotest.check' option_result_t ~msg:"id で引ける"
    ~expected:(Ok (Some (user ~id:1 ())))
    ~actual:(User_gateway.find_by_id ~store ~id:(id_of 1));
  Alcotest.check' option_result_t ~msg:"メールで引ける"
    ~expected:(Ok (Some (user ~id:1 ())))
    ~actual:
      (User_gateway.find_by_email ~store
         ~email:(email_of "nymphium@example.com"));
  Alcotest.check' option_result_t ~msg:"無いものは None" ~expected:(Ok None)
    ~actual:(User_gateway.find_by_id ~store ~id:(id_of 999))

let test_unique_violation () =
  let store = Store.create () in
  let create () =
    User_gateway.create ~store ~name:(name_of "nymphium")
      ~email:(email_of "nymphium@example.com")
  in
  ignore (create ());
  Alcotest.check' result_t ~msg:"ストアの一意制約はドメインのエラーになる"
    ~expected:(Error (`Conflict "email"))
    ~actual:(create ())

let () =
  Alcotest.run "gateway"
    [
      ( "腐敗防止層",
        [
          Alcotest.test_case "row -> domain" `Quick test_to_domain;
          Alcotest.test_case "壊れた row を弾く" `Quick
            test_to_domain_rejects_broken_row;
          Alcotest.test_case "domain -> row -> domain" `Quick
            test_of_domain_round_trip;
          Alcotest.test_case "エラー語彙の翻訳" `Quick test_translate_error;
        ] );
      ( "Driver との結合",
        [
          Alcotest.test_case "登録と検索" `Quick test_create_and_find;
          Alcotest.test_case "一意制約違反" `Quick test_unique_violation;
        ] );
    ]
