# Redmi AX3000 (RA81) 满血 NSS OpenWrt 编译环境

为红米 AX3000（硬件代号 RA81，高通 IPQ5018，256MB RAM / 128MB NAND）编译带
**NSS 硬件加速**的 OpenWrt 固件，并**保留原厂双分区（小分区）布局**。

## 为什么是这个方案

- **满血 WiFi 加速**：基于 `Cathgao/openwrt-nss-edma`（分支 `custom`），内核 6.18，
  NSS offload 让 NAT/PPPoE/VLAN/WiFi 走硬件，满速千兆 WiFi 时 CPU 占用极低。
- **保留小分区**：profile 选 `xiaomi_cr8806`（原厂双分区，Redmi AX3000 是其 ALT2），
  固件只写空闲槽，原厂系统留在另一槽，刷错可一键切回。
  **绝对不要**选 `xiaomi_redmi-ax3000-ubootmod`——那是大分区（single rootfs），
  需专用 U-Boot，与小分区固件混用会无法启动。

## 目录

- `.github/workflows/ra81-nss-build.yml` — GitHub Actions 云编译 workflow（手动触发）
- `RA81-刷机方案与避坑.md` — 备份、判槽、刷空闲槽、验证、切回原厂、常见坑速查
- `build-ra81-nss.sh` — 本地 Linux 一键编译脚本（备用，WSL/云主机可用）

## 使用方法

1. 打开 `Actions` 标签页，选中 `Build Redmi AX3000 RA81 NSS`。
2. 点 `Run workflow` 手动触发（不会因 push 自动编译，避免浪费额度）。
3. 编译约 30~90 分钟，完成后在 run 页面底部 `Artifacts` 下载固件包。
4. 按 `RA81-刷机方案与避坑.md` 操作：先备份原厂分区，判定当前启动槽，
   把固件写进另一槽，`nvram` 切换启动，重启。

## 编译配置要点

- Target：`qualcommax / ipq50xx`，Device：`xiaomi_cr8806`
- 内存档：`ATH11K_MEM_PROFILE_256M` + `NSS_MEM_PROFILE_LOW`（RA81 只有 256MB RAM）
- `nss-tools-dwmac` 必须 `<*>` 内置；WiFi 固件必须 `ipq5018-qcn6122`
- 160MHz WiFi 需国家码 `CN` + 国内合规信道（workflow 已预置 country=CN、channel=36、HE160）

## 风险提示

刷机有变砖风险，可能失去保修，操作风险自负。机器只有 256MB RAM，
这套固件定位是**优秀的 AP**，不适合当主路由跑大量插件。

## 参考

- NSS 源码：https://github.com/Cathgao/openwrt-nss-edma （分支 custom）
- NSS 上游：https://github.com/kuncy7/openwrt-nss-edma
- 恩山原帖：https://www.right.com.cn/forum/thread-8496060-1-1.html
