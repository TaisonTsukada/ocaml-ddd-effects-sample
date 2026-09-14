(** ドメインの境界でのパース失敗。

    外から来た文字列をドメインの値にできなかった、という一点だけを表す。 「見つからない」「重複している」は失敗ではなく業務上の結果なので、各
    Usecase が 自分の ADT で表現する ([Register_user.outcome] など)。接続断のような不測の事態は Gateway
    が例外を投げる。

    polymorphic variant にしておくと、各層で [[> Errors.t]] と書いて
    「これに加えて他のエラーもあり得る」と自然に拡張できる。 *)

type t = [ `ConvertError of string  (** バリデーションに落ちたフィールド名。入力が不正 (400 相当)。 *) ]

let equal (a : t) (b : t) = a = b

let pp fmt (e : t) =
  match e with
  | `ConvertError field -> Format.fprintf fmt "`ConvertError %S" field

let show e = Format.asprintf "%a" pp e
