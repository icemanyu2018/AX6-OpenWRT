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

# 1. 从 kenzok8/small 源中按需拉取所需插件
git_sparse_clone main https://github.com/kenzok8/small luci-app-openclash
git_sparse_clone main https://github.com/kenzok8/small luci-app-daed daed dae
git_sparse_clone main https://github.com/kenzok8/small luci-app-adguardhome
git_sparse_clone main https://github.com/kenzok8/small luci-theme-argon luci-app-argon-config
git_sparse_clone main https://github.com/kenzok8/small luci-app-wolultra 2>/dev/null || true

# 2. 清理官方 feed 中可能冲突的同名旧插件
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/applications/luci-app-openclash

# 3. 设置后台管理 IP 为 192.168.1.1 与主机名
sed -i 's/192.168.[0-9]*.1/192.168.1.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='.*'/hostname='Redmi-AX6'/g" package/base-files/files/bin/config_generate

# 4. 设置默认 root 密码为空
sed -i 's/root:::0:99999:7:::/root::0:99999:7:::/g' package/base-files/files/etc/shadow 2>/dev/null || true

# 5. 设置默认 WiFi (2.4G: redmi-ax6-2.4g, 5G: redmiax6-5g, 密码: 123456789)
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-wifi << 'EOF'
#!/bin/sh

# 开启物理无线
uci -q batch << 'UCIBATCH'
set wireless.@wifi-device[0].disabled='0'
set wireless.@wifi-device[1].disabled='0'
UCIBATCH

# 遍历所有无线接口精准配置 SSID 与密码
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
