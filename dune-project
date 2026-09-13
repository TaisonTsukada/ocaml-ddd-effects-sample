(lang dune 3.24)

(name user_api)

(generate_opam_files true)

; 各レイヤーが「自分が直接依存すると宣言したライブラリ」しか参照できなくする。
; スライドの依存の向き (REST -> Usecase -> Port -> Domain, Gateway -> Driver) を
; コンパイル時に強制するための設定。
(implicit_transitive_deps false)

(source
 (github TaisonTsukada/ocaml-ddd-effects-sample))

(authors "TaisonTsukada")

(maintainers "TaisonTsukada")

(license MIT)

(package
 (name user_api)
 (synopsis
  "User registration API: effect-based dependency injection on the REST/Usecase/Port/Gateway/Driver architecture")
 (description
  "Reimplementation of nymphium's \"dependencies lifted into effects\" article, laid out along the REST / Usecase / Port / Gateway (anti-corruption layer) / Driver architecture. Built on OCaml 5 effects, Eio and cohttp-eio.")
 (depends
  (ocaml
   (>= 5.3))
  dune
  eio
  eio_main
  cohttp-eio
  http
  uri
  yojson
  ppx_yojson_conv
  logs
  fmt
  (alcotest :with-test)))
