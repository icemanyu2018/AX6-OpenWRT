
#!/bin/bash

# 1. 清理冲突目录
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/applications/luci-app-nikki
rm -rf feeds/packages/net/nikki
rm -rf feeds/packages/net/mihomo
rm -rf feeds/luci/applications/luci-app-dae
rm -rf feeds/luci/applications/luci-app-daed
rm -rf feeds/packages/net/dae
rm -rf feeds/packages/net/daed
rm -rf package/luci-theme-argon package/luci-app-argon-config package/small package/daed package/dae package/luci-app-nikki

# 2. 拉取 argon 主题
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config

# 3. 拉取 kenzok8/small
git clone --depth 1 https://github.com/kenzok8/small package/small

# 4. 彻底重写/抹除 dae 和 daed Makefile 中的 vmlinux-btf 强依赖
if [ -d package/small/dae ]; then
    sed -i 's/+vmlinux-btf//g' package/small/dae/Makefile
    sed -i 's/@KERNEL_DEBUG_INFO_BTF//g' package/small/dae/Makefile
    sed -i 's/vmlinux-btf//g' package/small/dae/Makefile
fi

if [ -d package/small/daed ]; then
    sed -i 's/+vmlinux-btf//g' package/small/daed/Makefile
    sed -i 's/@KERNEL_DEBUG_INFO_BTF//g' package/small/daed/Makefile
    sed -i 's/vmlinux-btf//g' package/small/daed/Makefile
fi

if [ -d package/small/luci-app-daed ]; then
    sed -i 's/+vmlinux-btf//g' package/small/luci-app-daed/Makefile
fi

# 5. 禁用 Rust 编译
rm -rf feeds/packages/lang/rust

# 6. 设置后台 IP 为 192.168.1.1 与主机名
[ -f package/base-files/files/bin/config_generate ] && sed -i 's/192.168.[0-9]*.1/192.168.1.1/g' package/base-files/files/bin/config_generate
[ -f package/base-files/files/bin/config_generate ] && sed -i "s/hostname='.*'/hostname='Redmi-AX6'/g" package/base-files/files/bin/config_generate

# 7. 设置默认 root 密码为空
[ -f package/base-files/files/etc/shadow ] && sed -i 's/root:::0:99999:7:::/root::0:99999:7:::/g' package/base-files/files/etc/shadow

# 8. 设置默认 WiFi (2.4G: redmi-ax6-2.4g, 5G: redmiax6-5g, 密码: 123456789)
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
