#!/bin/bash
# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# 1. 添加第三方插件与主题源码
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config

# 添加 daed / dae 源码
git clone --depth 1 https://github.com/sbwml/luci-app-daed package/daed

# 2. 清理官方 feed 中可能冲突的主题包
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config

# 3. 设置默认管理 IP: 192.168.1.1
sed -i 's/192.168.[0-9]*.1/192.168.1.1/g' package/base-files/files/bin/config_generate

# 4. 设置默认密码为空 (清除 root 默认 hash)
sed -i 's/root:::0:99999:7:::/root::0:99999:7:::/g' package/base-files/files/etc/shadow 2>/dev/null || true

# 5. 设置默认 WiFi (2.4G: redmi-ax6-2.4g, 5G: redmiax6-5g, 密码: 123456789)
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-wifi << 'EOF'
#!/bin/sh

# 开启无线并设置 SSID 与密码
uci -q batch << 'UCIBATCH'
set wireless.@wifi-device[0].disabled='0'
set wireless.@wifi-device[1].disabled='0'
UCIBATCH

# 针对具体频段精准设置
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
