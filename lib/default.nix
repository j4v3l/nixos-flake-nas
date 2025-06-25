# Common library functions for NixOS NAS configuration
{ lib, ... }:

{
  # Helper function to create service user with proper permissions
  mkNasUser = name: extraGroups: {
    users.users.${name} = {
      isNormalUser = true;
      extraGroups = [ "users" ] ++ extraGroups;
      createHome = true;
      home = "/home/${name}";
    };
  };

  # Helper function to create data directory with proper permissions
  mkDataDirectory = path: owner: group: {
    systemd.tmpfiles.rules = [
      "d ${path} 0755 ${owner} ${group} -"
    ];
  };

  # Helper function for common firewall rules
  mkLocalNetworkFirewall = ports: {
    networking.firewall = {
      allowedTCPPorts = ports.tcp or [];
      allowedUDPPorts = ports.udp or [];
      extraCommands = lib.concatStringsSep "\n" (
        lib.flatten [
          (map (port: [
            "iptables -A nixos-fw -s 192.168.0.0/16 -p tcp --dport ${toString port} -j ACCEPT"
            "iptables -A nixos-fw -s 10.0.0.0/8 -p tcp --dport ${toString port} -j ACCEPT"
            "iptables -A nixos-fw -s 172.16.0.0/12 -p tcp --dport ${toString port} -j ACCEPT"
          ]) (ports.tcp or []))
          (map (port: [
            "iptables -A nixos-fw -s 192.168.0.0/16 -p udp --dport ${toString port} -j ACCEPT"
            "iptables -A nixos-fw -s 10.0.0.0/8 -p udp --dport ${toString port} -j ACCEPT"
            "iptables -A nixos-fw -s 172.16.0.0/12 -p udp --dport ${toString port} -j ACCEPT"
          ]) (ports.udp or []))
        ]
      );
    };
  };
} 