# 拾片 0.5.0 (6)

把截图与灵感，挂在眼前。

这一版在 Tendedero 的截图挂绳基础上加入可编辑的文字、待办、图片和附件便笺，并提供本地自动保存、便笺库、搜索与排序、取下/恢复、Markdown 及附件导出。便笺沿用原有夹子、边框与摆动机制。

界面采用拾片独立品牌，支持浅色、深色、跟随系统与六种纸色，底部轻量工具和自定义菜单。日夜图标已内置；Finder 静态图标使用浅色版。

## 安装

- `Shipian-0.5.0-arm64.dmg`：打开后把拾片拖到应用程序。
- `Shipian-0.5.0-arm64.zip`：解压后打开拾片.app。
- `SHA256SUMS.txt`：下载文件的 SHA-256 校验和。
- `shipian-intro.mp4`：产品介绍视频。

**要求 Apple Silicon、macOS 14 或更新系统。采用本地 ad hoc 签名，尚未通过 Apple 公证，下载后可能需要在系统设置中手动确认打开。**

## 数据与已知限制

沿用已有应用身份 `local.linenotes.test`，数据位于 `~/Library/Application Support/LineNotes Test`；请勿同时运行旧版 LineNotes Test 和拾片。原版 Tendedero 不会被覆盖。

当前没有账号、云同步、多端协作或 AI 功能；请自行备份本地数据。Intel 版本和跨设备长期压力验收尚未完成。

源码与品牌来源详见仓库 NOTICE。欢迎通过 Issues 反馈可复现的问题。
