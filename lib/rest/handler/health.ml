(** /health のハンドラ。

    死活確認は「200 を返せること自体」が答えなので、Usecase も Port も Gateway も作らず ここで即答する。Port
    にする価値が出るのは、DB への [SELECT 1] のように 「外部リソースに問い合わせないと分からない」ものを見に行くようになってから。 *)

let get () = Response.json ~status:`OK (`Assoc [ ("status", `String "ok") ])
