(** {!User_api_port.User_repository} の実装 (腐敗防止層)。

    - Driver の [row] → Domain: **必ず検証つきの [from] を通す**。外から来た値を信用しない のが ACL
      の役目なので、[unsafe_from] は使わない。壊れた行は [`InternalError] に翻訳して、不正な値をドメインに入れない。
    - Domain → Driver の [row]: [to_] で素の値に戻す。
    - Driver のエラー語彙 ([Store.error]) も、ここでドメインのエラーに翻訳する。 *)

open Effect.Deep
module Locator = User_api_port.Locator
module Port = User_api_port.User_repository
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

(** Port の action を Driver の呼び出しへ解釈するエフェクトハンドラ。 「どの実装で動かすか」はここを差し替えるだけで決まる。 *)
let handler ~store th =
  try th () with
  | effect Locator.Inject (Port.Create { name; email }), k ->
      continue k (create ~store ~name ~email)
  | effect Locator.Inject (Port.Find_by_id { id }), k ->
      continue k (find_by_id ~store ~id)
  | effect Locator.Inject (Port.Find_by_email { email }), k ->
      continue k (find_by_email ~store ~email)
