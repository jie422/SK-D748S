#!/bin/sh

echo "=========================================="
echo "  �维 SK-D748S 光猫 WAN2LAN 配置脚本"
echo "  模式: DHCP 自动获取 WAN IP (U�脚本)"
echo "=========================================="

# 1. 等待 WiFi 接口启动
echo ""
echo "=== 1. 等待 WiFi 接口启动 ==="
WAIT=0
while [ $WAIT -lt 30 ]; do
    if ifconfig | grep -q "ra0"; then
        echo "✅ WiFi 接口已就绪 (用时 ${WAIT} 秒)"
        break
    fi
    sleep 2
    WAIT=$(expr $WAIT + 2)
done
[ $WAIT -ge 30 ] && echo "⚠️ WiFi 未在30秒内出现，继续执行..."
sleep 3

# 2. 配置网桥（将 LAN1 从 br0 移除）
echo ""
echo "=== 2. 配置网桥 ==="
brctl delif br0 eth0.1 2>/dev/null
echo "✅ eth0.1 (LAN1) 已从 br0 移除"
ifconfig eth0.1 up
echo "✅ eth0.1 已启用"

# 3. 停用光口
echo ""
echo "=== 3. 停用光口 ==="
ifconfig oam down 2>/dev/null
ifconfig omci down 2>/dev/null
ifconfig pon down 2>/dev/null
echo "✅ 光口已停用"

# 4. 确保 U �上的 udhcpc 脚本存在
if [ ! -f /tmp/mnt/usb1_1/udhcpc.script ]; then
    echo "⚠️ udhcpc.script 不存在，�建中..."
    cat > /tmp/mnt/usb1_1/udhcpc.script << 'SCRIPT'
#!/bin/sh
case $1 in
    bound)
        ifconfig $interface $ip netmask $subnet up
        route del default 2>/dev/null
        route add default gw $router dev $interface
        echo "nameserver $dns" > /etc/resolv.conf
        echo "nameserver 1.2.4.8" >> /etc/resolv.conf
        echo "nameserver 114.114.114.114" >> /etc/resolv.conf
        echo 1 > /proc/sys/net/ipv4/ip_forward
        echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
        if ! iptables -t nat -L -v -n | grep -q "MASQUERADE.*eth0.1"; then
            iptables -t nat -F
            iptables -F
            iptables -t nat -A POSTROUTING -o eth0.1 -j MASQUERADE
            iptables -P FORWARD ACCEPT
            iptables -A FORWARD -i br0 -o eth0.1 -j ACCEPT
            iptables -A FORWARD -i eth0.1 -o br0 -j ACCEPT
        fi
        echo "✅ DHCP 配置完成！WAN IP: $ip"
        ;;
esac
SCRIPT
    chmod 777 /tmp/mnt/usb1_1/udhcpc.script
    echo "✅ udhcpc.script 已�建"
fi

# 5. 停止旧的 DHCP 客户端
echo ""
echo "=== 4. 启动 DHCP 客户端 ==="
killall udhcpc 2>/dev/null
sleep 1

# 6. 启动 DHCP 客户端（使用 U �脚本）
udhcpc -i eth0.1 -s /tmp/mnt/usb1_1/udhcpc.script -n -q &
sleep 6

# 7. 检查是否获取到 IP
WAN_IP=$(ifconfig eth0.1 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
if [ -n "$WAN_IP" ]; then
    echo "✅ DHCP 获取 IP 成功: $WAN_IP"
else
    echo "⚠️ DHCP 获取 IP 失败，使用备用静态 IP 192.168.1.187"
    ifconfig eth0.1 192.168.1.187 netmask 255.255.255.0 up
    ip route del default 2>/dev/null
    ip route add default via 192.168.1.1 dev eth0.1
    # 补充配置
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
    iptables -t nat -F
    iptables -F
    iptables -t nat -A POSTROUTING -o eth0.1 -j MASQUERADE
    iptables -P FORWARD ACCEPT
    iptables -A FORWARD -i br0 -o eth0.1 -j ACCEPT
    iptables -A FORWARD -i eth0.1 -o br0 -j ACCEPT
    echo "✅ 已设置静态 IP: 192.168.1.187"
fi

# 8. 配置 DNS（补充）
echo ""
echo "=== 5. 配置 DNS（补充） ==="
echo "nameserver 1.2.4.8" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf
echo "nameserver 223.5.5.5" >> /etc/resolv.conf
cat /etc/resolv.conf

# 9. 重启网络服务
echo ""
echo "=== 6. 重启网络服务 ==="
/etc/init.d/network restart 2>/dev/null
sleep 3
echo "✅ 网络服务已重启"

# 10. 显示结果
echo ""
echo "=========================================="
echo "  ✅ 配置完成！"
echo "=========================================="
WAN_IP=$(ifconfig eth0.1 | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}')
echo "📌 LAN1 (eth0.1) → WAN 口"
echo "   WAN IP: ${WAN_IP:-获取失败}"
echo "📌 LAN2-LAN4 → LAN 口"
echo "   LAN IP: 192.168.2.1"
echo "=========================================="

# 11. 测试网络
echo ""
echo "=== 测试网络 ==="
ping -c 2 baidu.com
RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "✅ 网络测试通过！"
else
    echo "⚠️ 网络测试失败，请检查上级路由器连接"
fi

echo ""
echo "=========================================="
echo "  🎯 脚本执行完成！"
echo "=========================================="
