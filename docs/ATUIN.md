# Atuin Shell History Sync

[Atuin](https://atuin.sh/) is a magical shell history sync tool that replaces your shell history with a SQLite database, and syncs it across all of your machines. It provides enhanced history search with full-text search, end-to-end encryption, and cross-machine synchronization.

## Features

- **Enhanced shell history**: Replace your shell history with a SQLite database
- **Cross-machine sync**: Sync your shell history across all your machines  
- **End-to-end encryption**: All data is encrypted and only readable by you
- **Advanced search**: Fuzzy search, full-text search, and filtering by host/directory
- **Privacy focused**: Filter out sensitive commands automatically
- **Shell integration**: Works with Bash, Zsh, Fish, and NuShell

## Configuration

The Atuin module is enabled in `hosts/beelink-mini/configuration.nix`:

```nix
atuin = {
  enable = true;
  daemon = {
    enable = true;
    logLevel = "info";
    syncFrequency = "15m";
  };
};
```

## User Configuration

The Home Manager configuration in `home/jager.nix` includes:

```nix
programs.atuin = {
  enable = true;
  enableBashIntegration = true;
  enableZshIntegration = true;
  daemon = {
    enable = true;
  };
  settings = {
    # Sync every 15 minutes
    auto_sync = true;
    sync_frequency = "15m";
    
    # Search configuration
    search_mode = "fuzzy";
    filter_mode = "global";
    show_preview = true;
    
    # Privacy filters
    secrets_filter = true;
    history_filter = [
      "^ls$" "^ll$" "^la$" "^cd$" "^pwd$" "^exit$" "^clear$"
    ];
  };
};
```

## Setup Instructions

### First Time Setup

1. **Deploy the configuration**:

   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#beelink-mini
   ```

2. **Register with Atuin Cloud** (or use your own server):

   ```bash
   atuin register -u your_username -e your_email@example.com
   ```

3. **Import existing history**:

   ```bash
   atuin import auto
   ```

4. **Start syncing**:

   ```bash
   atuin sync
   ```

### Adding Additional Machines

1. Get your encryption key from the first machine:

   ```bash
   atuin key
   ```

2. On the new machine, login with your credentials:

   ```bash
   atuin login -u your_username -k your_encryption_key
   ```

3. Sync your history:

   ```bash
   atuin sync
   ```

## Usage

Once configured, Atuin enhances your shell experience:

### Search History

- **Ctrl+R**: Opens Atuin's enhanced history search
- **Up Arrow**: Search history with current command as prefix (if enabled)

### Command Line Usage

```bash
# Manual sync
atuin sync

# Search history
atuin search "git commit"

# View statistics
atuin stats

# Check daemon status
atuin-status

# View daemon logs
atuin-logs
```

### Search Modes

- **Fuzzy**: Default mode, matches parts of commands in any order
- **Prefix**: Matches commands that start with your query
- **Fulltext**: Searches in full command text including arguments

### Filtering

- **Global**: Search across all sessions and hosts
- **Host**: Filter to current machine only
- **Session**: Filter to current shell session
- **Directory**: Filter to current directory

## Self-Hosting (Optional)

To run your own Atuin sync server instead of using Atuin Cloud:

1. **Enable the server** in your configuration:

   ```nix
   atuin = {
     enable = true;
     server = {
       enable = true;
       port = 8888;
       registrationDisabled = true;  # Disable after initial setup
     };
     daemon = {
       enable = true;
       openFirewall = true;  # Open port 8888
     };
   };
   ```

2. **Update sync server** in Home Manager:

   ```nix
   programs.atuin.settings.sync_address = "http://localhost:8888";
   ```

3. **Rebuild and register**:

   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#beelink-mini
   atuin register -u admin -e admin@local
   ```

## Security

- All history data is end-to-end encrypted
- Your encryption key never leaves your machines
- Sensitive commands are automatically filtered
- Server operators cannot read your history
- Local SQLite database is used for fast access

## Troubleshooting

### Daemon Issues

```bash
# Check daemon status
systemctl --user status atuin-daemon

# View daemon logs
journalctl --user -u atuin-daemon -f

# Restart daemon
systemctl --user restart atuin-daemon
```

### Sync Issues

```bash
# Check network connectivity
atuin doctor

# Force sync
atuin sync --force

# Check sync status
atuin stats
```

### Common Issues

1. **Connection timeouts**: Increase timeout values in configuration:

   ```nix
   programs.atuin.settings = {
     network_connect_timeout = 120;
     network_timeout = 120;
   };
   ```

2. **Large history database**: Use history filtering to reduce size:

   ```nix
   programs.atuin.settings.history_filter = [
     "^ls" "^cd" "^pwd" "^exit" "^clear"
   ];
   ```

3. **Permission errors**: Ensure proper directory permissions:

   ```bash
   ls -la ~/.local/share/atuin/
   ls -la ~/.config/atuin/
   ```

## Migration

If you're migrating from another shell history tool:

1. **From bash/zsh built-in history**:

   ```bash
   atuin import auto
   ```

2. **From other tools**: Check `atuin import --help` for supported formats

## Useful Aliases

The system provides these helpful aliases:

- `atuin-status`: Check daemon status
- `atuin-restart`: Restart daemon
- `atuin-logs`: View daemon logs
- `atuin-sync`: Manual sync
- `atuin-search`: Search history
- `atuin-stats`: View statistics

## Links

- [Atuin Documentation](https://docs.atuin.sh/)
- [Atuin GitHub](https://github.com/atuinsh/atuin)
- [Atuin Community Forum](https://forum.atuin.sh/)
