(** 腐敗防止層が「これは業務上の分岐ではない」と判断した事態。

    ドメインの語彙に翻訳せず、そのまま投げてプロセスを落とす。呼び出し側に回復手段が ない以上、[result]
    に入れて型で持ち回っても扱いに困るだけだからである。捕まえるのは ログを取るサーバーの最外周 ([User_api_app.Server] の
    [on_error]) だけ。 *)

exception Unavailable of string
(** 接続断などの一時障害。 *)

exception Corrupted_row of string
(** Driver の行がドメインの値に変換できない。データが壊れている。 *)

exception Unique_violation of string
(** 事前確認をすり抜けた一意制約違反。Usecase が先に重複を弾いているので、ここに来るのは 確認と書き込みの間に割り込まれたときだけ。 *)
