(** Composition root: Port の語彙を Gateway の実装で解釈するエフェクトハンドラ。

    Usecase は [Locator.call (User_port.Create { name; email })] と書いただけで、
    ここで初めて「それはインメモリストアへの書き込みである」と決まる。 「どの action
    に誰が答えるか」という束縛の決定は、すべてこのファイルに集まっている。

    実装を差し替えたいときは束縛先の Gateway を変えるだけでよく、Usecase も Port も Gateway 自身も触らない。Port
    が増えたらハンドラを重ねていく。 *)

open Effect.Deep
module Locator = User_api_port.Locator
module User_port = User_api_port.User_port
module System_port = User_api_port.System_port
module User_gateway = User_api_gateway.User_gateway
module System_gateway = User_api_gateway.System_gateway

(** User Port の action を {!User_gateway} の関数へ束縛する。 *)
let user_port ~store th =
  try th () with
  | effect Locator.Inject (User_port.Create { name; email }), k ->
      continue k (User_gateway.create ~store ~name ~email)
  | effect Locator.Inject (User_port.Find_by_id { id }), k ->
      continue k (User_gateway.find_by_id ~store ~id)
  | effect Locator.Inject (User_port.Find_by_email { email }), k ->
      continue k (User_gateway.find_by_email ~store ~email)

(** システム系の Port を {!System_gateway} へ束縛する。 *)
let system_port th =
  try th ()
  with effect Locator.Inject System_port.Ping, k ->
    continue k (System_gateway.ping ())

(** 全部を積み上げたもの。これで囲んだ計算は「実行環境を渡された」状態になる。 *)
let v ~store th =
  system_port @@ fun () ->
  user_port ~store @@ fun () -> th ()
