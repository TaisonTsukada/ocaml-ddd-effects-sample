(** ドメイン層のエラー。

    polymorphic variant にしておくと、各層で [[> Errors.t]] と書いて
    「これに加えて他のエラーもあり得る」と自然に拡張できる。 *)

type t =
  [ `ConvertError of string  (** バリデーションに落ちたフィールド名。入力が不正 (400 相当)。 *)
  | `NotFound of string  (** 対象が見つからない (404 相当)。 *)
  | `Conflict of string  (** 一意制約などの衝突 (409 相当)。 *)
  | `InternalError of string  (** Driver など外側の失敗 (500 相当)。 *) ]

let equal (a : t) (b : t) = a = b

let pp fmt (e : t) =
  match e with
  | `ConvertError field -> Format.fprintf fmt "`ConvertError %S" field
  | `NotFound what -> Format.fprintf fmt "`NotFound %S" what
  | `Conflict what -> Format.fprintf fmt "`Conflict %S" what
  | `InternalError message -> Format.fprintf fmt "`InternalError %S" message

let show e = Format.asprintf "%a" pp e
