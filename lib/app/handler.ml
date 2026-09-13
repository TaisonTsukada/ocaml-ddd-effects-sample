(** Port の語彙を Gateway の実装で解釈するエフェクトハンドラ。

    Usecase は [Locator.call (User_repository.Create { name; email })] と書いただけで、
    ここで初めて「それはインメモリストアへの書き込みである」と決まる。実装を差し替えたい ときは、この関数が参照する Gateway を変えるだけでよい。

    Port が増えたらハンドラを重ねていく (記事の [system] / [users] と同じ形)。 *)

let v ~store th =
  User_api_gateway.System.handler @@ fun () ->
  User_api_gateway.User_repository.handler ~store @@ fun () -> th ()
