(** Composition root: Port の語彙を Gateway の実装で解釈するエフェクトハンドラ。

    Usecase は [Locator.call (User_repository.Create { name; email })] と書いただけで、
    ここで初めて「それはインメモリストアへの書き込みである」と決まる。 「どの action
    に誰が答えるか」という束縛の決定は、すべてこのファイルに集まっている。

    実装を差し替えたいときは [Gateway] の参照先を変えるだけでよく、Usecase も Port も Gateway 自身も触らない。Port
    が増えたらハンドラを重ねていく。 *)

open Effect.Deep
module Locator = User_api_port.Locator
module User_repository = User_api_port.User_repository
module System = User_api_port.System
module Gateway = User_api_gateway

(** User リポジトリの action を Gateway の関数へ束縛する。 *)
let users ~store th =
  try th () with
  | effect Locator.Inject (User_repository.Create { name; email }), k ->
      continue k (Gateway.User_repository.create ~store ~name ~email)
  | effect Locator.Inject (User_repository.Find_by_id { id }), k ->
      continue k (Gateway.User_repository.find_by_id ~store ~id)
  | effect Locator.Inject (User_repository.Find_by_email { email }), k ->
      continue k (Gateway.User_repository.find_by_email ~store ~email)

(** システム系の action を束縛する。 *)
let system th =
  try th ()
  with effect Locator.Inject System.Ping, k ->
    continue k (Gateway.System.ping ())

(** 全部を積み上げたもの。これで囲んだ計算は「実行環境を渡された」状態になる。 *)
let v ~store th =
  system @@ fun () ->
  users ~store @@ fun () -> th ()
