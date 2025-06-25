{ config, lib, ... }:

{
  # Simple WiFi configuration using NetworkManager
  options.wifi.enable = lib.mkEnableOption "WiFi support";
  
  config = lib.mkIf config.wifi.enable {
    # Enable NetworkManager for WiFi management
    networking.networkmanager = {
      enable = true;
      wifi = {
        # Enable WiFi
        backend = "wpa_supplicant";
        # Allow NetworkManager to manage all WiFi devices
        powersave = false;
      };
    };
    
    # Disable wpa_supplicant to avoid conflicts with NetworkManager
    networking.wireless.enable = false;
    
    # Add user to networkmanager group for WiFi control
    users.users.jager.extraGroups = [ "networkmanager" ];
    
    # Enable WiFi hardware support
    hardware.enableRedistributableFirmware = true;
    
    # Ensure NetworkManager service starts properly
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
