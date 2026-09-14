(** User Port に対応する腐敗防止層 (ACL)。

    Driver の語彙 ([row] / [Store.error]) と Domain の語彙をひたすら翻訳するだけの層で、 effect
    のことは知らない (依存にも [user_api_port] を入れていない)。 どの Port の action
    がここのどの関数に対応するかを決めるのは composition root ([User_api_app.Composition_root])。

    - Driver の [row] → Domain: **必ず検証つきの [from] を通す**。外から来た値を信用しないのが ACL
      の役目なので、[unsafe_from] は使わない。
    - Domain → Driver の [row]: [to_] で素の値に戻す。
    - 翻訳できない事態 (壊れた行、接続断) はドメインのエラーに落とさず {!Failure} を投げる。 返すのは常にドメインの値で、[result]
      は出てこない。 *)

module Store = User_api_driver.Memory.User_store
module User = User_api_domain.Objects.User

(** Driver の行をドメインオブジェクトへ。検証に落ちたらデータが壊れている。 *)
let to_domain (row : Store.row) : User.t =
  match (User.Name.from row.name, User.Email.from row.email) with
  | Ok name, Ok email -> { User.id = User.Id.from row.id; name; email }
  | _ ->
      raise
        (Failure.Corrupted_row (Printf.sprintf "broken user row: id=%d" row.id))

(** ドメインオブジェクトを Driver の行へ。 *)
let of_domain (user : User.t) : Store.row =
  { Store.id = User.id user; name = User.name user; email = User.email user }

(** Driver のエラー語彙は、どれも呼び出し側が回復できないので例外にする。 *)
let raise_store_error = function
  | Store.Unique_violation column -> raise (Failure.Unique_violation column)
  | Store.Unavailable message -> raise (Failure.Unavailable message)

let create ~store ~name ~email : User.t =
  match
    Store.insert store ~name:(User.Name.to_ name) ~email:(User.Email.to_ email)
  with
  | Ok row -> to_domain row
  | Error e -> raise_store_error e

let find_by_id ~store ~id : User.t option =
  Option.map to_domain (Store.find_by_id store (User.Id.to_ id))

let find_by_email ~store ~email : User.t option =
  Option.map to_domain (Store.find_by_email store (User.Email.to_ email))
