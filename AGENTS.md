# Agent Instructions

This file is shared by Codex and Claude Code. `CLAUDE.md` is a symlink to this file, so update this file when changing agent-facing project knowledge.

## Repository

- This repository manages personal dotfiles.
- Keep edits scoped to files in this repository unless explicitly asked otherwise.
- Do not rewrite generated runtime state unless the task is specifically about that state.
- Be careful with shell startup files because they affect login shells, interactive shells, and Nix devShell behavior.

## Package Management

- Prefer Nix for CLI tools, development tools, and libraries.
- Use `nix-darwin` for macOS system-level configuration.
- Use `home-manager` for user-level configuration.
- Avoid adding new Homebrew formula dependencies.
- If Homebrew remains necessary, keep it limited to casks for macOS GUI apps or binary apps that are not practical to manage with Nix.
- Tools that are difficult to manage practically with Nix may be declared as Homebrew casks through `nix-darwin`.
- Shared Nix package ownership lives in `nix/packages.nix`; update that list instead of adding ad-hoc installation scripts.
- macOS-only nix-darwin configuration lives in `nix/darwin.nix`.
- The Nix flake entrypoint is `flake.nix`; the portable darwin configuration name is `default`.
- Machine bootstrap entrypoint is `make bootstrap` (composes `nix-install` → `link` → `switch`); standalone scripts live in `.bin/` (`install-nix.sh`, `install.sh`). nix-darwin derives `system.primaryUser` from the current non-root user via `SUDO_USER` / `USER`, so run darwin rebuilds with `--impure`.
- Install Karabiner-Elements as a macOS-only Nix package in `nix/darwin.nix`; do not enable `services.karabiner-elements` unless the nix-darwin module matches the package layout.
- Nixpkgs unfree exceptions live in `nix/nixpkgs-config.nix`; prefer narrow `allowUnfreePredicate` entries over globally allowing all unfree packages.
- Manage Claude Code as the Nix package `claude-code`; do not manage Claude login/session state in dotfiles.
- Manage Neovim LSP server binaries with Nix packages, not Mason auto-install.

## Nix And PATH

- Nix devShell paths should stay ahead of system paths.
- Watch for shell initialization code that rebuilds `PATH`, especially `mise`, `path_helper`, and Homebrew shell setup.
- In Nix shells, avoid changing `PATH` in a way that moves `/nix/store/.../bin` behind `/usr/bin` or `/opt/homebrew/bin`.

## Editing Notes

- This repo uses a whitelist-style `.gitignore`; add new tracked root files explicitly.
- Do not remove unrelated user changes from the working tree.
- Keep documentation concise and actionable.
