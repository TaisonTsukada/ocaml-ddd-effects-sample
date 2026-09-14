# User API (OCaml 5 Effect による DDD サンプル)

OCaml 5 で正式導入された **Effect Handler（エフェクトハンドラ）** を使って、
クリーンアーキテクチャ / DDD の **依存性注入 (DI)** を実現するサンプルアプリケーションです。

---

## 3分でわかる「Effect Handler による DI」

「Effect Handler という言葉は聞いたことがあるけれど、何が嬉しいのかよくわからない」という方向けに、このリポジトリの設計思想を解説します。

### 1. 直感的なイメージ：「再開できる例外」

プログラミング言語の「例外 (Exception)」を思い浮かべてください。

- **例外**: `raise` すると外側の `try ... with` まで一気にジャンプし、**そこで処理は終了**します。
- **Effect**: `perform` すると外側のハンドラまでジャンプしますが、**ハンドラが答えを返してくれたら、元の場所から処理をそのまま再開**できます。

```text
【通常の例外】
Usecase ──(raise)──> [ハンドラ] ──> ここで終わり（二度と戻らない）

【Effect Handler】
Usecase ──(perform "データ頂戴")──> [ハンドラ]
   │                                     │
   │ <─────(continue "はいどうぞ")───────┘
   ↓
Usecase: データを受け取って続きを実行！
```

つまり、Effect とは **「深い関数の中から外側へ向けて『これやって！』とリクエストを投げ、外側から結果を受け取って続きを走らせる仕組み」** です。

### 2. 従来の DI が抱えていた悩み

DDD やオニオンアーキテクチャでは、「ビジネスロジック (Usecase) は DB や外部サービスの詳細に依存したくない」という原則があります。従来の言語や OCaml でこれをやろうとすると、以下の壁にぶつかりがちでした。

1. **引数渡し (関数の引数に repository を渡す)**
   - Usecase を呼び出す REST コントローラなども Repository を知らなければならず、引数のバケツリレーが発生する。
2. **OCaml の Functor (モジュール引数で抽象化する)**
   - 型安全だが、シグネチャの定義やモジュール展開が重厚になり、型パズルになりやすい。
3. **グローバル変数 / シングルトン**
   - テスト時にモックを差し替えるのが困難で、並行テストで状態が壊れる。

### 3. Effect による解決：シグネチャから依存関係が消える！

Effect を使うと、Usecase のシグネチャから **DB やリポジトリに関する引数が一切消えます**。

```ocaml
(* lib/usecase/register_user.ml *)

let run ~(name : Objects.User.Name.t) ~(email : Objects.User.Email.t) : outcome =
  (* 1. 「このメールアドレスのユーザーいる？」と外側に叫ぶ *)
  match Locator.call @@ User_port.Find_by_email { email } with
  | Some _ -> Email_taken
  | None ->
      (* 2. 「ユーザーを保存して！」と外側に叫ぶ *)
      Registered (Locator.call @@ User_port.Create { name; email })
```

- 関数の引数は `~name` と `~email` だけ。純粋な業務データしか受け取りません。
- Usecase は「誰がどうやって保存するか（PostgreSQLなのか、インメモリなのか、テスト用のダミーなのか）」を一切知りません。

### 4. 誰が答えるのか？：一番外側でハンドラを被せるだけ

Usecase が投げたリクエスト (`perform`) は、外側で「ハンドラ」を被せることで解釈します。

- **本番環境 (`lib/app/composition_root.ml`)**:
  「`Create` されたら、本物の DB (Driver) を呼んで結果を返す」というハンドラを被せる。
- **テスト (`test/usecase/test_register_user.ml`)**:
  「`Find_by_email` されたら、即座に `None` を返す」というハンドラをその場で被せる。

**専用のモックライブラリは不要**です。OCaml の普通のパターンマッチでハンドラを書くだけで、自由自在に依存を差し替えられます。

---

## アーキテクチャ概要

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

| レイヤー | ディレクトリ | 役割 |
| --- | --- | --- |
| **REST** | `lib/rest/` | HTTP (JSON) ⇄ Domain の変換、ルーティング。入力のバリデーションはここで完結する |
| **Usecase** | `lib/usecase/` | 業務ロジックの記述。Port の語彙を使って Effect を投げる。結果は自分の ADT で返す |
| **Port** | `lib/port/` | 「何が欲しいか」の語彙（シグネチャ）の宣言。実装は持たない |
| **Domain** | `lib/domain/` | 封印された Value Object（正しい値しか存在できない） |
| **Gateway** | `lib/gateway/` | **腐敗防止層 (ACL)**。Driver の生データと Domain オブジェクトを相互変換する。回復不能な失敗は例外で落とす |
| **Driver** | `lib/driver/` | 外部ストレージ操作。Domain のことは一切知らない |
| **結び目** | `lib/app/`, `bin/` | **Composition Root**。どの Port のリクエストをどの Gateway に繋ぐかを決定する |

---

## コードで追う Effect DI の仕組み

### 1. Port: お願いの語彙を定義する (`lib/port/`)

Port は「どんな操作を要求できるか」という型（GADT + Extensible Variant）を定義するだけです。

```ocaml
(* lib/port/user_port.ml *)
type _ Locator.action +=
  | Create : { name : M.Name.t; email : M.Email.t } -> M.t Locator.action
  | Find_by_id : { id : M.Id.t } -> M.t option Locator.action
  | Find_by_email : { email : M.Email.t } -> M.t option Locator.action
```
`-> M.t Locator.action` は、「このリクエストを投げると、最終的に `User.t` が返ってくる」という約束を表します。

