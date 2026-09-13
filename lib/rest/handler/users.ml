(** /users のハンドラ。HTTP <-> Usecase の変換だけを行い、永続化のことは知らない。 *)

let ( let* ) = Result.bind

let register body =
  let result =
    let* dto = Dto.User.register_request_of_body (Eio.Flow.read_all body) in
    let* name, email = Dto.User.to_domain dto in
    (* ここで Port の effect が perform されるが、REST 層はそれを扱わない。
       解釈するのは Gateway のハンドラ (app/handler.ml で被せる)。 *)
    User_api_usecase.Register_user.run ~name ~email
  in
  match result with
  | Ok user ->
      Response.json ~status:`Created
        (Dto.User.yojson_of_response (Dto.User.of_domain user))
  | Error e -> Response.error e

let get ~id =
  let result =
    let* id = Dto.User.id_of_string id in
    User_api_usecase.Get_user.run ~id
  in
  match result with
  | Ok user ->
      Response.json ~status:`OK
        (Dto.User.yojson_of_response (Dto.User.of_domain user))
  | Error e -> Response.error e
