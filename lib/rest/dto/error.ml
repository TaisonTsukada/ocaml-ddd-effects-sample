(** エラーの DTO と、ドメインのエラー -> HTTP ステータスの対応表。 *)

open Ppx_yojson_conv_lib.Yojson_conv.Primitives
module Errors = User_api_domain.Errors

type t = { error : string } [@@deriving yojson_of]

(** ドメインのエラーを HTTP の語彙へ翻訳する。REST 層の責務。 *)
let to_http (e : Errors.t) : Http.Status.t * t =
  match e with
  | `ConvertError field -> (`Bad_request, { error = "invalid " ^ field })
  | `NotFound what -> (`Not_found, { error = what ^ " not found" })
  | `Conflict what -> (`Conflict, { error = what ^ " already exists" })
  | `InternalError message -> (`Internal_server_error, { error = message })
