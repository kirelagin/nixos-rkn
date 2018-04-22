# TODO: What about IPv6?

{ config, lib, pkgs, ... }:

with lib;

let
  routes = pkgs.stdenv.mkDerivation {
    name = "rkn-openvpn-routes";
    src = builtins.fetchurl {
      url = "https://api.antizapret.info/group.php?data=ip";
    };
    buildInputs = [ pkgs.curl pkgs.python3 ];
    buildCommand = ''
       python3 ${./rkn.py} < "$src" > "$out"
    '';
  };
in

{
  options = {
    networking.rkn.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to configure OpenVPN to fuck RKN.
      '';
    };

    networking.rkn.instance = mkOption {
      type = types.str;
      example = "server";
      description = ''
        OpenVPN instance to use for routing.
	This modules assumes that you have a working OpenVPN config.
      '';
    };

    networking.rkn.externalInterface = mkOption {
      type = types.str;
      example = "enp0s1";
      description = ''
        The name of the network interface over which packets from VPN
	will be forwarded.
      '';
    };
  };

  config = with config.networking.rkn; {
    services.openvpn.servers."${instance}" = {
      config = pkgs.lib.readFile routes;
      up = ''
        echo 1 > "/proc/sys/net/ipv4/conf/$dev/forwarding"
        iptables -w -A FORWARD -i "$dev" -j ACCEPT
        iptables -w -t nat -A POSTROUTING -o "${externalInterface}" -j MASQUERADE
      '';
      down = ''
        iptables -w -t nat -D POSTROUTING -o "${externalInterface}" -j MASQUERADE
        iptables -w -D FORWARD -i "$dev" -j ACCEPT
      '';
    };

    # TODO: This enables forwarding on the external interface but does not limit
    # it with any firewall rules (the `nat` module does the same :/).
    boot.kernel.sysctl."net.ipv4.conf.${externalInterface}.forwarding" = 1;

    networking.firewall.extraCommands = ''
      iptables -w -N nixos-rkn-fwd
      iptables -w -A nixos-rkn-fwd -m state --state ESTABLISHED,RELATED -j ACCEPT
      iptables -w -A FORWARD -j nixos-rkn-fwd
    '';
    networking.firewall.extraStopCommands = ''
      iptables -w -D FORWARD -j nixos-rkn-fwd 2>/dev/null || true
      iptables -w -F nixos-rkn-fwd 2>/dev/null || true
      iptables -w -X nixos-rkn-fwd 2>/dev/null || true
    '';
  };
}
