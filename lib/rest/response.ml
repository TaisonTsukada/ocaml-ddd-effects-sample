(** cohttp-eio のレスポンスを組み立てる小物。 *)

let json ~status body =
  Cohttp_eio.Server.respond_string ~status
    ~headers:(Http.Header.init_with "content-type" "application/json")
    ~body:(Yojson.Safe.to_string body)
    ()

let message ~status text =
  json ~status (Dto.Error.yojson_of_t { Dto.Error.error = text })

(** 境界のパース失敗 (400)。 *)
let error e =
  let status, dto = Dto.Error.to_http e in
  json ~status (Dto.Error.yojson_of_t dto)

let not_found what = message ~status:`Not_found (what ^ " not found")
let conflict what = message ~status:`Conflict (what ^ " already exists")
