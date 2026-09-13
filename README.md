# User API 

- **型の隠蔽でドメインの値を絞る** : `Morph.Seal` / `Morph.SealHom` で value object を封印し、
  `from` を通らない値は存在させない (Parse, don't validate)。
- **依存関係をエフェクトで文脈に持ち上げる**: Usecase は Port を引数でもファンクターでも
  受け取らず、`Locator.call` で effect を perform するだけ。
- **結び目としての main** : エフェクトハンドラを被せた瞬間に実行環境が決まる。
- **副次効果としてのテスト容易性**: モックライブラリは使わず、`Inject` に答える
  ハンドラを書くだけで Port を差し替える。

## アーキテクチャ

```text
                  DTO <- Domain
       ┌──────┐ ←──────────── ┌─────────┐
       │ REST │ ─── 依存 ───→ │ Usecase │ ─┐
       └──────┘ ────────────→ └─────────┘  │
                  DTO -> Domain    │        ├── 依存 ──→ ┌────────┐
                                  依存      │            │ Domain │
                                   ↓        │            └────────┘
                              ┌────────┐ ───┘
                              │  Port  │        Usecase / Port / Domain が
                              └────────┘        Always Valid Domain Model の内側
                                   ↑
                                  実装
                                   │
       ┌───────────┐  Domain -> DTO
       │  Gateway  │ ─────────────────── 依存 ──→ ┌────────┐
       │ (腐敗防止層) │ ←──────────────────────────  │ Driver │
       └───────────┘  Domain <- DTO               └────────┘
```

| レイヤー | 実体 | 役割 |
| --- | --- | --- |
| REST | `lib/rest/` | JSON DTO ⇄ Domain の変換、ルーティング、ドメインエラー → HTTP ステータス |
| Usecase | `lib/usecase/` | Domain と Port の語彙だけで振る舞いを記述。HTTP も DB も知らない |
| Port | `lib/port/` | 「何が欲しいか」の宣言のみ。`Locator.action` (extensible variant) + `Inject` effect |
| Domain | `lib/domain/` | 封印された value object とドメインエラー。どのライブラリにも依存しない |
| Gateway | `lib/gateway/` | **腐敗防止層 (ACL)**。Driver の DTO/エラー語彙と Domain を翻訳する。effect は扱わない |
| Driver | `lib/driver/` | 実際の外部リソース操作。**Domain を知らない** (依存にも入れていない) |
| 結び目 | `lib/app/`, `bin/` | **composition root**。Port の action を Gateway のどの関数に束縛するかを決め、cohttp-eio に配線する |

**Gateway ──実装──→ Port** の矢印は、effect では
「Port の `Inject` に答えるハンドラを書くこと」にあたります。本実装ではその**束縛の決定を
composition root (`lib/app/composition_root.ml`) に集約**し、Gateway 自身は Port を知りません
(`lib/gateway/dune` に `user_api_port` が無い)。「実装を差し替える」とは
composition root が参照する Gateway を差し替えることです。

依存の向きは `dune-project` の `(implicit_transitive_deps false)` によってコンパイル時に強制されます。
たとえば `lib/driver/dune` は `user_api_domain` を列挙していないので、Driver からドメインの型を
参照しようとするとビルドが落ちます。これが腐敗防止層 (Gateway) を置く理由そのものです。
同じ仕組みで、Gateway から Port の action を触ることもできません。

## ディレクトリ

```text
lib/domain/       errors.ml            ドメインエラー (polymorphic variant)
                  morph.ml             Seal / SealHom: 型の隠蔽で値を絞るファンクター
                  objects/user.ml      User = { id; name; email } (各フィールドは封印済み)
lib/port/         locator.ml           type _ action = .. と Inject effect、call
                  user_port.ml         action += Create / Find_by_id / Find_by_email
lib/usecase/      register_user.ml     重複確認 → 登録
                  get_user.ml          取得 → 無ければ `NotFound
lib/driver/       memory/user_store.ml row (int/string) を持つインメモリストア + 自前のエラー型
lib/gateway/      user_gateway.ml      row ⇄ domain / Driver のエラー ⇄ ドメインのエラー の翻訳
lib/rest/         dto/user.ml          request/response DTO と to_domain / of_domain
                  dto/error.ml         ドメインエラー → (HTTP ステータス, メッセージ)
                  handler/users.ml     POST /users, GET /users/:id
                  handler/health.ml    GET /health (Usecase も Port も通さず即答)
                  router.ml            メソッド + パスのディスパッチ
lib/app/          composition_root.ml  Port の action を Gateway の関数へ束縛するエフェクトハンドラ
                  server.ml            listen / serve (cohttp-eio)。store も Port も知らない
bin/main.ml       PORT を読んで起動するだけ
test/             support/ domain/ usecase/ e2e/
```

## 1 リクエストの流れ

`POST /users` を例に、どこで何が起きるか。

1. **`lib/rest/router.ml`** — メソッドとパスで `Handler.Users.register` にディスパッチ。
2. **`lib/rest/dto/user.ml`** — ボディを JSON としてパースし、`Name.from` / `Email.from` で
   **ドメインの値に変換する**。ここで落ちれば 400 で返り、Usecase には届かない。

   ```ocaml
   let to_domain ({ name; email } : register_request) =
     let* name = User.Name.from name in
     let* email = User.Email.from email in
     Ok (name, email)
   ```

3. **`lib/usecase/register_user.ml`** — Port の語彙を組み合わせるだけ。依存は引数に現れない。

   ```ocaml
   let run ~name ~email =
     let* existing = Locator.call @@ User_port.Find_by_email { email } in
     match existing with
     | Some _ -> Error (`Conflict "email")
     | None -> Locator.call @@ User_port.Create { name; email }
   ```

4. **`lib/app/composition_root.ml`** — `Inject` を捕まえて、
   その action を Gateway のどの関数で答えるかを決める。束縛の決定はここに集約されている。

   ```ocaml
   let user_port ~store th =
     try th () with
     | effect Locator.Inject (User_port.Create { name; email }), k ->
         continue k (User_gateway.create ~store ~name ~email)
     | ...

   let handler ~store th = user_port ~store @@ fun () -> th ()
   ```

5. **`lib/gateway/user_gateway.ml`** — Driver を呼び、返ってきた `row` を**検証つきで**
   ドメインに戻す (壊れていれば `` `InternalError ``)。effect のことは知らない純粋な関数。
6. **`lib/app/server.ml`** — cohttp-eio は接続ごとに fiber を fork し、**effect は fiber をまたげない**ので、
   ハンドラはリクエストごとの callback の中で被せる (記事 §6 と同じ制約)。サーバー自身は
   `wrap` を受け取るだけで、`store` も Port も知らない。

   ```ocaml
   (* bin/main.ml *)
   Server.serve ~wrap:(fun th -> Composition_root.handler ~store th) socket
   ```

## ビルド、テスト、起動

OCaml 5.3 以上 (effect 構文 `effect P, k ->` を使うため) と dune 3.24 以上が必要です。

```sh
opam install dune eio eio_main cohttp-eio http uri yojson ppx_yojson_conv logs fmt alcotest

make build   # dune build
make test    # dune runtest (25 ケース)
make fmt     # dune fmt
make run     # PORT=8080 で起動。make run PORT=9090 で変更可
make opam    # dune-project を編集したあと user_api.opam を生成し直す
```

`user_api.opam` は dune が生成したものをコミットしています (dune 3.24 は `_build` 内にしか
書き出さないため、`make opam` で明示的に取り込む運用にしています)。

## API

```sh
# 登録
curl -i -X POST localhost:8080/users -d '{"name":"nymphium","email":"nymphium@example.com"}'
# HTTP/1.1 201 Created
# {"id":1,"name":"nymphium","email":"nymphium@example.com"}

# メールが重複したら 409
curl -i -X POST localhost:8080/users -d '{"name":"dup","email":"nymphium@example.com"}'
# HTTP/1.1 409 Conflict
# {"error":"email already exists"}

# 取得
curl -i localhost:8080/users/1
# HTTP/1.1 200 OK
# {"id":1,"name":"nymphium","email":"nymphium@example.com"}

curl -i localhost:8080/users/999
# HTTP/1.1 404 Not Found
# {"error":"user not found"}

# バリデーション (name は 1〜50 文字、email は "@" の前後が非空)
curl -i -X POST localhost:8080/users -d '{"name":"","email":"nope"}'
# HTTP/1.1 400 Bad Request
# {"error":"invalid name"}

# 死活確認
curl -i localhost:8080/health
# HTTP/1.1 200 OK
# {"status":"ok"}
```

`/health` だけは Usecase も Port も作らず、REST のハンドラで即答しています。
「200 を返せること自体」が答えなのでレイヤーを通す意味がなく、通すと構造だけが増えるためです。
DB への `SELECT 1` のように外部リソースを見に行くようになった時点で Port に切り出します。

データはメモリにだけ保持するので、プロセスを終了すると消えます。

## テスト

`make test` で 25 ケースが走ります。**純粋な中心 (domain / usecase) と、外側の結線をまとめて
踏む e2e** の 3 つだけに絞っています。Gateway・composition root・REST は「翻訳と結線」しかない
薄い層で、単体テストを置くと振る舞いではなく構造をピン留めしてしまい、レイヤーを動かすたびに
壊れるからです。

| 対象 | 何を見ているか |
| --- | --- |
| `test/domain/` | value object のバリデーション境界、`Seal` の同型性、アクセサ |
| `test/usecase/` | **`Inject` に答えるハンドラをモックとして書く** (記事 §5)。重複時に `Create` が呼ばれないことも検証 |
| `test/e2e/` | 空きポートで実際にサーバーを起動して叩く。ルーティング、JSON パース、**Port の束縛漏れ** (書き忘れると実行時 `Effect.Unhandled`)、ドメインエラー → HTTP ステータスをまとめて踏む |

Usecase のテストはこう書けます。モックライブラリは要りません。

```ocaml
let inject : type a. a Locator.action -> a = function
  | User_port.Find_by_email _ -> Ok None
  | User_port.Create { name; email } -> ...; Ok fixture
  | _ -> failwith "unexpected action"
in
Mock.handle { inject } (fun () -> Register_user.run ~name ~email)
```
