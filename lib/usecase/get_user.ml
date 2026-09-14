(** ユースケース: ID でユーザーを 1 人取得する。

    Port が返す [option] を、このユースケースの語彙 ({!outcome}) に置き直すだけ。
    「見つからない」はエラーではなく答えのひとつなので、[result] にはしない。 *)

open User_api_domain
open User_api_port

type outcome =
  | Found of Objects.User.t  (** 見つかった。 *)
  | Missing  (** その ID のユーザーは居ない。 *)

let run ~(id : Objects.User.Id.t) : outcome =
  match Locator.call @@ User_port.Find_by_id { id } with
  | Some user -> Found user
  | None -> Missing
