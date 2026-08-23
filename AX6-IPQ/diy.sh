#!/bin/bash

# 1. 彻底清除冲突目录
rm -rf package/luci-theme-argon package/luci-app-argon-config package/small package/openwrt-packages package/daed package/dae package/luci-app-nikki package/luci-app-daed package/luci-app-daed-next

# 2. 引入基础扩展源
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages.git' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small.git' feeds.conf.default

# 3. 单独克隆官方维护的独立 LuCI 适配仓库到 package/ 目录
git clone --depth 1 https://github.com/sbwml/luci-app-daed package/luci-app-daed
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config

# 4. 解除所有 Makefile 中针对内核版本与 BTF 的限制
find package/ -type f -name "Makefile" 2>/dev/null | xargs sed -i -E 's/[+@]*[A-Za-z0-9_]*vmlinux-btf//g' 2>/dev/null || true
find package/ -type f -name "Makefile" 2>/dev/null | xargs sed -i 's/@!LINUX_6_6//g' 2>/dev/null || true

# 5. 禁用 Rust 编译
rm -rf feeds/packages/lang/rust

# 6. 设置后台管理 IP 为 192.168.1.1 与主机名
[ -f package/base-files/files/bin/config_generate ] && sed -i 's/192.168.[0-9]*.1/192.168.1.1/g' package/base-files/files/bin/config_generate
[ -f package/base-files/files/bin/config_generate ] && sed -i "s/hostname='.*'/hostname='Redmi-AX6'/g" package/base-files/files/bin/config_generate

# 7. 设置默认 root 密码为空
[ -f package/base-files/files/etc/shadow ] && sed -i 's/root:::0:99999:7:::/root::0:99999:7:::/g' package/base-files/files/etc/shadow

# 8. 设置默认 WiFi
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
