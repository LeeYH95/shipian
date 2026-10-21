# GitHub 产品发布包

从一个已经能运行的软件项目，得到一套可核对、可发布的产品介绍：README、首屏 Banner、功能图、介绍视频、发布文案与检查报告。重点是让截图、产品承诺和源码对应，避免上传个人数据、遗漏上游署名，或交付无法播放的“视频”。

## 安装与使用

把仓库交给你的 Agent：

> 请安装 https://github.com/LeeYH95/shipian 中的 github-product-launch Skill。

也可手动将本目录复制到宿主支持的 Skill 目录。支持通用 Agent Skill 目录结构的安装器可使用：

```sh
npx skills add LeeYH95/shipian --skill github-product-launch
```

安装器需要 Node.js；Skill 的检查脚本本身只需要 Python 3.10+。无需额外配置，不保存账号或密钥。执行远程发布时复用当前环境安全的 GitHub 登录。

自然语言调用：

> 用 github-product-launch 给当前项目准备一套 GitHub 发布材料，包括 Banner、功能图和介绍视频。先检查实际能力，按我指定的仓库发布。

## 输出与边界

产出源码与宣传材料的清单、可展示的图片、可播放的视频、说明文档及发布校验。视频需要宿主提供渲染能力，只有文字/文件能力时可完成文案与分镜，并明确视频尚未生成。不会因为安装 Skill 就自动上传项目。

检查脚本使用 Python 标准库；已在 macOS 测试，Windows/Linux 未实测。实际界面采集需要可用浏览器或原生 GUI；图像生成、视频制作和 GitHub 上传取决于宿主工具、网络与授权，可能产生相应服务费用。单纯本地检查可离线运行，不发送文件到外部。

发布时将用户授权的源码与材料发送给指定 GitHub 仓库；不采集真实用户笔记、截图或凭据。机器检查只覆盖已实现规则，不能保证完整保密性、许可合规或审美质量，也不宣称已验证所有宿主。

## 校验

```sh
python3 -m unittest discover -s tests
python3 scripts/check_launch.py --root <发布目录> --manifest launch-manifest.json
```

Windows 可将 `python3` 换成 `py -3`。图像与视频制作的视觉选择由人审，程序校验负责路径、尺寸、素材清单、常见泄露规则及链接。
