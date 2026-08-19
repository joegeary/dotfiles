#!/bin/sh
# OnCourse FortiVPN split-DNS. Installed to /etc/ppp/ip-up.d/ by install.sh.
#
# The servers are NOT set here on purpose - they come from the VPN on every
# connect and must never be hardcoded. install.sh sets two keys in
# /etc/openfortivpn/omarchy.conf to make that work cleanly:
#
#   pppd-use-peerdns = 1  pppd learns ppp0's resolvers from the tunnel, writes
#                         them to /etc/ppp/resolv.conf, and the stock ip-up hook
#                         00-dns.sh applies them to resolved - all dynamic.
#   set-dns = 0           openfortivpn does NOT also push DNS itself. Its push
#                         runs *after* the ip-up hooks and resets ppp0's search
#                         domains, silently wiping this hook on every connect
#                         (the bug that kept coming back). With it off, the
#                         ordering is deterministic: 00-dns.sh sets servers,
#                         then this hook (50-) adds the domains, and nothing
#                         clobbers them afterward.
#
# So this hook owns only the split-DNS policy: which zones ride the tunnel, and
# not making it the catch-all resolver. pppd passes the interface as $IFNAME.

case "$IFNAME" in
  ppp*) ;;
  *) exit 0 ;;
esac

# sws.local -> search + routing domain (so bare `oc-kermit` resolves too).
# 10.in-addr.arpa -> routing-only (~) domain for 10.x reverse lookups.
# oncoursesystems.com -> routing-only (~) domain: split-horizon zone whose
# internal view (e.g. devel/prod.k8s.oncoursesystems.com -> the 10.x cluster
# VIPs) only the corporate resolver serves. Without it these leak to public
# DNS and return Cloudflare-proxied IPs that never answer on the API port 6443.
resolvectl domain "$IFNAME" sws.local '~10.in-addr.arpa' '~oncoursesystems.com'

# Split DNS, not full takeover: only the domains above go over the tunnel;
# everything else stays on the normal (ethernet) resolver.
resolvectl default-route "$IFNAME" false
