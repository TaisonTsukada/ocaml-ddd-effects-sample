DUNE ?= opam exec -- dune
PORT ?= 8080

.PHONY: all build test fmt run opam clean

all: build

build: ## ビルド
	$(DUNE) build

test: ## 全レイヤーのテスト (domain / usecase / gateway / rest / e2e)
	$(DUNE) runtest

fmt: ## ocamlformat で整形
	$(DUNE) fmt

run: ## API を起動 (make run PORT=9090)
	PORT=$(PORT) $(DUNE) exec user_api

opam: ## dune-project から user_api.opam を生成し直す
	$(DUNE) build user_api.opam
	cp -f _build/default/user_api.opam user_api.opam
	chmod 644 user_api.opam

clean:
	$(DUNE) clean
