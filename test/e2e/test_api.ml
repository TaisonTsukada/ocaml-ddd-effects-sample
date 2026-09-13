module Store = User_api_driver.Memory.User_store
module Server = User_api_app.Server

let url ~port path =
  Uri.of_string (Printf.sprintf "http://127.0.0.1:%d%s" port path)

(** サーバーを空きポートで起動し、クライアントを渡してテスト本体を走らせる。 *)
let with_server env f =
  Eio.Switch.run @@ fun sw ->
  let net = Eio.Stdenv.net env in
  let store = Store.create () in
  let socket =
    Server.listen ~sw ~net ~addr:Eio.Net.Ipaddr.V4.loopback ~port:0 ()
  in
  let port = Server.port_of socket in
  let client = Cohttp_eio.Client.make ~https:None net in
  (* テスト本体が終わったらサーバーの fiber をキャンセルする。
     graceful stop (Server.serve ~stop) は keep-alive の接続が閉じるまで待つので、
     テストでは Fiber.first によるキャンセルで止める。 *)
  Eio.Fiber.first
    (fun () ->
      Server.serve ~wrap:(fun th -> User_api_app.Handler.v ~store th) socket)
    (fun () -> f ~client ~sw ~port)

let read (response, body) =
  (Http.Status.to_int (Http.Response.status response), Eio.Flow.read_all body)

let post ~client ~sw ~port path body =
  read
    (Cohttp_eio.Client.post client ~sw
       ~headers:
         (Http.Header.of_list
            [
              ("content-type", "application/json");
              ("content-length", string_of_int (String.length body));
            ])
       ~body:(Cohttp_eio.Body.of_string body)
       (url ~port path))

let get ~client ~sw ~port path =
  read (Cohttp_eio.Client.get client ~sw (url ~port path))

let check_status ~msg ~expected (status, _) =
  Alcotest.check' Alcotest.int ~msg ~expected ~actual:status

let check_body ~msg ~expected (_, body) =
  Alcotest.check' Alcotest.string ~msg ~expected ~actual:body

let nymphium = {|{"name":"nymphium","email":"nymphium@example.com"}|}

let test_register env () =
  with_server env @@ fun ~client ~sw ~port ->
  let response = post ~client ~sw ~port "/users" nymphium in
  check_status ~msg:"201 Created" ~expected:201 response;
  check_body ~msg:"採番された id が返る"
    ~expected:{|{"id":1,"name":"nymphium","email":"nymphium@example.com"}|}
    response

let test_register_duplicated env () =
  with_server env @@ fun ~client ~sw ~port ->
  ignore (post ~client ~sw ~port "/users" nymphium);
  let response =
    post ~client ~sw ~port "/users"
      {|{"name":"another","email":"nymphium@example.com"}|}
  in
  check_status ~msg:"409 Conflict" ~expected:409 response;
  check_body ~msg:"理由が返る" ~expected:{|{"error":"email already exists"}|}
    response

let test_register_invalid env () =
  with_server env @@ fun ~client ~sw ~port ->
  check_status ~msg:"name が空なら 400" ~expected:400
    (post ~client ~sw ~port "/users" {|{"name":"","email":"a@example.com"}|});
  check_body ~msg:"email が不正なら 400" ~expected:{|{"error":"invalid email"}|}
    (post ~client ~sw ~port "/users" {|{"name":"nymphium","email":"nope"}|});
  check_status ~msg:"壊れた JSON なら 400" ~expected:400
    (post ~client ~sw ~port "/users" "{")

let test_get env () =
  with_server env @@ fun ~client ~sw ~port ->
  ignore (post ~client ~sw ~port "/users" nymphium);
  let response = get ~client ~sw ~port "/users/1" in
  check_status ~msg:"200 OK" ~expected:200 response;
  check_body ~msg:"登録したユーザーが返る"
    ~expected:{|{"id":1,"name":"nymphium","email":"nymphium@example.com"}|}
    response

let test_get_missing env () =
  with_server env @@ fun ~client ~sw ~port ->
  check_status ~msg:"未登録なら 404" ~expected:404
    (get ~client ~sw ~port "/users/999");
  check_status ~msg:"数値でない id は 400" ~expected:400
    (get ~client ~sw ~port "/users/abc")

let test_health env () =
  with_server env @@ fun ~client ~sw ~port ->
  let response = get ~client ~sw ~port "/health" in
  check_status ~msg:"200 OK" ~expected:200 response;
  check_body ~msg:"ok が返る" ~expected:{|{"status":"ok"}|} response

let test_unknown_route env () =
  with_server env @@ fun ~client ~sw ~port ->
  check_status ~msg:"知らないパスは 404" ~expected:404 (get ~client ~sw ~port "/nope")

let () =
  Eio_main.run @@ fun env ->
  Alcotest.run ~and_exit:false "e2e"
    [
      ( "POST /users",
        [
          Alcotest.test_case "登録できる" `Quick (test_register env);
          Alcotest.test_case "メール重複は 409" `Quick (test_register_duplicated env);
          Alcotest.test_case "不正な入力は 400" `Quick (test_register_invalid env);
        ] );
      ( "GET /users/:id",
        [
          Alcotest.test_case "取得できる" `Quick (test_get env);
          Alcotest.test_case "見つからない" `Quick (test_get_missing env);
        ] );
      ( "その他",
        [
          Alcotest.test_case "GET /health" `Quick (test_health env);
          Alcotest.test_case "未定義のルート" `Quick (test_unknown_route env);
        ] );
    ]
