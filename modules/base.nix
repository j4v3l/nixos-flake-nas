# Base system configuration for Beelink ME mini NAS
{ config, pkgs, lib, ... }:

{
  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Time zone and locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # User configuration
  users.users.jager = {
    isNormalUser = true;
    initialPassword = "temp123";  # CHANGE IMMEDIATELY AFTER FIRST LOGIN
    extraGroups = [ "wheel" "docker" "users" "networkmanager" "storage" ];
    createHome = true;
    home = "/home/jager";
    shell = pkgs.zsh;
  };

  # Enable mutable users for initial setup
  users.mutableUsers = true;

  # Enable services
  virtualisation.docker.enable = true;
  programs.zsh.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    # Core utilities
    vim
    nano
    git
    curl
    wget
    htop
    btop
    tree
    unzip
    zip
    rsync
    screen
    tmux
    
    # Network tools
    nmap
    iperf3
    speedtest-cli
    inetutils  # ping, telnet, etc.
    nettools   # netstat, route, etc.
    
    # System monitoring
    iotop
    lm_sensors
    smartmontools
    
    # File management
    mc  # Midnight Commander
    ranger
    
    # Development tools
    gcc
    gnumake
    
    # Fonts
    nerd-fonts.fira-code
    
    # Modern replacements
    fastfetch  # System info
    eza        # Better ls
    bat        # Better cat
    fd         # Better find
    ripgrep    # Better grep
    dust       # Better du
    duf        # Better df
    

    
    # System administration essentials
    sudo
    systemd
  ];

  # Security configurations
  security.sudo.wheelNeedsPassword = false;  # Disable for convenience on NAS

  # Networking
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 139 445 ]; # SSH, Samba
    allowedUDPPorts = [ 137 138 ]; # NetBIOS
  };

  # SSH configuration with security hardening
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;  # Use SSH keys only
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      Protocol = 2;
      X11Forwarding = false;
    };
    extraConfig = ''
      AllowUsers jager
    '';
  };

  # Fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      multipliers = "2 4 8 16 32 64";
      maxtime = "168h"; # 1 week
    };
  };

  # System maintenance
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Automatic updates
  system.autoUpgrade = {
    enable = true;
    dates = "04:00";
    allowReboot = false;
    flake = "/home/jager/nixos-flake-nas";
    flags = [ "--update-input" "nixpkgs" ];
    randomizedDelaySec = "30min";
  };

  # Additional services
  services.logrotate.enable = true;
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # Additional shell configuration
  programs.bash.shellInit = ''
    # Custom prompt for server
    export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
  '';
}
