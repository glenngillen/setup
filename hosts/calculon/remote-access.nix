{ pkgs, ... }:
let
  baseline = pkgs.writeText "calculon-remote-access-baseline.conf" ''
    pass in quick on lo0 proto tcp to any port { 22, 5900 }
    pass in quick inet proto tcp from 192.168.4.0/22 to 192.168.4.0/22 port { 22, 5900 }
    block drop in quick proto tcp to any port { 22, 5900 }
  '';

  # Preserve Apple's anchor points; only our remote-access anchor is terminal.
  pfConfig = pkgs.writeText "calculon-pf.conf" ''
    scrub-anchor "com.apple/*"
    nat-anchor "com.apple/*"
    rdr-anchor "com.apple/*"
    dummynet-anchor "com.apple/*"
    anchor "calculon-remote-access" quick
    anchor "com.apple/*"
    load anchor "com.apple" from "/etc/pf.anchors/com.apple"
    load anchor "calculon-remote-access" from "/etc/pf.anchors/calculon-remote-access"
  '';

  # Tailscale's utun number changes across reconnects. Discover interfaces by
  # their assigned Tailscale addresses, rather than allowing all VPN interfaces
  # or trusting CGNAT source addresses arriving over Ethernet/Wi-Fi.
  refresh = pkgs.writers.writePython3Bin "calculon-remote-access-firewall" { } ''
    import ipaddress
    import pathlib
    import re
    import subprocess
    import time

    anchor = "calculon-remote-access"
    rules_file = pathlib.Path("/etc/pf.anchors/calculon-remote-access")
    tailscale_v4 = ipaddress.ip_network("100.64.0.0/10")
    tailscale_v6 = ipaddress.ip_network("fd7a:115c:a1e0::/48")


    def run(*args):
        return subprocess.check_output(args, text=True)


    def rules():
        lines = [
            "pass in quick on lo0 proto tcp to any port { 22, 5900 }",
            "pass in quick inet proto tcp from 192.168.4.0/22 "
            "to 192.168.4.0/22 port { 22, 5900 }",
        ]
        interface = ""
        for line in run("/sbin/ifconfig").splitlines():
            if line and not line[0].isspace():
                interface = line.split(":", 1)[0]
            if not re.fullmatch(r"utun[0-9]+", interface):
                continue
            fields = line.split()
            if len(fields) < 2 or fields[0] not in ("inet", "inet6"):
                continue
            address = ipaddress.ip_address(fields[1].split("%", 1)[0])
            network = tailscale_v4 if address.version == 4 else tailscale_v6
            if address not in network:
                continue
            family = "inet" if address.version == 4 else "inet6"
            lines.append(
                f"pass in quick on {interface} {family} proto tcp "
                f"from {network} to {address} port {{ 22, 5900 }}"
            )
        # Covers both IP families, including globally routable LAN IPv6.
        lines.append("block drop in quick proto tcp to any port { 22, 5900 }")
        return "\n".join(lines) + "\n"


    previous = None
    while True:
        current = rules()
        if current != previous or rules_file.read_text() != current:
            rules_file.write_text(current)
            subprocess.run(
                ["/sbin/pfctl", "-n", "-a", anchor, "-f", str(rules_file)],
                check=True,
            )
            subprocess.run(
                ["/sbin/pfctl", "-a", anchor, "-f", str(rules_file)],
                check=True,
            )
            previous = current
        time.sleep(5)
  '';
in
{
  # This host owns the main PF configuration. Keep custom rules in the anchor;
  # normal refreshes reload only that anchor, preserving other PF users' state.
  environment.etc."pf.conf".source = pfConfig;

  system.activationScripts.postActivation.text = ''
    # Start with LAN + loopback only. The daemon adds live Tailscale interfaces.
    /bin/mkdir -p /etc/pf.anchors
    /usr/bin/install -m 644 ${baseline} /etc/pf.anchors/calculon-remote-access
    /sbin/pfctl -nf /etc/pf.conf
    /sbin/pfctl -f /etc/pf.conf
  '';

  launchd.daemons.calculon-remote-access-firewall = {
    script = ''
      set -eu
      # The boot-time load also restores the main anchor after a reboot.
      /usr/bin/install -m 644 ${baseline} /etc/pf.anchors/calculon-remote-access
      /sbin/pfctl -f /etc/pf.conf
      if ! /sbin/pfctl -s info | /usr/bin/grep -q 'Status: Enabled'; then
        /sbin/pfctl -e
      fi
      exec ${refresh}/bin/calculon-remote-access-firewall
    '';
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      StandardOutPath = "/var/log/calculon-remote-access-firewall.log";
      StandardErrorPath = "/var/log/calculon-remote-access-firewall.log";
    };
  };
}
