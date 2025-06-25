{ config, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader configuration (systemd-boot for UEFI systems)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.jager = {
    isNormalUser = true;
    # Initial password hash for "temp123" - CHANGE IMMEDIATELY AFTER FIRST LOGIN
    # Generated with: mkpasswd -m sha-512
    initialPassword = "temp123";
    extraGroups = [ "wheel" "docker" "users" ];
    # Create home directory
    createHome = true;
    home = "/home/jager";
    # Set up zsh shell
    shell = pkgs.zsh;
  };

  # Enable mutable users for initial setup
  # Set to false after passwords are properly configured
  users.mutableUsers = true;

  virtualisation.docker.enable = true;

  # Enable zsh system-wide
  programs.zsh.enable = true;

  # Essential system packages (keep minimal, user packages go to home-manager)
  environment.systemPackages = with pkgs; [
    # Network utilities (system-wide)
    curl
    wget
    rsync
    
    # System monitoring (system-wide)
    htop
    iotop
    
    # Basic text editing (system-wide for emergency access)
    vim
    nano
    
    # Network debugging (system-wide)
    inetutils  # ping, telnet, etc.
    nettools   # netstat, route, etc.
    
    # System administration essentials
    sudo
    systemd
    
    # Fonts
    nerd-fonts.fira-code
  ];

  # Security configurations
  security.sudo.wheelNeedsPassword = true;
  
  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH only by default
    # Samba ports will be configured in the samba module
  };

  # Enable automatic security updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false; # Set to true if you want automatic reboots
    channel = "https://nixos.org/channels/nixos-25.05";
    dates = "daily";
    randomizedDelaySec = "30min";
  };

  # Additional security services
  services = {
    logrotate.enable = true;
    
    # SSH hardening
    openssh = {
      enable = true;
      settings = {
        # Allow password authentication initially for setup, disable after SSH keys are configured
        PasswordAuthentication = true; # Change to false after SSH key setup
        PermitRootLogin = "no";
        Protocol = 2;
        X11Forwarding = false;
        # Additional security settings
        MaxAuthTries = 3;
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
      };
    };
  };
}
