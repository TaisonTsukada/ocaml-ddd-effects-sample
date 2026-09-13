module Handler = User_api_app.Handler
module Store = User_api_driver.Memory.User_store
open User_api_test_support.Fixture

let result_t = Alcotest.result user_t errors_t

(* Usecase は effect を perform するだけなので、composition root のハンドラで囲んで
   初めて「インメモリストアに書く」という意味がつく。 *)

let test_register_then_get () =
  let store = Store.create () in
  let registered =
    Handler.v ~store @@ fun () ->
    User_api_usecase.Register_user.run ~name:(name_of "nymphium")
      ~email:(email_of "nymphium@example.com")
  in
  Alcotest.check' result_t ~msg:"Create が Gateway に束縛されている"
    ~expected:(Ok (user ~id:1 ()))
    ~actual:registered;
  let fetched =
    Handler.v ~store @@ fun () -> User_api_usecase.Get_user.run ~id:(id_of 1)
  in
  Alcotest.check' result_t ~msg:"同じストアから取得できる"
    ~expected:(Ok (user ~id:1 ()))
    ~actual:fetched

let test_duplicated_email () =
  let store = Store.create () in
  let register name email =
    Handler.v ~store @@ fun () ->
    User_api_usecase.Register_user.run ~name:(name_of name)
      ~email:(email_of email)
  in
  ignore (register "nymphium" "nymphium@example.com");
  Alcotest.check' result_t ~msg:"重複は Conflict"
    ~expected:(Error (`Conflict "email"))
    ~actual:(register "another" "nymphium@example.com")

let test_not_found () =
  let store = Store.create () in
  let actual =
    Handler.v ~store @@ fun () -> User_api_usecase.Get_user.run ~id:(id_of 999)
  in
  Alcotest.check' result_t ~msg:"未登録は NotFound"
    ~expected:(Error (`NotFound "user"))
    ~actual

let test_health () =
  let store = Store.create () in
  let actual = Handler.v ~store @@ fun () -> User_api_usecase.Health.run () in
  Alcotest.check'
    (Alcotest.result Alcotest.unit errors_t)
    ~msg:"System.Ping も束縛されている" ~expected:(Ok ()) ~actual

let () =
  Alcotest.run "app/handler"
    [
      ( "Port の束縛",
        [
          Alcotest.test_case "登録して取得する" `Quick test_register_then_get;
          Alcotest.test_case "メール重複" `Quick test_duplicated_email;
          Alcotest.test_case "未登録の取得" `Quick test_not_found;
          Alcotest.test_case "死活確認" `Quick test_health;
        ] );
    ]
