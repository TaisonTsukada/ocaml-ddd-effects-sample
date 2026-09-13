(** Port のモック。

    記事 §5 のとおり、必要なのは「[Locator.Inject] に答えるエフェクトハンドラ」だけで、 モックライブラリは要らない。action
    ごとに何を返すかを書いた {!t} を渡すと、 その解釈のもとで計算を走らせられる。

    ([inject] は action の型変数に対して多相でなければならないので、多相フィールドを 持つレコードにしてある。) *)

type t = { inject : 'a. 'a User_api_port.Locator.action -> 'a }

let handle { inject } th =
  try th ()
  with effect User_api_port.Locator.Inject action, k ->
    Effect.Deep.continue k (inject action)
