(** Composition root。Port の語彙を Gateway の実装で解釈するエフェクトハンドラを組み立てる。

    Usecase は [Locator.call (User_port.Create { name; email })] と書いただけで、
    ここで初めて「それはインメモリストアへの書き込みである」と決まる。 「どの action
    に誰が答えるか」という束縛の決定は、すべてこのファイルに集まっている。

    実装を差し替えたいときは束縛先の Gateway を変えるだけでよく、Usecase も Port も Gateway 自身も触らない。Port
    が増えたらハンドラを重ねていく。 *)

open Effect.Deep
module Locator = User_api_port.Locator
module User_port = User_api_port.User_port
module User_gateway = User_api_gateway.User_gateway

(** User Port の action を {!User_gateway} の関数へ束縛する。 *)
let user_port ~store th =
  try th () with
  | effect Locator.Inject (User_port.Create { name; email }), k ->
      continue k (User_gateway.create ~store ~name ~email)
  | effect Locator.Inject (User_port.Find_by_id { id }), k ->
      continue k (User_gateway.find_by_id ~store ~id)
  | effect Locator.Inject (User_port.Find_by_email { email }), k ->
      continue k (User_gateway.find_by_email ~store ~email)

(** 全部を積み上げたもの。これで囲んだ計算は「実行環境を渡された」状態になる。 Port が増えたら
    [a @@ fun () -> b ~x @@ fun () -> th ()] とハンドラを重ねていく。 *)
let handler ~store th = user_port ~store @@ fun () -> th ()
