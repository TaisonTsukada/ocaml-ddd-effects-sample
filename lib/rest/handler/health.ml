(** /health のハンドラ。 *)

let get () =
  match User_api_usecase.Health.run () with
  | Ok () -> Response.json ~status:`OK (`Assoc [ ("status", `String "ok") ])
  | Error e -> Response.error e
