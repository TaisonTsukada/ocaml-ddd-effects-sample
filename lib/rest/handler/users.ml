(** /users のハンドラ。HTTP <-> Usecase の変換だけを行い、永続化のことは知らない。 *)

let ( let* ) = Result.bind

let register body =
  let result =
    let* dto = Dto.User.register_request_of_body (Eio.Flow.read_all body) in
    let* name, email = Dto.User.to_domain dto in
    (* Usecase が Port の effect を perform する。REST 層はそれを扱わない。
       解釈するのは composition root (lib/app/composition_root.ml がリクエスト全体に被せる)。 *)
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
