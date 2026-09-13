(** システム系の腐敗防止層。Driver の死活確認をドメインの語彙に翻訳する。 *)

module Probe = User_api_driver.System.Probe
module Errors = User_api_domain.Errors

let ping () : (unit, [> Errors.t ]) result =
  match Probe.ping () with
  | Ok () -> Ok ()
  | Error message -> Error (`InternalError message)
