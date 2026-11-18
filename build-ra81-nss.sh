#!/usr/bin/env bash
# ==============================================================================
# 红米 AX3000 (RA81, IPQ5018) 满血 NSS 固件 —— 一键编译脚本
#
# 目标: 保留原厂【小分区 / 双系统槽】布局，编译带 NSS 硬件加速的 OpenWrt
#       (内核 6.18 / apk 包管理 / WiFi offload)
#
# 关键选择:
#   - 仓库   : https://github.com/Cathgao/openwrt-nss-edma  分支 custom
#   - NSS feed: kuncy7/nss-packages 分支 ipq50xx-rebase (feeds.conf.default 已含)
#   - Profile: xiaomi_cr8806  <-- 覆盖 Redmi AX3000 原厂双分区 (ALT2)
#              绝对不要选 xiaomi_redmi-ax3000-ubootmod，那是【大分区/single rootfs】
#   - 内存档 : ATH11K 256M + NSS LOW (RA81 只有 256MB RAM)
#
# 环境: Ubuntu 20.04+ / Debian 11+ / WSL2, 至少 8GB RAM(推荐16G) + 60GB 可用磁盘
# 用法: bash build-ra81-nss.sh [输出目录]
# ==============================================================================
set -euo pipefail

REPO_URL="https://github.com/Cathgao/openwrt-nss-edma.git"
BRANCH="custom"
WORKDIR="${1:-$HOME/openwrt-nss-ra81}"
JOBS="$(nproc)"

log() { echo -e "\n\033[1;32m>>> $*\033[0m"; }
warn() { echo -e "\n\033[1;33m!!! $*\033[0m"; }

log "0/6 环境自检"
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
echo "工作目录: $WORKDIR | 并行线程: $JOBS | RAM: $(free -h | awk '/Mem:/{print $2}')"
MEM_GB=$(free -g | awk '/Mem:/{print $2}')
[ "$MEM_GB" -lt 8 ] && warn "内存不足 8GB，编译可能失败，建议加 swap 或减线程"

log "1/6 安装编译依赖"
$SUDO apt update
$SUDO apt install -y build-essential clang flex bison g++ gawk gcc-multilib \
  g++-multilib gettext git libncurses-dev libssl-dev python3-setuptools \
  rsync unzip zlib1g-dev file wget libelf-dev
# Ubuntu 24.04 起 python3-distutils 被移除，存在才装
apt-cache policy python3-distutils 2>/dev/null | grep -q 'Candidate: [0-9]' && \
  $SUDO apt install -y python3-distutils || true

log "2/6 克隆源码 (分支: $BRANCH)"
if [ ! -d "$WORKDIR/.git" ]; then
  git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$WORKDIR"
else
  echo "目录已存在，跳过 clone (如需全新编译请先手动删除该目录)"
fi
cd "$WORKDIR"

log "3/6 更新 feeds (含 NSS feed: kuncy7/nss-packages@ipq50xx-rebase)"
./scripts/feeds update -a
./scripts/feeds install -a
if ! ./scripts/feeds list -r nss 2>/dev/null | grep -q qca-nss-drv; then
  warn "NSS feed 未就位！请检查 feeds.conf.default 中是否包含 kuncy7/nss-packages 的 ipq50xx-rebase 分支"
  exit 1
fi
echo "NSS feed OK"

log "4/6 生成 .config (单设备 xiaomi_cr8806 + 256M 内存档 + NSS 全栈)"
cat > .config <<'EOF'
# ---- 目标: qualcommax/ipq50xx，单设备: Xiaomi CR8806 (覆盖 Redmi AX3000 原厂双分区) ----
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq50xx=y
CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_xiaomi_cr8806=y

# ---- NSS 运行时 + DSA 数据面 (nss-tools-dwmac 会把整条 NSS 栈拉进来) ----
CONFIG_PACKAGE_nss-tools-dwmac=y
CONFIG_PACKAGE_nss-firmware=y
CONFIG_NSS_FIRMWARE_VERSION_12_5=y
CONFIG_NSS_MEM_PROFILE_LOW=y
CONFIG_NSS_DRV_VLAN_ENABLE=y
CONFIG_NSS_DRV_IPV6_ENABLE=y
CONFIG_NSS_DRV_VIRT_IF_ENABLE=y
CONFIG_PACKAGE_kmod-qca-nss-drv-pppoe=y
CONFIG_PACKAGE_kmod-qca-nss-drv-netlink=y
CONFIG_PACKAGE_nssinfo=y
CONFIG_PACKAGE_libnl-nss=y

# ---- ath11k WiFi offload (关键: 必须是 qcn6122 固件，否则 2.4G 起不来) ----
CONFIG_PACKAGE_MAC80211_NSS_SUPPORT=y
CONFIG_ATH11K_NSS_SUPPORT=y
CONFIG_ATH11K_MEM_PROFILE_256M=y
CONFIG_NSS_DRV_WIFIOFFLOAD_ENABLE=y
CONFIG_NSS_DRV_WIFI_EXT_VDEV_ENABLE=y
CONFIG_PACKAGE_ath11k-firmware-ipq5018-qcn6122=y
CONFIG_PACKAGE_ipq-wifi-xiaomi_cr8806=y

# ---- NSS SQM / QoS ----
CONFIG_NSS_DRV_SHAPER_ENABLE=y
CONFIG_NSS_DRV_IGS_ENABLE=y
CONFIG_PACKAGE_kmod-qca-nss-drv-qdisc=y
CONFIG_PACKAGE_kmod-qca-nss-drv-igs=y
CONFIG_PACKAGE_sqm-scripts=y
CONFIG_PACKAGE_sqm-scripts-nss=y
CONFIG_PACKAGE_tc-full=y

# ---- 排障工具 ----
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_iperf3=y
CONFIG_CCACHE=y
EOF
make defconfig
echo "已生成 .config。如需加装自定义插件，请现在运行: make menuconfig"
echo "（提示: 256MB RAM + 36MB 系统槽，插件务必精简，nss-tools-dwmac 保持 <*> 内置）"

log "5/6 下载源码包"
make -j"$JOBS" download

log "6/6 开始编译 (首次较慢，30~90 分钟取决于机器)"
make -j"$JOBS"

log "完成！固件产物:"
ls -lh bin/targets/qualcommax/ipq50xx/ | grep -E 'xiaomi_cr8806|sha256' || true
echo ""
echo "主固件: bin/targets/qualcommax/ipq50xx/openwrt-qualcommax-ipq50xx-xiaomi_cr8806-squashfs-sysupgrade.bin"
warn "刷机前请看随附方案文档：先用经典固件打底并备份原厂，再 sysupgrade 本固件；确认 profile 不是 ubootmod(大分区)"
