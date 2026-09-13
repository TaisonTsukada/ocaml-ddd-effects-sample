(** cohttp-eio サーバーの組み立て。 *)

let callback ~store _conn request body =
  (* cohttp-eio は接続ごとに fiber を fork し、effect は fiber をまたげないので、
     ハンドラはリクエストごとに (callback の中で) 被せる。 *)
  Handler.v ~store @@ fun () -> User_api_rest.Router.handle request body

let listen ~sw ~net ?(addr = Eio.Net.Ipaddr.V4.any) ~port () =
  Eio.Net.listen net ~sw ~backlog:128 ~reuse_addr:true (`Tcp (addr, port))

(** 実際に bind されたポート番号。[port:0] で listen したときに使う。 *)
let port_of socket =
  match Eio.Net.listening_addr socket with
  | `Tcp (_, port) -> port
  | `Unix path -> invalid_arg ("not a TCP socket: " ^ path)

let serve ?stop ~store socket =
  Cohttp_eio.Server.run ?stop socket
    (Cohttp_eio.Server.make ~callback:(callback ~store) ())
    ~on_error:(fun exn -> Logs.err (fun m -> m "%a" Eio.Exn.pp exn))
