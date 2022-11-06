#!/bin/sh

smartdns_Bin="/etc/storage/smartdns-mipsel"
smartdns_Conf="/etc/storage/smartdns_m.conf"
smartdns_port="6053"
smartdns_Bin_Name="smartdns-mipsel"

# iptables -t nat -L
# netstat -tulpn | grep LISTEN

updateconf() {
    # https://cdn.jsdelivr.net/gh/Apocalypsor/SmartDNS-GFWList/smartdns_gfw_domain.conf

    curl -s -k -f --connect-timeout 30 --retry 5 --retry-delay 5 https://cdn.jsdelivr.net/gh/Apocalypsor/SmartDNS-GFWList/smartdns_gfw_domain.conf >/tmp/smartdns_gfw_domain.conf

    if [ -s "/tmp/smartdns_gfw_domain.conf" ]; then
        logger -t "SmartDNS" "smartdns_gfw_domain.conf 下载成功"
    else
        logger -t "SmartDNS" "smartdns_gfw_domain.conf 下载失败"
    fi

    # https://anti-ad.net/anti-ad-for-smartdns.conf
    # https://cdn.jsdelivr.net/gh/privacy-protection-tools/dead-horse/anti-ad-white-for-smartdns.txt

    curl -s -k -f --connect-timeout 30 --retry 5 --retry-delay 5 https://anti-ad.net/anti-ad-for-smartdns.conf >/tmp/anti-ad-for-smartdns.conf

    if [ -s "/tmp/anti-ad-for-smartdns.conf" ]; then
        logger -t "SmartDNS" "anti-ad-for-smartdns.conf 下载成功"
    else
        logger -t "SmartDNS" "anti-ad-for-smartdns.conf 下载失败"
    fi

    # https://neodev.team/lite_smartdns.conf
    curl -s -k -f --connect-timeout 30 --retry 5 --retry-delay 5 https://neodev.team/lite_smartdns.conf >/tmp/lite_smartdns.conf

    if [ -s "/tmp/lite_smartdns.conf" ]; then
        logger -t "SmartDNS" "/tmp/lite_smartdns.conf 下载成功"
    else
        logger -t "SmartDNS" "/tmp/lite_smartdns.conf 下载失败"
    fi

}

set_iptable() {

    IPS="$(ifconfig | grep "inet addr" | grep -v ":127" | grep "Bcast" | awk '{print $2}' | awk -F : '{print $2}')"

    for IP in $IPS; do
        iptables -t nat -A PREROUTING -p tcp -d $IP --dport 53 -j REDIRECT --to-ports $smartdns_port >/dev/null 2>&1
        iptables -t nat -A PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-ports $smartdns_port >/dev/null 2>&1
        logger -t "SmartDNS" "iptables $IP 53 to $smartdns_port"
    done
}

clear_iptable() {
    OLD_PORT="$smartdns_port"
    IPS="$(ifconfig | grep "inet addr" | grep -v ":127" | grep "Bcast" | awk '{print $2}' | awk -F : '{print $2}')"
    for IP in $IPS; do
        iptables -t nat -D PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-ports $OLD_PORT >/dev/null 2>&1
        iptables -t nat -D PREROUTING -p tcp -d $IP --dport 53 -j REDIRECT --to-ports $OLD_PORT >/dev/null 2>&1
        logger -t "SmartDNS" "UNSET iptables $IP 53 to $smartdns_port"
    done
}

start_smartdns() {

    updateconf

    killall "$smartdns_Bin_Name" &>/dev/null
    sleep 5
    $smartdns_Bin -f -c $smartdns_Conf -x  2&>1 | logger -t "SmartDNS" &
    sleep 5
    smartdns_process=$(pidof smartdns-mipsel | awk '{ print $1 }')
    if [ "$smartdns_process"x = x ]; then
        logger -t "SmartDNS" "启动失败．．．"
        exit
    else
        logger -t "SmartDNS" "smartdns 进程已启动 PID:$smartdns_process"
        set_iptable
    fi
}

stop_smartdns() {
    killall "$smartdns_Bin_Name" &>/dev/null
    logger -t "SmartDNS" "killall  $smartdns_Bin_Name"
    clear_iptable
}

case $1 in
start)
    start_smartdns
    ;;
stop)
    stop_smartdns
    ;;
setiptable)
    # set_iptable
    smartdns_process=$(pidof smartdns-mipsel | awk '{ print $1 }')
    if [ "$smartdns_process"x = x ]; then
        logger -t "SmartDNS" "未检测到smartdns进程，不修改iptable"
        exit
    else
        logger -t "SmartDNS" "smartdns 进程已启动 PID:$smartdns_process，修改iptable"
        set_iptable
    fi
    ;;
cleariptable)
    clear_iptable
    ;;
smartdns)
    $smartdns_Bin -f -c $smartdns_Conf -x  2&>1 | logger -t "SmartDNS" &
    ;;
updateconf)
    updateconf
    ;;
*)
    echo "start stop setiptable cleariptable smartdns updateconf "
    ;;
esac
