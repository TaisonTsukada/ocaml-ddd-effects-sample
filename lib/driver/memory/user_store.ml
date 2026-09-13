(** ユーザーのインメモリストア。

    DB ドライバのスタンドイン。ドメインを一切知らず、素の値 (int/string) の行 {!row} を 保持するだけで、エラーも自分の語彙
    {!error} で返す。

    Eio は単一ドメインで fiber を切り替えるだけなので、これらの関数の中に中断点 (I/O) が なければ Mutex なしで安全に使える。 *)

type row = { id : int; name : string; email : string }

type error =
  | Unique_violation of string  (** 一意制約違反。カラム名を持つ。 *)
  | Unavailable of string  (** 接続断などの一時障害。 *)

let pp_error fmt = function
  | Unique_violation column -> Format.fprintf fmt "Unique_violation %S" column
  | Unavailable message -> Format.fprintf fmt "Unavailable %S" message

type t = { mutable next_id : int; rows : (int, row) Hashtbl.t }

let create () = { next_id = 1; rows = Hashtbl.create 16 }

let find_by_email t email =
  Hashtbl.fold
    (fun _ row acc -> if acc = None && row.email = email then Some row else acc)
    t.rows None

let find_by_id t id = Hashtbl.find_opt t.rows id

let insert t ~name ~email =
  (* 本物の DB の UNIQUE 制約と同じように、ストア側でも一意性を守る。 *)
  match find_by_email t email with
  | Some _ -> Error (Unique_violation "email")
  | None ->
      let id = t.next_id in
      t.next_id <- id + 1;
      let row = { id; name; email } in
      Hashtbl.replace t.rows id row;
      Ok row
