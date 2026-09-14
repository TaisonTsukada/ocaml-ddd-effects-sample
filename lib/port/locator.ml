(** 依存関係をエフェクトで「文脈」に持ち上げるための入口。

    各 Port は {!action} (extensible variant) にコンストラクタを追加して「何が欲しいか」を 宣言する。Usecase
    は {!call} で effect を投げるだけで、誰がどう答えるか (インメモリか、 DB か、テスト用のモックか)
    を知らない。答えるハンドラを決めるのは composition root ([User_api_app.Composition_root])。

    action の戻り値に [result] のような制約は置かない。Port は常にドメインの値を返し、 「見つからない」のような業務上の分岐は ADT
    で表現する。接続断などの不測の事態は Gateway が例外を投げてプロセスを落とすので、型には現れない。 *)

type _ action = ..
type _ Effect.t += Inject : 'a action -> 'a Effect.t

let call action = Effect.perform (Inject action)