### 2. Usecase: お願いを投げる (`lib/usecase/`)

`Locator.call` を呼ぶと、内部で `Effect.perform` が走り、処理が一時停止してハンドラに制御が移ります。

```ocaml
(* lib/usecase/register_user.ml *)
let run ~name ~email =
  match Locator.call @@ User_port.Find_by_email { email } with
  | Some _ -> Email_taken
  | None -> Registered (Locator.call @@ User_port.Create { name; email })
```

### 3. テスト: その場で答える (`test/usecase/`)

テストでは、Port のリクエストに対してダミーの値を返すハンドラをサッと書くだけです。

```ocaml
(* test/usecase/test_register_user.ml *)
let inject : type a. a Locator.action -> a = function
  | User_port.Find_by_email _ -> None             (* 未登録として答える *)
  | User_port.Create { name; email } -> fixture   (* fixture を返す *)
  | _ -> failwith "unexpected action"
in
(* ハンドラの下で Usecase を走らせる *)
Mock.handle { inject } (fun () -> Register_user.run ~name ~email)
```

### 4. 本番: 本物のストレージに繋ぐ (`lib/app/composition_root.ml`)

本番のアプリケーションでは、Gateway（本物のストレージ翻訳層）に関数を繋ぎます。
`continue k value` を呼ぶことで、一時停止していた Usecase が受け取った `value` と共に再開します。

```ocaml
(* lib/app/composition_root.ml *)
let user_port ~store th =
  try th () with
  | effect Locator.Inject (User_port.Create { name; email }), k ->
      continue k (User_gateway.create ~store ~name ~email)
  | effect Locator.Inject (User_port.Find_by_email { email }), k ->
      continue k (User_gateway.find_by_email ~store ~email)
  | ...
```

---

## 本サンプルの設計のこだわり

### 1. Port は `Result` を返さない（ADT と例外の明確な分離）

よくある設計として「Port が `(User.t, error) result` を返す」というものがありますが、本サンプルではあえて **Result を使っていません**。

| 起きた事象 | 性質 | 表現方法 | 理由 |
| --- | --- | --- | --- |
| **入力不正** (空文字など) | 境界のバリデーション | `Result` (400) | アプリケーションの入口 (REST DTO) で弾く |
| **ユーザー不在・メール重複** | 業務上の想定内分岐 | **Usecase の ADT** | 失敗ではなく正常なビジネス結果のひとつ |
| **DB 接続断・行データ破損** | 回復不能な不測の事態 | **例外で落とす** | 業務ロジックで回復できないため型に持ち回らない |

Port が `Result` を返さないため、Usecase 内に不要なエラー伝播のボイラープレート（`Result.bind` や `let*`）が一切登場しません。

### 2. Always Valid Domain Model (Parse, don't validate)

ドメインの値（`User.Name.t`, `User.Email.t`）は、ファンクター（`Morph.SealHom`）によって型レベルで隠蔽されています。
バリデーションを通過した値しかドメインの型になれないため、**Usecase や Domain 層に届いた値は 100% 正しいことがコンパイル時に保証**されます。

### 3. コンパイル時にアーキテクチャの境界を強制

`dune-project` に `(implicit_transitive_deps false)` を設定しています。
これにより、例えば「Driver が勝手に Domain の型を参照する」といったルール違反コードを書くと、コンパイル時にビルドエラーになります。

---

## コードリーディングの推奨順序

1. [`lib/port/user_port.ml`](lib/port/user_port.ml) : どんなリクエスト（語彙）があるかを見る
2. [`lib/usecase/register_user.ml`](lib/usecase/register_user.ml) : Usecase がどう語彙を呼んでいるかを見る
3. [`test/usecase/test_register_user.ml`](test/usecase/test_register_user.ml) : テストでどうモックハンドラを被せているかを見る
4. [`lib/app/composition_root.ml`](lib/app/composition_root.ml) : 本番でどうハンドラを結線しているかを見る
5. [`lib/gateway/user_gateway.ml`](lib/gateway/user_gateway.ml) : Gateway でどう Driver と Domain を翻訳しているかを見る

---

## ビルド・テスト・実行

### 必要要件
- OCaml 5.3 以上 (Effect ハンドラ構文 `effect P, k ->` を利用)
- Dune 3.24 以上

### コマンド
```sh
# 依存ライブラリのインストール
opam install dune eio eio_main cohttp-eio http uri yojson ppx_yojson_conv logs fmt alcotest

# ビルド
make build

# テスト実行 (25 ケース)
make test

# コード整形
make fmt

# サーバー起動 (デフォルト: 8080 ポート)
make run
# ポート指定の場合: make run PORT=9090
```

### API 動作確認

```sh
# 1. ユーザー登録 (201 Created)
curl -i -X POST localhost:8080/users \
  -d '{"name":"nymphium","email":"nymphium@example.com"}'

# 2. メール重複登録 (409 Conflict)
curl -i -X POST localhost:8080/users \
  -d '{"name":"dup","email":"nymphium@example.com"}'

# 3. ユーザー取得 (200 OK)
curl -i localhost:8080/users/1

# 4. 存在しないユーザー取得 (404 Not Found)
curl -i localhost:8080/users/999

# 5. バリデーションエラー (400 Bad Request)
curl -i -X POST localhost:8080/users \
  -d '{"name":"","email":"invalid"}'

# 6. ヘルスチェック (200 OK)
curl -i localhost:8080/health
```
