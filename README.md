# SVNMate

SVNMate 是一个面向 macOS 的原生 SVN 客户端，基于 SwiftUI + AppKit 构建，通过调用本地 `svn` 二进制完成工作副本管理。

## 当前能力

- 打开本地 SVN 工作副本
- 从远程仓库地址执行 checkout
- 以文件树方式查看工作副本状态
- 查看文件 diff
- 按选中文件提交
- 执行 update / cleanup / resolve

## 系统要求

- macOS 13.0+
- 本机已安装 `svn`
- 开发构建建议安装 Xcode 15+ 或兼容 Swift 5.9 工具链

## 快速开始

```bash
# 安装命令行工具
xcode-select --install

# 可选：使用 Homebrew 安装 svn
brew install svn

# 进入项目
cd svn-mac-client

# 构建
swift build --scratch-path /tmp/svnmate-swiftpm

# 运行
open .build/debug/SVNMate
```

## 文档导航

- [设计文档](docs/design/design-document.md)
- [使用手册](docs/manuals/user-manual.md)
- [安装部署手册](docs/manuals/install-deploy-manual.md)
- [早期规格说明](SPEC.md)

## 代码结构

```text
SVNMate/Sources/
├── App/         # 应用入口与全局状态
├── Models/      # 仓库、文件节点、错误模型
├── Services/    # svn 二进制解析、命令执行、XML 解析、仓库存储
└── Views/       # 主界面、详情页、检出与提交交互
```

## 说明

- 当前版本仍以工作副本核心操作为主，不包含 branch/tag、图形化历史浏览和完整认证设置页
- `svn` 可执行文件会按 `/usr/bin/svn`、`/opt/homebrew/bin/svn`、`/usr/local/bin/svn` 等路径自动发现
- 若默认路径不满足需求，可通过环境变量 `SVN_BINARY_PATH` 覆盖
