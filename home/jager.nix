{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "jager";
  home.homeDirectory = "/home/jager";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "25.05";

  # User-specific packages
  home.packages = with pkgs; [
    # Development tools
    git # git and git-lfs
    tree # list directory contents
    tmux # terminal multiplexer
    
    # Archive and compression tools
    unzip # extract zip files
    zip # create zip files
    p7zip # create and extract 7z files
    
    # Modern CLI tools
    bat   # Modern cat with syntax highlighting
    eza   # Modern ls with colors and icons
    fzf   # Fuzzy finder for command line
    ranger # CLI file manager with vi-like keybindings
    
    # Zsh plugins and tools
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    
    # Terminal compatibility
    ghostty  # Terminal emulator and terminfo
    
    # System information
    fastfetch # system information (faster than neofetch)
    lsof # list open files
    dysk  # Modern disk usage analyzer
    
    # Network tools (user-specific)
    nmap # network mapper
    iperf3 # network performance tester
    
    # Fonts for user applications
    nerd-fonts.fira-code
  ];

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Jager";
    userEmail = "jager@beelink-mini.local";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  # Bash configuration
  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      # Custom aliases for NAS management (enhanced with modern tools)
      alias ll='eza -la --git --header --icons'
      alias la='eza -a --icons'
      alias l='eza --icons'
      alias ls='eza --color=auto --icons'
      alias lt='eza -T --icons'           # Tree view with icons
      alias lg='eza -la --git --icons'    # Git status in listing with icons
      alias ..='cd ..'
      alias ...='cd ../..'
      
      # Modern cat replacement
      alias cat='bat'
      alias ccat='/usr/bin/cat'   # Original cat when needed
      alias bat-plain='bat --style=plain'  # Bat without decorations
      
      # NixOS Flake management aliases
      alias rebuild='sudo nixos-rebuild switch --flake /etc/nixos#beelink-mini'
      alias rebuild-boot='sudo nixos-rebuild boot --flake /etc/nixos#beelink-mini'
      alias rebuild-test='sudo nixos-rebuild test --flake /etc/nixos#beelink-mini'
      alias rebuild-dry='sudo nixos-rebuild dry-run --flake /etc/nixos#beelink-mini'
      alias flake-update='sudo nix flake update /etc/nixos'
      alias flake-check='nix flake check /etc/nixos'
      
      # Home Manager is integrated - use these instead
      alias hm-rebuild='rebuild'  # Home Manager rebuilds with system
      alias hm-test='rebuild-test'  # Test both system and HM config
      alias hm-gen='ls -la /nix/var/nix/profiles/system* | tail -10'  # System generations include HM
      alias hm-switch-gen='sudo nix-env --switch-generation --profile /nix/var/nix/profiles/system'
      
      # Update workflow aliases
      alias update-all='flake-update && rebuild'  # Update inputs and rebuild everything
      alias update-check='flake-update && rebuild-dry'  # Update and preview changes
      
      # Samba management aliases
      alias samba-status='sudo systemctl status smbd'
      alias samba-start='sudo systemctl start smbd'
      alias samba-stop='sudo systemctl stop smbd'
      alias samba-restart='sudo systemctl restart smbd'
      alias samba-reload='sudo systemctl reload smbd'
      alias samba-config='sudo testparm'
      alias samba-users='sudo smbstatus'
      alias samba-shares='sudo smbstatus --shares'
      alias samba-locks='sudo smbstatus --locks'
      alias nas-logs='sudo journalctl -u smbd -f'
      alias samba-logs='sudo journalctl -u smbd --since "1 hour ago"'
      
      # Disk usage and monitoring aliases
      alias df='df -h'
      alias du='du -h'
      alias check-data='df -h /mnt/data'
      alias check-root='df -h /'
      alias check-boot='df -h /boot'
      alias check-all-drives='df -h /mnt/drive* /mnt/data'
      alias diskusage='df -h'
      alias diskfree='df -h'
      alias dysk-data='dysk /mnt/data'
      alias dysk-root='dysk /'
      alias dysk-all='dysk'
      alias space='dysk'
      alias usage='dysk --type d'  # Show directories only
      
      # NVMe drive management
      alias list-nvme='sudo nvme list'
      alias nvme-health='sudo smartctl -H /dev/nvme*n1'
      alias nvme-temp='sudo smartctl -A /dev/nvme*n1 | grep -i temperature'
      alias nvme-info='sudo nvme id-ctrl /dev/nvme0n1 | head -20'
      alias drive-health='sudo smartctl -H /dev/nvme*n1'
      alias drive-temp='for d in /dev/nvme*n1; do echo "$d:"; sudo smartctl -A "$d" | grep -i temp || echo "No temp data"; done'
      
      # Storage monitoring
      alias iostat-nvme='iostat -x 1 5 nvme*'
      alias iotop-nvme='sudo iotop -a -o -d 2'
      alias storage-status='systemctl status storage-setup storage-monitor'
      alias storage-logs='sudo journalctl -u storage-setup -u storage-monitor -f'
      
      # System monitoring
      alias temps='sensors 2>/dev/null || echo "lm-sensors not available"'
      alias meminfo='free -h'
      alias cpuinfo='lscpu'
      alias processes='htop'
      alias ports='ss -tulpn'
      alias listening='ss -tulpn | grep LISTEN'
      
      # Network and services
      alias services='systemctl list-units --type=service --state=running'
      alias failed='systemctl list-units --failed'
      alias journal='sudo journalctl -f'
      alias bootlog='sudo journalctl -b'
      
      # Quick navigation
      alias cddata='cd /mnt/data'
      alias cddrive1='cd /mnt/drive1'
      alias cddrive2='cd /mnt/drive2'
      alias cddrive3='cd /mnt/drive3'
      alias cddrive4='cd /mnt/drive4'
      alias cddrive5='cd /mnt/drive5'
      alias cdetc='cd /etc/nixos'
      alias cdlogs='cd /var/log'
      
      # File management
      alias fm='ranger'    # Start ranger file manager
      alias r='ranger'     # Short alias for ranger
      
      # FZF shortcuts
      alias fzf-files='fzf --preview "bat --style=numbers --color=always --line-range :500 {}"'
      alias fzf-dirs='find . -type d | fzf'
      
      # Starship prompt will be configured separately
    '';
    
    historyControl = [ "ignoredups" "ignorespace" ];
    historySize = 10000;
  };

  # Zsh configuration with modern features
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    # History settings
    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };
    
    # Shell aliases (migrated from bash)
    shellAliases = {
      # Modern CLI replacements with icons
      ll = "eza -la --git --header --icons";
      la = "eza -a --icons";
      l = "eza --icons";
      ls = "eza --color=auto --icons";
      lt = "eza -T --icons";           # Tree view with icons
      lg = "eza -la --git --icons";    # Git status in listing with icons
      ".." = "cd ..";
      "..." = "cd ../..";
      
      # Modern cat replacement
      cat = "bat";
      ccat = "/usr/bin/cat";   # Original cat when needed
      bat-plain = "bat --style=plain";  # Bat without decorations
      
      # NixOS Flake management aliases
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#beelink-mini";
      rebuild-boot = "sudo nixos-rebuild boot --flake /etc/nixos#beelink-mini";
      rebuild-test = "sudo nixos-rebuild test --flake /etc/nixos#beelink-mini";
      rebuild-dry = "sudo nixos-rebuild dry-run --flake /etc/nixos#beelink-mini";
      flake-update = "sudo nix flake update /etc/nixos";
      flake-check = "nix flake check /etc/nixos";
      
      # Home Manager is integrated - use these instead
      hm-rebuild = "rebuild";  # Home Manager rebuilds with system
      hm-test = "rebuild-test";  # Test both system and HM config
      hm-gen = "ls -la /nix/var/nix/profiles/system* | tail -10";  # System generations include HM
      hm-switch-gen = "sudo nix-env --switch-generation --profile /nix/var/nix/profiles/system";
      
      # Update workflow aliases
      update-all = "flake-update && rebuild";  # Update inputs and rebuild everything
      update-check = "flake-update && rebuild-dry";  # Update and preview changes
      
      # Samba management aliases
      samba-status = "sudo systemctl status smbd";
      samba-start = "sudo systemctl start smbd";
      samba-stop = "sudo systemctl stop smbd";
      samba-restart = "sudo systemctl restart smbd";
      samba-reload = "sudo systemctl reload smbd";
      samba-config = "sudo testparm";
      samba-users = "sudo smbstatus";
      samba-shares = "sudo smbstatus --shares";
      samba-locks = "sudo smbstatus --locks";
      nas-logs = "sudo journalctl -u smbd -f";
      samba-logs = "sudo journalctl -u smbd --since '1 hour ago'";
      
      # Disk usage and monitoring aliases
      df = "df -h";
      du = "du -h";
      check-data = "df -h /mnt/data";
      check-root = "df -h /";
      check-boot = "df -h /boot";
      check-all-drives = "df -h /mnt/drive* /mnt/data";
      diskusage = "df -h";
      diskfree = "df -h";
      dysk-data = "dysk /mnt/data";
      dysk-root = "dysk /";
      dysk-all = "dysk";
      space = "dysk";
      usage = "dysk --type d";  # Show directories only
      
      # NVMe drive management
      list-nvme = "sudo nvme list";
      nvme-health = "sudo smartctl -H /dev/nvme*n1";
      nvme-temp = "sudo smartctl -A /dev/nvme*n1 | grep -i temperature";
      nvme-info = "sudo nvme id-ctrl /dev/nvme0n1 | head -20";
      drive-health = "sudo smartctl -H /dev/nvme*n1";
      drive-temp = "for d in /dev/nvme*n1; do echo \"$d:\"; sudo smartctl -A \"$d\" | grep -i temp || echo 'No temp data'; done";
      
      # Storage monitoring
      iostat-nvme = "iostat -x 1 5 nvme*";
      iotop-nvme = "sudo iotop -a -o -d 2";
      storage-status = "systemctl status storage-setup storage-monitor";
      storage-logs = "sudo journalctl -u storage-setup -u storage-monitor -f";
      
      # System monitoring
      temps = "sensors 2>/dev/null || echo 'lm-sensors not available'";
      meminfo = "free -h";
      cpuinfo = "lscpu";
      processes = "htop";
      ports = "ss -tulpn";
      listening = "ss -tulpn | grep LISTEN";
      
      # Network and services
      services = "systemctl list-units --type=service --state=running";
      failed = "systemctl list-units --failed";
      journal = "sudo journalctl -f";
      bootlog = "sudo journalctl -b";
      
      # Quick navigation
      cddata = "cd /mnt/data";
      cddrive1 = "cd /mnt/drive1";
      cddrive2 = "cd /mnt/drive2";
      cddrive3 = "cd /mnt/drive3";
      cddrive4 = "cd /mnt/drive4";
      cddrive5 = "cd /mnt/drive5";
      cdetc = "cd /etc/nixos";
      cdlogs = "cd /var/log";
      
      # File management
      fm = "ranger";    # Start ranger file manager
      r = "ranger";     # Short alias for ranger
      
      # FZF shortcuts
      fzf-files = "fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'";
      fzf-dirs = "find . -type d | fzf";
    };
    
    # Additional zsh configuration
    initContent = ''
      # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
      # Initialization code that may require console input (password prompts, [y/n]
      # confirmations, etc.) must go above this block; everything else may go below.
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi
      
      # Completion settings
      setopt AUTO_LIST
      setopt AUTO_MENU
      setopt COMPLETE_IN_WORD
      setopt GLOB_COMPLETE
      
      # History settings
      setopt HIST_EXPIRE_DUPS_FIRST
      setopt HIST_IGNORE_DUPS
      setopt HIST_IGNORE_ALL_DUPS
      setopt HIST_FIND_NO_DUPS
      setopt HIST_SAVE_NO_DUPS
      setopt SHARE_HISTORY
      setopt APPEND_HISTORY
      setopt INC_APPEND_HISTORY
      
      # Navigation
      setopt AUTO_CD
      setopt AUTO_PUSHD
      setopt PUSHD_IGNORE_DUPS
      setopt PUSHD_SILENT
      
      # Correction
      setopt CORRECT
      setopt CORRECT_ALL
      
      # Key bindings
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      bindkey '^[[1;5C' forward-word
      bindkey '^[[1;5D' backward-word
      
      # Better completion
      zstyle ':completion:*' menu select
      zstyle ':completion:*' group-name '''
      zstyle ':completion:*:descriptions' format '[%d]'
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*:*:kill:*' menu yes select
      zstyle ':completion:*:kill:*'   force-list always
      zstyle ':completion:*:*:killall:*' menu yes select
      zstyle ':completion:*:killall:*'   force-list always
      
      # Directory stack
      alias d='dirs -v | head -10'
      alias 1='cd -'
      alias 2='cd -2'
      alias 3='cd -3'
      alias 4='cd -4'
      alias 5='cd -5'
    '';
    
    # Oh My Zsh configuration
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "docker"
        "systemd"
        "cp"
        "history-substring-search"
        "colored-man-pages"
        "command-not-found"
        "extract"
        "z"
      ];
      theme = "robbyrussell";  # You can change this to any theme you prefer
    };
  };

  # Vim configuration
  programs.vim = {
    enable = true;
    defaultEditor = true;
    settings = {
      number = true;
      relativenumber = false;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
    };
    extraConfig = ''
      " Basic vim configuration for server management
      syntax on
      set background=dark
      set showcmd
      set showmatch
      set ignorecase
      set smartcase
      set incsearch
      set hlsearch
      
      " File handling
      set autoread
      set noswapfile
      set nobackup
      
      " Better navigation
      set scrolloff=8
      set sidescrolloff=8
    '';
  };

  # Htop configuration
  programs.htop = {
    enable = true;
    settings = {
      show_cpu_frequency = true;
      show_cpu_temperature = true;
      show_program_path = false;
      highlight_base_name = true;
      highlight_threads = true;
    };
  };

  # Tmux configuration for remote management
  programs.tmux = {
    enable = true;
    clock24 = true;
    historyLimit = 10000;
    keyMode = "vi";
    extraConfig = ''
      # Better prefix key
      unbind C-b
      set -g prefix C-a
      bind C-a send-prefix
      
      # Quick pane switching
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      
      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"
      
      # Status bar
      set -g status-bg black
      set -g status-fg white
      set -g status-left '[#S] '
      set -g status-right '#H %Y-%m-%d %H:%M'
      
      # Better colors
      set -g default-terminal "screen-256color"
    '';
  };

  # SSH configuration
  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
        ServerAliveInterval 60
        ServerAliveCountMax 3
        TCPKeepAlive yes
        
      # Add your commonly accessed hosts here
      # Host myserver
      #   HostName 192.168.1.100
      #   User jager
      #   Port 22
    '';
  };

  # Bat configuration (modern cat replacement)
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      italic-text = "always";
      style = "numbers,changes,header";
      pager = "less -FR";
    };
  };

  # FZF configuration
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    defaultCommand = "find . -type f";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
    ];
    historyWidgetOptions = [
      "--sort"
      "--exact"
    ];
  };

  # Eza configuration (modern ls replacement)
  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    icons = "always";
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # XDG directories for better file organization
  xdg.enable = true;
  
  # User services (if needed later)
  # systemd.user.services = {};
  
  # Font configuration
  fonts.fontconfig.enable = true;

  # Environment variables
  home.sessionVariables = {
    EDITOR = "vim";
    BROWSER = "echo";  # No browser needed on a NAS
    PAGER = "less";
    # Terminal compatibility - fallback for ghostty
    TERM = "xterm-256color";
    # Font configuration for applications
    FONTCONFIG_FILE = "${config.xdg.configHome}/fontconfig/fonts.conf";
  };
} 