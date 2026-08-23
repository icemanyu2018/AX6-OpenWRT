#!/bin/bash

# 1. 彻底清除可能冲突的残留
rm -rf package/luci-theme-argon package/luci-app-argon-config package/small package/openwrt-packages

# 2. 引入基础 feeds (这里面已经包含了纯预编译的 dae 和 daed)
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages.git' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small.git' feeds.conf.default

# 3. 仅克隆 argon 主题
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config

# 4. 禁用 Rust 编译
rm -rf feeds/packages/lang/rust

# 5. 设置后台管理 IP 为 192.168.1.1 与主机名
[ -f package/base-files/files/bin/config_generate ] && sed -i 's/192.168.[0-9]*.1/192.168.1.1/g' package/base-files/files/bin/config_generate
[ -f package/base-files/files/bin/config_generate ] && sed -i "s/hostname='.*'/hostname='Redmi-AX6'/g" package/base-files/files/bin/config_generate

# 6. 设置默认 root 密码为空
[ -f package/base-files/files/etc/shadow ] && sed -i 's/root:::0:99999:7:::/root::0:99999:7:::/g' package/base-files/files/etc/shadow

# 7. 设置默认 WiFi
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
