(** ユースケース: 死活確認。Port が増えても Usecase の書き方は変わらない、の例。 *)

open User_api_domain
open User_api_port

let run () : (unit, [> Errors.t ]) result = Locator.call System.Ping
