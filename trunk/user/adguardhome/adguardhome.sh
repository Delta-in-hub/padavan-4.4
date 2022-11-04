#!/bin/sh

change_dns() {
  if [ "$(nvram get adg_redirect)" = 1 ]; then
    sed -i '/no-resolv/d' /etc/storage/dnsmasq/dnsmasq.conf
    sed -i '/server=127.0.0.1/d' /etc/storage/dnsmasq/dnsmasq.conf
    cat >>/etc/storage/dnsmasq/dnsmasq.conf <<EOF
no-resolv
server=127.0.0.1#5335
EOF
    /sbin/restart_dhcpd
    logger -t "AdGuardHome" "ADD dnsmasq upstream server 127.0.0.1#5335"
  fi
}
del_dns() {
  sed -i '/no-resolv/d' /etc/storage/dnsmasq/dnsmasq.conf
  sed -i '/server=127.0.0.1#5335/d' /etc/storage/dnsmasq/dnsmasq.conf
  /sbin/restart_dhcpd
  logger -t "AdGuardHome" "DEL dnsmasq upstream server 127.0.0.1#5335"
}

set_iptable() {
  if [ "$(nvram get adg_redirect)" = 2 ]; then
    IPS="$(ifconfig | grep "inet addr" | grep -v ":127" | grep "Bcast" | awk '{print $2}' | awk -F : '{print $2}')"
    for IP in $IPS; do
      iptables -t nat -A PREROUTING -p tcp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
      iptables -t nat -A PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
      logger -t "AdGuardHome" "iptables $IP 53 to 5335"
    done

    IPS="$(ifconfig | grep "inet6 addr" | grep -v " fe80::" | grep -v " ::1" | grep "Global" | awk '{print $3}')"
    for IP in $IPS; do
      ip6tables -t nat -A PREROUTING -p tcp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
      ip6tables -t nat -A PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
      logger -t "AdGuardHome" "ip6tables $IP 53 to 5335"
    done
    logger -t "AdGuardHome" "iptables REDIRECT 53端口 to 5335"
  fi
}

clear_iptable() {
  OLD_PORT="5335"
  IPS="$(ifconfig | grep "inet addr" | grep -v ":127" | grep "Bcast" | awk '{print $2}' | awk -F : '{print $2}')"
  for IP in $IPS; do
    iptables -t nat -D PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-ports $OLD_PORT >/dev/null 2>&1
    iptables -t nat -D PREROUTING -p tcp -d $IP --dport 53 -j REDIRECT --to-ports $OLD_PORT >/dev/null 2>&1
  done

  IPS="$(ifconfig | grep "inet6 addr" | grep -v " fe80::" | grep -v " ::1" | grep "Global" | awk '{print $3}')"
  for IP in $IPS; do
    ip6tables -t nat -D PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-ports $OLD_PORT >/dev/null 2>&1
    ip6tables -t nat -D PREROUTING -p tcp -d $IP --dport 53 -j REDIRECT --to-ports $OLD_PORT >/dev/null 2>&1
  done
  logger -t "AdGuardHome" "UNSET iptables REDIRECT 53端口 to 5335"

}

getconfig() {
  adg_file="/etc/storage/adg.sh"
  if [ ! -f "$adg_file" ] || [ ! -s "$adg_file" ]; then
    cat >"$adg_file" <<-\EEE
bind_host: 0.0.0.0
bind_port: 3030
auth_name: admin
auth_pass: admin
language: zh-cn
rlimit_nofile: 0
dns:
  bind_host: 0.0.0.0
  port: 5335
  protection_enabled: true
  filtering_enabled: true
  blocking_mode: nxdomain
  blocked_response_ttl: 10
  querylog_enabled: true
  ratelimit: 20
  ratelimit_whitelist: []
  refuse_any: true
  bootstrap_dns:
  - 223.5.5.5
  all_servers: true
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts: []
  parental_sensitivity: 0
  parental_enabled: false
  safesearch_enabled: false
  safebrowsing_enabled: false
  resolveraddress: ""
  upstream_dns:
  - 223.5.5.5
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  certificate_chain: ""
  private_key: ""
filters:
- enabled: true
  url: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
  name: AdGuard Simplified Domain Names filter
  id: 1
- enabled: true
  url: https://adaway.org/hosts.txt
  name: AdAway
  id: 2
user_rules: []
dhcp:
  enabled: false
  interface_name: ""
  gateway_ip: ""
  subnet_mask: ""
  range_start: ""
  range_end: ""
  lease_duration: 86400
  icmp_timeout_msec: 1000
clients: []
log_file: ""
verbose: false
schema_version: 3

EEE
    chmod 755 "$adg_file"
    logger -t "AdGuardHome" "Construct /etc/storage/adg.sh"
  fi
  logger -t "AdGuardHome" "配置文件/etc/storage/adg.sh存在"
}

start_adg() {
  mkdir -p /tmp/AdGuardHome
  logger -t "AdGuardHome" "AdGuard Home v0.108.0-b.20"
  if [ ! -f "/usr/bin/AdGuardHome" ]; then
    # cp /usr/bin/AdGuardHome /tmp/AdGuardHome/AdGuardHome
    logger -t "AdGuardHome" "AdGuardHome not found!!!!"
    exit 1
  fi
  getconfig
  change_dns
  set_iptable
  logger -t "AdGuardHome" "AdGuardHome开始运行, listen port must be 5335."
  eval "/usr/bin/AdGuardHome -c $adg_file -w /tmp/AdGuardHome -v | logger -t 'AdGuardHome'" &

}
stop_adg() {
  rm -rf /tmp/AdGuardHome
  killall -9 AdGuardHome
  del_dns
  clear_iptable
  logger -t "AdGuardHome" "AdGuardHome 停止"

}

case $1 in
start)
  start_adg
  ;;
stop)
  stop_adg
  ;;
*)
  echo "需要参数"
  ;;
esac
