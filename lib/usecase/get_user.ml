(** ユースケース: ID でユーザーを 1 人取得する。 「見つからない」を Port の [None] からドメインのエラーへ翻訳するのはここ。 *)

open User_api_domain
open User_api_port

let ( let* ) = Result.bind

let run ~(id : Objects.User.Id.t) : (Objects.User.t, [> Errors.t ]) result =
  let* found = Locator.call @@ User_port.Find_by_id { id } in
  match found with Some user -> Ok user | None -> Error (`NotFound "user")
