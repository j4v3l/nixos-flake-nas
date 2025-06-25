{ config, pkgs, ... }:

{
  imports = [
    ../../hardware/beelink-mini.nix  # This will be the actual system hardware config
    ../../modules/base.nix
    ../../modules/samba.nix
    ../../modules/secrets.nix
    ../../modules/wifi.nix
    ../../modules/storage.nix
    # Home Manager configuration is now handled through flake.nix
  ];

  networking.hostName = "beelink-mini";
  wifi.enable = true;
  system.stateVersion = "25.05";
}
