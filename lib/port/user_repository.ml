(** User リポジトリの「語彙」。

    ここにはシグネチャ (action) だけがあり、実装はない。実装は Driver にあり、 両者を繋ぐのは Gateway のハンドラ。Usecase
    はこのコンストラクタを使わないと effect を投げられないので、シグネチャと実装のズレはコンパイル時に検出される。 *)

open User_api_domain

open struct
  module M = Objects.User
end

type _ Locator.action +=
  | Create : {
      name : M.Name.t;
      email : M.Email.t;
    }
      -> (M.t, [> Errors.t ]) result Locator.action
  | Find_by_id : {
      id : M.Id.t;
    }
      -> (M.t option, [> Errors.t ]) result Locator.action
  | Find_by_email : {
      email : M.Email.t;
    }
      -> (M.t option, [> Errors.t ]) result Locator.action
