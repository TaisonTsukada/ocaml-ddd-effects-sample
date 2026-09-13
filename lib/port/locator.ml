(** 依存関係をエフェクトで「文脈」に持ち上げるための入口。

    各 Port は {!action} (extensible variant) にコンストラクタを追加して「何が欲しいか」を 宣言する。Usecase
    は {!call} で effect を投げるだけで、誰がどう答えるか (インメモリか、 DB か、テスト用のモックか)
    を知らない。答えるハンドラを決めるのは composition root ([User_api_app.Composition_root])。

    ['action] は必ず [('a, [> Errors.t]) result] の形になるよう制約しているので、 「Port
    の操作は失敗し得る」ことが型に現れる。 *)

open User_api_domain

type _ action = ..

type _ Effect.t +=
  | Inject : (('a, [> Errors.t ]) result as 'action) action -> 'action Effect.t

let call action = Effect.perform (Inject action)
