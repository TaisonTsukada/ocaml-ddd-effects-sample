(** ユースケース: ユーザーを 1 人登録する。

    引数やファンクターで Port の実装を受け取る代わりに、{!User_api_port.Locator.call} で effect を
    perform する。依存が値の世界から文脈に移ったので、シグネチャは 「何を受け取って何を返すか」だけになる。

    受け取るのは既にパース済みの [Name.t] / [Email.t]。文字列から作るのは REST 層の 仕事なので、この層より内側には常に
    valid な値しか流れてこない (Always Valid Domain Model)。 *)

open User_api_domain
open User_api_port

let ( let* ) = Result.bind

let run ~(name : Objects.User.Name.t) ~(email : Objects.User.Email.t) :
    (Objects.User.t, [> Errors.t ]) result =
  (* メールの重複確認 → 登録。2 つの Port 呼び出しを組み合わせるだけ。 *)
  let* existing = Locator.call @@ User_port.Find_by_email { email } in
  match existing with
  | Some _ -> Error (`Conflict "email")
  | None -> Locator.call @@ User_port.Create { name; email }
