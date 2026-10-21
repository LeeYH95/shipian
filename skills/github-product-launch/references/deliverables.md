# 清单与格式

输出目录由用户提供或在项目内新建，不覆盖已有发布包。建议包含 README、docs/media、docs/launch 和可重新制作的媒体源工程；运行日志、临时渲染帧与评估输出放到发布目录外。

`launch-manifest.json` 是产品事实和素材的索引，示例：

```json
{
  "product": {"name": "产品名", "summary": "一句话价值", "repository": "https://github.com/owner/repository"},
  "claims": [{"text": "支持本地导出", "evidence": ["src/export.py"]}],
  "assets": [{"path": "docs/media/banner.png", "role": "banner", "origin": "composition", "source": "marketing/source/index.html", "rights": "project-owned", "width": 1600, "height": 900}],
  "readmes": ["README.md"],
  "max_asset_bytes": 25000000
}
```

所有文件路径均相对发布目录，不能包含路径穿越或指向目录外的符号链接。`source` 可为目录内文件、已核实的外部 HTTPS 来源，或可定位的生成任务记录；`rights` 表示授权依据，不能写“未知”或“待确认”后继续发布。

`claims` 的证据应有足够语义关联。检查器只验证文件存在，Agent 仍要读内容判断是否支持承诺。不要用一个无关文件为所有承诺背书。

Banner 一般为宽画幅，社交预览按目标平台要求；尺寸由任务选择并写入清单。机器检查 PNG 的尺寸、素材大小、路径及 README 本地链接，不把这些检查等同于视觉质量或许可审查。

README 安装命令必须和实际产物相符；测试版、未公证、平台未测等限制放在下载入口附近。相对路径链接发布后仍需在目标平台检查。
