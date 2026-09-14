(** User に関する Port の「語彙」。

    ここにはシグネチャ (action) だけがあり、実装はない。実際の操作は Driver にあり、 その翻訳は Gateway が、両者の束縛は
    composition root が行う。Usecase はこの コンストラクタを使わないと effect
    を投げられないので、語彙と使用のズレは起きない。

    どの action もドメインの値をそのまま返す。「その ID のユーザーは居ないかもしれない」だけが 業務上あり得る分岐なので [option]
    で表し、それ以外の失敗は例外として扱う。 *)

open User_api_domain

open struct
  module M = Objects.User
end

type _ Locator.action +=
  | Create : { name : M.Name.t; email : M.Email.t } -> M.t Locator.action
  | Find_by_id : { id : M.Id.t } -> M.t option Locator.action
  | Find_by_email : { email : M.Email.t } -> M.t option Locator.action
