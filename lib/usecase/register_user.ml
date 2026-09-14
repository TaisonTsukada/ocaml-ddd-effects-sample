(** ユースケース: ユーザーを 1 人登録する。

    引数やファンクターで Port の実装を受け取る代わりに、{!User_api_port.Locator.call} で effect を
    perform する。依存が値の世界から文脈に移ったので、シグネチャは 「何を受け取って何を返すか」だけになる。

    受け取るのは既にパース済みの [Name.t] / [Email.t]。文字列から作るのは REST 層の 仕事なので、この層より内側には常に
    valid な値しか流れてこない (Always Valid Domain Model)。

    結果は {!outcome} で表す。「メールが埋まっていた」は失敗ではなくこのユースケースの 正常な帰結のひとつなので、[result] ではなく
    ADT のコンストラクタになる。 *)

open User_api_domain
open User_api_port

type outcome =
  | Registered of Objects.User.t  (** 登録できた。 *)
  | Email_taken  (** そのメールは既に使われていた。 *)

let run ~(name : Objects.User.Name.t) ~(email : Objects.User.Email.t) : outcome
    =
  (* メールの重複確認 → 登録。2 つの Port 呼び出しを組み合わせるだけ。 *)
  match Locator.call @@ User_port.Find_by_email { email } with
  | Some _ -> Email_taken
  | None -> Registered (Locator.call @@ User_port.Create { name; email })
