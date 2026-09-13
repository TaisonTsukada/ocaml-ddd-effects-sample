(** User Port に対応する腐敗防止層 (ACL)。

    Driver の語彙 ([row] / [Store.error]) と Domain の語彙をひたすら翻訳するだけの層で、 effect
    のことは知らない (依存にも [user_api_port] を入れていない)。 どの Port の action
    がここのどの関数に対応するかを決めるのは composition root ([User_api_app.Composition_root])。

    - Driver の [row] → Domain: **必ず検証つきの [from] を通す**。外から来た値を信用しないのが ACL
      の役目なので、[unsafe_from] は使わない。壊れた行は [`InternalError] に翻訳して、 不正な値をドメインに入れない。
    - Domain → Driver の [row]: [to_] で素の値に戻す。
    - Driver のエラー語彙 ([Store.error]) も、ここでドメインのエラーに翻訳する。 *)

module Store = User_api_driver.Memory.User_store
module Errors = User_api_domain.Errors
module User = User_api_domain.Objects.User

(** Driver の行をドメインオブジェクトへ。検証に落ちたらデータが壊れている。 *)
let to_domain (row : Store.row) : (User.t, [> Errors.t ]) result =
  match (User.Name.from row.name, User.Email.from row.email) with
  | Ok name, Ok email -> Ok { User.id = User.Id.from row.id; name; email }
  | _ -> Error (`InternalError (Printf.sprintf "broken user row: id=%d" row.id))

(** ドメインオブジェクトを Driver の行へ。 *)
let of_domain (user : User.t) : Store.row =
  { Store.id = User.id user; name = User.name user; email = User.email user }

(** Driver のエラー語彙 → ドメインのエラー語彙。 *)
let translate_error : Store.error -> [> Errors.t ] = function
  | Store.Unique_violation column -> `Conflict column
  | Store.Unavailable message -> `InternalError message

let create ~store ~name ~email : (User.t, [> Errors.t ]) result =
  match
    Store.insert store ~name:(User.Name.to_ name) ~email:(User.Email.to_ email)
  with
  | Ok row -> to_domain row
  | Error e -> Error (translate_error e)

let find_by_id ~store ~id : (User.t option, [> Errors.t ]) result =
  match Store.find_by_id store (User.Id.to_ id) with
  | None -> Ok None
  | Some row -> Result.map Option.some (to_domain row)

let find_by_email ~store ~email : (User.t option, [> Errors.t ]) result =
  match Store.find_by_email store (User.Email.to_ email) with
  | None -> Ok None
  | Some row -> Result.map Option.some (to_domain row)
