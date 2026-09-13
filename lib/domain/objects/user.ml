(** User ドメインオブジェクト。

    レコードの形 (フィールド名) は公開するが、各フィールドの型は {!Morph} で隠蔽されて いるので、[Name.from] /
    [Email.from] を通さずに [t] を組み立てることはできない。 つまり「[t] が存在する = 全フィールドがドメイン的に正しい」。 *)

(** ID。永続化層が採番するので、バリデーションのない同型変換 (Seal) にしてある。 *)
module Id = Morph.Seal (struct
  type t = int

  let equal = Int.equal
  let pp = Format.pp_print_int
end)

(** 表示名。1〜50 文字。 *)
module Name = Morph.SealHom (struct
  type t = string

  let equal = String.equal
  let pp fmt s = Format.fprintf fmt "%S" s
  let field = "name"

  let validate s =
    let len = String.length s in
    1 <= len && len <= 50
end)

(** メールアドレス。[@] をちょうど 1 つ含み、その前後が空でないこと。 *)
module Email = Morph.SealHom (struct
  type t = string

  let equal = String.equal
  let pp fmt s = Format.fprintf fmt "%S" s
  let field = "email"

  let validate s =
    String.length s <= 254
    &&
    match String.split_on_char '@' s with
    | [ local; domain ] -> local <> "" && domain <> ""
    | _ -> false
end)

type t = { id : Id.t; name : Name.t; email : Email.t }

(* 呼び出し側 (REST の DTO など) 向けに、素の値へ戻すアクセサを用意する。
   deconstruction はここを通る。 *)

let id { id; _ } = Id.to_ id
let name { name; _ } = Name.to_ name
let email { email; _ } = Email.to_ email

let equal a b =
  Id.equal a.id b.id && Name.equal a.name b.name && Email.equal a.email b.email

let pp fmt { id; name; email } =
  Format.fprintf fmt "{ id = %a; name = %a; email = %a }" Id.pp id Name.pp name
    Email.pp email
