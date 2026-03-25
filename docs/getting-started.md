# Getting Started

本文档面向第一次接触 SVNMate 的用户或开发者，说明如何准备环境、构建应用并完成首次使用。

## 1. 环境要求

### 1.1 运行环境

- macOS 13.0 及以上
- Apple Silicon 或 Intel Mac
- 已安装 `svn`

### 1.2 开发环境

- Xcode 15 或兼容版本
- Swift 5.9 及以上工具链
- 建议安装 `xcodegen`

## 2. 安装依赖

### 2.1 安装 Xcode Command Line Tools

```bash
xcode-select --install
```

### 2.2 安装 SVN

系统自带或 Homebrew 安装均可。

```bash
brew install svn
```

常见路径包括：

- `/usr/bin/svn`
- `/opt/homebrew/bin/svn`
- `/usr/local/bin/svn`

### 2.3 安装 XcodeGen

```bash
brew install xcodegen
```

## 3. 获取源码

```bash
git clone <your-repository-url> svn-mac-client
cd svn-mac-client
```

## 4. 构建应用

### 4.1 快速编译校验

```bash
swift build --scratch-path /tmp/svnmate-swiftpm
```

这条链路适合快速验证源码是否可以编译通过，但不负责生成最终 `.app` 包。

### 4.2 生成 Xcode 工程

```bash
xcodegen generate
open SVNMate.xcodeproj
```

### 4.3 生成可运行应用和内部测试 DMG

```bash
./scripts/package_dmg.sh
```

产物位于：

- `dist/SVNMate.app`
- `dist/SVNMate-macOS.dmg`

## 5. 首次启动

首次打开应用后，界面分为两部分：

- 左侧：仓库列表
- 右侧：欢迎页或当前仓库详情

如果系统或 Gatekeeper 对未签名内部测试包进行拦截，可在 Finder 中右键应用选择“打开”，或在“系统设置 > 隐私与安全性”中放行。

## 6. 第一次使用建议路径

推荐按以下顺序体验：

1. 通过 `Open Repository...` 打开一个已有 SVN 工作副本
2. 检查文件树是否正常加载
3. 选中一个已修改文件，查看 diff
4. 选中一个未纳管文件，执行 `Add to SVN`
5. 批量选择可提交项并执行 `Commit Selected`
6. 再执行一次 `Update`

如果没有现成工作副本，也可以直接使用 `New Checkout...` 从远程仓库地址检出。

## 7. 语言与设置

SVNMate 支持 `zh-Hans` 和 `en` 两种语言：

- 默认跟随系统语言
- 若系统语言不是 `zh/en`，回退到简体中文
- 可在 Settings 中手动覆盖语言

设置页还支持：

- 配置 `svn` 可执行文件路径
- 配置超时时间
- 配置强调色和状态颜色

## 8. 下一步阅读

- 日常操作请看 [User Guide](user-guide.md)
- 构建与打包请看 [Installation and Packaging](installation-and-packaging.md)
- 设计实现请看 [Architecture](architecture.md)
