#!/bin/sh
echo "=== 开始配置 WAN2LAN ==="
echo "等待 WiFi 接口启动..."
WAIT=0
while [ $WAIT -lt 30 ]; do
    if ifconfig | grep -q "ra0"; then
        echo "✅ WiFi 接口已就绪"
        break
    fi
    sleep 2
    WAIT=$(expr $WAIT + 2)
done
[ $WAIT -ge 30 ] && echo "⚠️ WiFi 未在30秒内出现，继续执行..."
sleep 3

echo "=== 停止网络 ==="
/etc/init.d/network stop 2>/dev/null
sleep 2

echo "=== 配置网络 ==="
brctl delif br0 eth0.1 2>/dev/null
ifconfig eth0.1 192.168.1.187 netmask 255.255.255.0 up
ip route del default 2>/dev/null
ip route add default via 192.168.1.1 dev eth0.1
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter

echo "=== 配置 DNS ==="
echo "nameserver 1.2.4.8" > /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf
echo "nameserver 223.5.5.5" >> /etc/resolv.conf

echo "=== 配置防火墙 ==="
iptables -t nat -F
iptables -F
iptables -t nat -A POSTROUTING -o eth0.1 -j MASQUERADE
iptables -P FORWARD ACCEPT
iptables -A FORWARD -i br0 -o eth0.1 -j ACCEPT
iptables -A FORWARD -i eth0.1 -o br0 -j ACCEPT

echo "=== 停用光口 ==="
ifconfig oam down 2>/dev/null
ifconfig omci down 2>/dev/null
ifconfig pon down 2>/dev/null

echo "=== 重启网络 ==="
/etc/init.d/network restart 2>/dev/null
sleep 3

echo ""
echo "✅ 配置完成！LAN1 为 WAN 口，其他口为 LAN 口"
echo "📌 WAN IP: 192.168.1.187"
echo "📌 LAN IP: 192.168.2.1"
echo "📌 DNS: 1.2.4.8, 8.8.8.8, 114.114.114.114, 223.5.5.5"
echo ""
echo "=== 测试网络 ==="
ping -c 2 baidu.com || echo "⚠️ 网络测试失败"
