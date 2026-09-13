(** 「型の隠蔽でドメインの値を絞る」ための小さなファンクター群。

    value object の型 [t] を abstract にし、[from] を通さないと値を作れなくする。 実装は [Fun.id]
    なので、ランタイムコストは実質ゼロで型だけが変わる (準)同型変換 ("morph") になっている。

    - {!Seal} : バリデーション不要な同型変換 (例: [Id])
    - {!SealHom} : [validate] を通った値だけ [Ok] にする準同型変換 (例: [Email])

    ドメインオブジェクトのレコード型そのものは公開したまま、各フィールドだけ隠蔽する。 こうすると「オブジェクトが存在する =
    全フィールドが正しい」が型で保証され、 Usecase 層でのチェックが不要になる (Parse, don't validate)。 *)

module type Sealed = sig
  type bwd
  (** 隠蔽前の素の型。 *)

  type t
  (** 隠蔽後の型。 *)

  val from : bwd -> t
  val to_ : t -> bwd
  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit
end

module type SealedHom = sig
  type bwd
  type t

  val validate : bwd -> bool

  val from : bwd -> (t, [> Errors.t ]) result
  (** バリデーションを通った値だけ [Ok] にする。ドメインの値はここでしか作れない。 *)

  val to_ : t -> bwd
  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit

  val unsafe_from : bwd -> t
  (** バリデーションを飛ばして変換する。テストの fixture 専用。 外から来た値の復元には使わず、必ず {!from} を通すこと。 *)
end

module Seal (M : sig
  type t

  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit
end) : Sealed with type bwd = M.t = struct
  include M

  type bwd = t

  let from = Fun.id
  let to_ = Fun.id
end

module SealHom (M : sig
  type t

  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit
  val validate : t -> bool
  val field : string
end) : SealedHom with type bwd = M.t = struct
  include M

  type bwd = t

  let to_ = Fun.id
  let unsafe_from = Fun.id
  let from t = if validate t then Ok t else Error (`ConvertError field)
end
