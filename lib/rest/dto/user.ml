(** User の DTO と、Domain との相互変換。

    スライドで REST と Usecase の間に描かれている [DTO -> Domain] / [DTO <- Domain] の
    矢印がこのモジュール。入力のパース (= バリデーション) はここで完結する。 *)

open Ppx_yojson_conv_lib.Yojson_conv.Primitives
module User = User_api_domain.Objects.User
module Errors = User_api_domain.Errors

type register_request = { name : string; email : string } [@@deriving of_yojson]

type response = { id : int; name : string; email : string }
[@@deriving yojson_of]

let ( let* ) = Result.bind

(** DTO -> Domain。ここを通らないとドメインの値は作れない。 *)
let to_domain ({ name; email } : register_request) :
    (User.Name.t * User.Email.t, [> Errors.t ]) result =
  let* name = User.Name.from name in
  let* email = User.Email.from email in
  Ok (name, email)

(** Domain -> DTO。 *)
let of_domain user : response =
  { id = User.id user; name = User.name user; email = User.email user }

(** パス変数の文字列 -> [User.Id.t]。 *)
let id_of_string raw : (User.Id.t, [> Errors.t ]) result =
  match int_of_string_opt raw with
  | Some id when id > 0 -> Ok (User.Id.from id)
  | _ -> Error (`ConvertError "id")

(** リクエストボディ (JSON 文字列) -> DTO。 *)
let register_request_of_body raw : (register_request, [> Errors.t ]) result =
  match Yojson.Safe.from_string raw with
  | json -> (
      match register_request_of_yojson json with
      | dto -> Ok dto
      | exception Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error _ ->
          Error (`ConvertError "body"))
  | exception Yojson.Json_error _ -> Error (`ConvertError "body")
