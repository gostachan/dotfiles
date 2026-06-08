DOTFILES_DIR := $(CURDIR)
CONFIG_NAME  ?= default
FLAKE_REF    := $(DOTFILES_DIR)\#$(CONFIG_NAME)

.DEFAULT_GOAL := help
.PHONY: help bootstrap nix-install link switch update

help: ## 利用可能なターゲットを表示
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

bootstrap: nix-install link switch ## マシン全体をセットアップ (nix-install → link → switch)

nix-install: ## Nix が未導入なら Determinate Nix をインストール
	@bash $(DOTFILES_DIR)/.bin/install-nix.sh

link: ## dotfiles を $HOME へ symlink (.bin/install.sh)
	@bash $(DOTFILES_DIR)/.bin/install.sh

switch: ## nix-darwin 設定を適用 (darwin-rebuild switch)
	@sudo darwin-rebuild switch --impure --flake "$(FLAKE_REF)"

update: ## flake.lock を更新
	@nix flake update --flake $(DOTFILES_DIR)
