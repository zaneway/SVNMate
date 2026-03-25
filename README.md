# SVNMate

> Native macOS SVN client built with SwiftUI and AppKit.

SVNMate 是一个面向 macOS 的开源 SVN 客户端，聚焦工作副本日常操作闭环，而不是追求覆盖 SVN 的全部服务器端管理能力。它通过调用本地 `svn` 二进制，与现有企业 SVN 基础设施兼容，并提供更适合桌面环境的交互体验。

## Highlights

- 原生 macOS 桌面应用，基于 `SwiftUI + AppKit`
- 支持打开已有工作副本和从远程仓库地址执行 checkout
- 以“真实磁盘目录树 + SVN 状态 overlay”方式浏览工作副本
- 支持批量 `Add to SVN`、选择性 `Commit Selected`
- 支持 `Update`、`Cleanup`、`Resolve`
- 支持查看 diff、树冲突详情和 SVN issue 汇总
- 内置设置页，可配置 `svn` 路径、超时、颜色和语言
- 支持菜单栏入口、应用图标和内部测试 DMG 打包
- 支持 `zh-Hans` / `en` 本地化，默认跟随系统语言，未支持语言回退到简体中文

## Current Scope

当前版本适合以下场景：

- 本地 SVN 工作副本浏览与状态检查
- 文档或代码类项目的日常更新、差异查看、批量添加和提交
- 冲突与异常工作副本的基础诊断
- macOS 内部测试环境下的桌面分发

当前版本不聚焦以下能力：

- branch / tag / merge assistant
- 图形化历史浏览
- 凭据管理 UI / Keychain 集成
- 正式签名、公证和 Mac App Store 交付链路

详细边界见 [docs/limitations.md](docs/limitations.md)。

## Quick Start

### Requirements

- macOS 13.0+
- 本机已安装 `svn`
- Xcode 15+ 或兼容工具链
- 建议安装 `xcodegen`

### Build From Source

```bash
xcode-select --install
brew install svn xcodegen

git clone <your-repository-url> svn-mac-client
cd svn-mac-client

# 快速编译校验
swift build --scratch-path /tmp/svnmate-swiftpm

# 生成可运行的 .app 和 .dmg
./scripts/package_dmg.sh

# 启动应用
open dist/SVNMate.app
```

### Open In Xcode

```bash
xcodegen generate
open SVNMate.xcodeproj
```

## Documentation

- [Getting Started](docs/getting-started.md)
- [User Guide](docs/user-guide.md)
- [Installation and Packaging](docs/installation-and-packaging.md)
- [Architecture](docs/architecture.md)
- [Limitations](docs/limitations.md)

## Repository Layout

```text
SVNMate/Sources/
├── App/         # 应用入口、设置、本地化、菜单栏和全局状态
├── Models/      # 仓库、文件节点、状态、错误模型
├── Services/    # svn 路径解析、命令执行、XML 解析、仓库存储、磁盘扫描
└── Views/       # 主界面、仓库详情、检出、设置和菜单栏视图
```

## Project Status

SVNMate 当前已经具备可用的工作副本操作主链路，但仍处于持续迭代阶段。仓库中保留了完整的设计规格记录和打包脚本，适合继续向“可维护的 macOS SVN 客户端”方向演进。

如果你要评估是否适合接入自己的环境，建议优先阅读：

1. [Getting Started](docs/getting-started.md)
2. [User Guide](docs/user-guide.md)
3. [Limitations](docs/limitations.md)

## License

本仓库采用 [GNU General Public License v3.0](LICENSE) 发布。

- SPDX: `GPL-3.0-only`
- 你可以在 GPL-3.0 条款下使用、修改和分发本项目
- 如果你分发修改版或衍生作品，需要继续遵守 GPL-3.0 的 copyleft 要求
