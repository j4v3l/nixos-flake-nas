{ config, pkgs, lib, ... }:

{
  # Secure password management
  # This module handles initial password setup and provides recovery options

  # Enable mutable users temporarily for initial setup
  # Set to false after passwords are configured
  users.mutableUsers = lib.mkDefault true;

  # Initial setup script for passwords
  systemd.services.initial-password-setup = {
    description = "Initial password setup reminder";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Create a reminder file for initial setup
      if [ ! -f /etc/nixos/.passwords-configured ]; then
        echo "===================================================" > /tmp/password-setup-reminder.txt
        echo "IMPORTANT: Configure passwords for your NAS setup" >> /tmp/password-setup-reminder.txt
        echo "===================================================" >> /tmp/password-setup-reminder.txt
        echo "" >> /tmp/password-setup-reminder.txt
        echo "1. Change the initial password:" >> /tmp/password-setup-reminder.txt
        echo "   sudo passwd jager" >> /tmp/password-setup-reminder.txt
        echo "   (Current temporary password: temp123)" >> /tmp/password-setup-reminder.txt
        echo "" >> /tmp/password-setup-reminder.txt
        echo "2. Set Samba password:" >> /tmp/password-setup-reminder.txt
        echo "   sudo smbpasswd -a jager" >> /tmp/password-setup-reminder.txt
        echo "" >> /tmp/password-setup-reminder.txt
        echo "3. After setup, disable mutable users:" >> /tmp/password-setup-reminder.txt
        echo "   Set users.mutableUsers = false in secrets.nix" >> /tmp/password-setup-reminder.txt
        echo "   sudo nixos-rebuild switch" >> /tmp/password-setup-reminder.txt
        echo "" >> /tmp/password-setup-reminder.txt
        echo "4. Mark setup as complete:" >> /tmp/password-setup-reminder.txt
        echo "   sudo touch /etc/nixos/.passwords-configured" >> /tmp/password-setup-reminder.txt
        echo "" >> /tmp/password-setup-reminder.txt
        
        # Display on console during boot
        cat /tmp/password-setup-reminder.txt
        
        # Log to journal
        echo "Password setup required - see /tmp/password-setup-reminder.txt" | systemd-cat -t password-setup
      fi
    '';
  };

  # SSH key management
  # Uncomment and configure after initial password setup
  # users.users.jager.openssh.authorizedKeys.keys = [
  #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-public-key-here"
  # ];

  # Security hardening after initial setup
  environment.etc."nixos/security-checklist" = {
    text = ''
      NixOS NAS Security Checklist
      ============================
      
      Initial Setup:
      □ Set strong password for jager user
      □ Configure Samba password for jager
      □ Test SSH access
      □ Test Samba access
      
      Security Hardening:
      □ Add SSH public keys to authorized_keys
      □ Disable SSH password authentication
      □ Set users.mutableUsers = false
      □ Configure firewall rules
      □ Enable fail2ban
      □ Set up automatic updates
      
      Ongoing Maintenance:
      □ Regular security updates
      □ Monitor system logs
      □ Review access logs
      □ Backup important data
      □ Test recovery procedures
    '';
  };

  # Backup script for critical configurations
  systemd.services.config-backup = {
    description = "Backup critical configurations";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      # Create backup directory
      mkdir -p /home/jager/config-backups
      
      # Backup critical files
      cp -r /etc/nixos /home/jager/config-backups/nixos-$(date +%Y%m%d) || true
      
      # Keep only last 5 backups
      cd /home/jager/config-backups
      ls -t | tail -n +6 | xargs rm -rf
      
      # Set proper ownership
      chown -R jager:users /home/jager/config-backups
    '';
  };

  # Schedule weekly config backups
  systemd.timers.config-backup = {
    description = "Weekly configuration backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
}
