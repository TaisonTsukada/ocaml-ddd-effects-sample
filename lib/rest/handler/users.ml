(** /users のハンドラ。HTTP <-> Usecase の変換だけを行い、永続化のことは知らない。

    入力のパースだけが [result] で、その先は Usecase の outcome を match して ステータスを決める。Driver
    が落ちたときの例外はここでは捕まえない。 *)

module Register_user = User_api_usecase.Register_user
module Get_user = User_api_usecase.Get_user

let ( let* ) = Result.bind

let user ~status user =
  Response.json ~status (Dto.User.yojson_of_response (Dto.User.of_domain user))

let register body =
  let parsed =
    let* dto = Dto.User.register_request_of_body (Eio.Flow.read_all body) in
    Dto.User.to_domain dto
  in
  match parsed with
  | Error e -> Response.error e
  | Ok (name, email) -> (
      (* Usecase が Port の effect を perform する。REST 層はそれを扱わない。
         解釈するのは composition root (lib/app/composition_root.ml がリクエスト全体に被せる)。 *)
      match Register_user.run ~name ~email with
      | Register_user.Registered created -> user ~status:`Created created
      | Register_user.Email_taken -> Response.conflict "email")

let get ~id =
  match Dto.User.id_of_string id with
  | Error e -> Response.error e
  | Ok id -> (
      match Get_user.run ~id with
      | Get_user.Found found -> user ~status:`OK found
      | Get_user.Missing -> Response.not_found "user")
