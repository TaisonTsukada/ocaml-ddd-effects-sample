(** メソッドとパスで Usecase を呼び分けるだけの小さなルータ。 *)

let path_segments resource =
  Uri.path (Uri.of_string resource)
  |> String.split_on_char '/'
  |> List.filter (fun s -> s <> "")

let handle request body =
  let resource = Http.Request.resource request in
  match (Http.Request.meth request, path_segments resource) with
  | `POST, [ "users" ] -> Handler.Users.register body
  | `GET, [ "users"; id ] -> Handler.Users.get ~id
  | `GET, [ "health" ] -> Handler.Health.get ()
  | _ -> Response.not_found "route"
