#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Keep the established test bundle ID so existing test notes remain available.
LINENOTES_APP_NAME="拾片" LINENOTES_BUNDLE_ID="local.linenotes.test" \
LINENOTES_VERSION="0.5.0" LINENOTES_BUILD="6" LINENOTES_BRAND_ICONS=1 scripts/build-dev-app.sh release
notes_output="build/shipian-test-release"
mkdir -p "$notes_output"
ditto 'build/拾片.app' "$notes_output/拾片.app"
cat > "$notes_output/请先阅读.txt" <<'TEXT'
拾片 0.5.0 (6) · 本机测试版 · Apple Silicon · macOS 14+

双击 拾片.app 即可使用，也可拖到“应用程序”。
使用原 LineNotes Test 的独立测试身份，已有测试笔记会继续显示。
笔记及附件仍保存在 ~/Library/Application Support/LineNotes Test。
不要同时运行旧 LineNotes Test 和拾片；退出旧测试版后再打开拾片。
原版 Tendedero 和 LineNotes Dev 不会被覆盖。

图标已替换为确认的「拾片」白天版。夜间资源同时内置，应用运行时图标
和偏好设置中的品牌图标随应用的浅色/深色/跟随系统设置切换。
Finder 和未运行时的静态图标使用白天版，不宣称系统范围自动切换。
关闭窗口不会退出菜单栏应用，再次双击应用可重开便笺库。
截图监听与开机启动默认不开启；本次打包不会修改已有用户偏好。

本机 ad hoc 签名，未进行 Apple 公证。已在当前 Mac 测试，不等同于
可在其他 Mac 无提示分发的正式发行版。
TEXT
codesign --verify --deep --strict "$notes_output/拾片.app"
ditto -c -k --sequesterRsrc --keepParent "$notes_output/拾片.app" "$notes_output/Shipian-0.5.0-arm64.zip"
notes_stage="$(mktemp -d "$PWD/build/shipian-dmg-stage.XXXXXX")"
trap 'rm -rf "$notes_stage"' EXIT
ditto "$notes_output/拾片.app" "$notes_stage/拾片.app"
cp "$notes_output/请先阅读.txt" "$notes_stage/请先阅读.txt"
ln -s /Applications "$notes_stage/Applications"
hdiutil create -quiet -srcfolder "$notes_stage" -volname '拾片 测试版' -format UDZO -ov "$notes_output/Shipian-0.5.0-arm64.dmg"
(cd "$notes_output" && shasum -a 256 Shipian-0.5.0-arm64.zip Shipian-0.5.0-arm64.dmg) > "$notes_output/SHA256SUMS.txt"
echo "Built $notes_output"
