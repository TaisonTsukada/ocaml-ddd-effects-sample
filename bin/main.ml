let port =
  match Sys.getenv_opt "PORT" with
  | Some raw -> int_of_string raw
  | None -> 8080

let () =
  Logs.set_reporter (Logs_fmt.reporter ());
  Logs.set_level (Some Logs.Info);
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  (* Driver のインスタンス化 = 実行環境の決定。ここから下は effect 越しに使われる。 *)
  let store = User_api_driver.Memory.User_store.create () in
  let socket = User_api_app.Server.listen ~sw ~net:env#net ~port () in
  Logs.info (fun m ->
      m "listening on port %d" (User_api_app.Server.port_of socket));
  (* 結び目: どの Port を誰が実装するかを決めたハンドラでリクエストを包む。 *)
  User_api_app.Server.serve
    ~wrap:(fun th -> User_api_app.Handler.v ~store th)
    socket
