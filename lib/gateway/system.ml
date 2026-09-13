(** {!User_api_port.System} の実装。Port が増えたらこうしてハンドラを足していく。 *)

open Effect.Deep
module Locator = User_api_port.Locator
module Port = User_api_port.System
module Probe = User_api_driver.System.Probe
module Errors = User_api_domain.Errors

let ping () : (unit, [> Errors.t ]) result =
  match Probe.ping () with
  | Ok () -> Ok ()
  | Error message -> Error (`InternalError message)

let handler th =
  try th () with effect Locator.Inject Port.Ping, k -> continue k (ping ())
