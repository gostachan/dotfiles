{ pkgs }:

with pkgs;

let
  python314_4 = python314.override {
    sourceVersion = {
      major = "3";
      minor = "14";
      patch = "4";
      suffix = "";
    };
    hash = "sha256-2SPFEwPjjiSRNvwb3zVo1W7LAyFO/e9IUWF209f6rvg=";
  };

  languages = [
    cabal-install
    ghc
    go
    nodejs
    pnpm
    (lib.meta.hiPrio python314_4)
  ];

  languageServers = [
    clang-tools
    gopls
    haskell-language-server
    pyright
    sqls
    terraform-ls
  ];

  cliTools = [
    buf
    codex
    claude-code
    colima
    docker-client
    gh
    ipcalc
    marp-cli
    mise
    neovim
    podman
    ripgrep
    snowflake-cli
    terraform
    tmux
    tree-sitter
    uv
    zsh
  ];
in
languages ++ languageServers ++ cliTools
