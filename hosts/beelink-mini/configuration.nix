{ config, pkgs, ... }:

{
  imports = [
    ../../hardware/beelink-mini.nix  # This will be the actual system hardware config
    ../../modules/base.nix
    ../../modules/samba.nix
    ../../modules/secrets.nix
    ../../modules/wifi.nix
    ../../modules/storage.nix
    ../../modules/motd.nix
    # Home Manager configuration is now handled through flake.nix
  ];

  networking.hostName = "beelink-mini";
  wifi.enable = true;
  storage.enable = true;  # Enable advanced storage management for 6-slot NAS
  motd.enable = true;     # Enable server-style MOTD
  system.stateVersion = "25.05";
}
