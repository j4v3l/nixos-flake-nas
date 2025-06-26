# Base system configuration for Beelink ME mini NAS
{ config, pkgs, lib, ... }:

{
  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Time zone and locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Console configuration with enhanced font support
  console = {
    font = "ter-v32n";  # Terminus font - excellent console font with good glyph support
    packages = with pkgs; [ 
      terminus_font 
      powerline-fonts
      kbd  # Provides additional console fonts
    ];
    keyMap = "us";
    earlySetup = true;
    colors = [
      "1e1e2e" # base - Catppuccin Mocha theme for console
      "f38ba8" # red  
      "a6e3a1" # green
      "f9e2af" # yellow
      "89b4fa" # blue
      "f5c2e7" # magenta
      "94e2d5" # cyan
      "bac2de" # white
      "585b70" # bright black
      "f38ba8" # bright red
      "a6e3a1" # bright green
      "f9e2af" # bright yellow
      "89b4fa" # bright blue
      "f5c2e7" # bright magenta
      "94e2d5" # bright cyan
      "a6adc8" # bright white
    ];
  };

  # Add Nerd Fonts for terminal emulators (when you SSH in)
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono  
    nerd-fonts.hack
    terminus_font
    powerline-fonts
  ];

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
    # Custom prompt for server with better colors
    export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    
    # Show available console fonts
    alias show-console-fonts='ls -la /run/current-system/sw/share/consolefonts/ 2>/dev/null || echo "Console fonts not found in expected location"'
    
    # Console font management aliases  
    alias set-font-large='sudo setfont ter-v32n'
    alias set-font-medium='sudo setfont ter-v22n' 
    alias set-font-small='sudo setfont ter-v16n'
    alias show-current-font='showconsolefont 2>/dev/null || echo "showconsolefont not available"'
  '';

  # ZSH configuration with font management aliases
  programs.zsh = {
    enable = true;
    shellAliases = {
      # Console font management aliases  
      "set-font-large" = "sudo setfont ter-v32n";
      "set-font-medium" = "sudo setfont ter-v22n";
      "set-font-small" = "sudo setfont ter-v16n";
      "show-console-fonts" = "ls -la /run/current-system/sw/share/consolefonts/ 2>/dev/null || echo 'Console fonts not found in expected location'";
      "show-current-font" = "echo 'showconsolefont only works on direct console (Ctrl+Alt+F1-F6), not SSH'";
    };
    ohMyZsh = {
      enable = true;
      theme = "";
    };
  };

  # Disable command-not-found to prevent database errors
  programs.command-not-found.enable = false;
}
