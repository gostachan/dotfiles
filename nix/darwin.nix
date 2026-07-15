{ lib, pkgs, primaryUser, ... }:

{
  nix.enable = false;

  nixpkgs.config = import ./nixpkgs-config.nix { inherit lib; };
  nixpkgs.overlays = import ./overlays.nix;
  nixpkgs.hostPlatform = "aarch64-darwin";

  environment.systemPackages =
    (import ./packages.nix { inherit pkgs; })
    ++ [
      pkgs.karabiner-elements
    ];

  programs.zsh.enable = true;

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  fonts.packages = [
    pkgs.nerd-fonts.hack
  ];

  homebrew = {
    enable = true;
    casks = [
      "keyboardcleantool"
    ];
  };

  system.defaults.dock.mru-spaces = false;

  system.primaryUser = primaryUser;
  system.stateVersion = 6;

}
