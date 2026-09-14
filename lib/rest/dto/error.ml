(** エラーの DTO と、境界のパース失敗 -> HTTP ステータスの対応表。

    ここに並ぶのは「入力が読めなかった」だけになった。404 や 409 は Usecase の
    {!User_api_usecase.Get_user.outcome} などから直接組み立てるので ({!Response})、
    ドメインのエラー型を経由しない。 *)

open Ppx_yojson_conv_lib.Yojson_conv.Primitives
module Errors = User_api_domain.Errors

type t = { error : string } [@@deriving yojson_of]

(** パース失敗を HTTP の語彙へ翻訳する。REST 層の責務。 *)
let to_http (e : Errors.t) : Http.Status.t * t =
  match e with
  | `ConvertError field -> (`Bad_request, { error = "invalid " ^ field })
