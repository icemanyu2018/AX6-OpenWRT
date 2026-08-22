#!/bin/bash

# 1. 注入第三方源以提供完整的 daed 和 nikki 依赖
sed -i '$a src-git nikki https://github.com/nikkinikki-org/luci-app-nikki.git;main' feeds.conf.default
sed -i '$a src-git daed https://github.com/sbwml/luci-app-daed.git;main' feeds.conf.default
sed -i '$a src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master' feeds.conf.default

# 2. 彻底禁用 Rust 编译以防 404
rm -rf feeds/packages/lang/rust

# 3. 设置后台管理 IP 为 192.168.1.1 与主机名
[ -f package/base-files/files/bin/config_generate ] && sed -i 's/192.168.[0-9]*.1/192.168.1.1/g' package/base-files/files/bin/config_generate
[ -f package/base-files/files/bin/config_generate ] && sed -i "s/hostname='.*'/hostname='Redmi-AX6'/g" package/base-files/files/bin/config_generate

# 4. 设置默认 root 密码为空
[ -f package/base-files/files/etc/shadow ] && sed -i 's/root:::0:99999:7:::/root::0:99999:7:::/g' package/base-files/files/etc/shadow

# 5. 设置默认 WiFi (2.4G: redmi-ax6-2.4g, 5G: redmiax6-5g, 密码: 123456789)
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-wifi << 'EOF'
#!/sh
uci -q batch << 'UCIBATCH'
set wireless.@wifi-device[0].disabled='0'
set wireless.@wifi-device[1].disabled='0'
UCIBATCH

for iface in $(uci show wireless | grep '=wifi-iface' | cut -d'.' -f2 | cut -d'=' -f1); do
    device=$(uci -q get wireless.${iface}.device)
    band=$(uci -q get wireless.${device}.band)
    
    uci -q set wireless.${iface}.disabled='0'
    uci -q set wireless.${iface}.encryption='psk2+ccmp'
    uci -q set wireless.${iface}.key='123456789'
    
    if [ "$band" = "5g" ] || [ "$device" = "radio1" ]; then
        uci -q set wireless.${iface}.ssid='redmiax6-5g'
    else
        uci -q set wireless.${iface}.ssid='redmi-ax6-2.4g'
    fi
done

uci commit wireless
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-wifi
