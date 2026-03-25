# Installation and Packaging

本文档面向开发者、测试人员和构建发布人员，说明如何从源码构建 SVNMate，以及如何生成内部测试 DMG。

## 1. 环境要求

### 1.1 运行要求

- macOS 13.0+
- 本机可用的 `svn` 命令行

### 1.2 构建要求

- Xcode 15 或兼容版本
- Swift 5.9+
- 建议安装 `xcodegen`

## 2. 安装依赖

```bash
xcode-select --install
brew install svn xcodegen
```

如果只想快速编译校验，`xcodegen` 不是强制依赖；如果要生成 `.app` 或 `.dmg`，建议安装。

## 3. SwiftPM 构建

用于快速检查当前源码是否能通过编译：

```bash
swift build --scratch-path /tmp/svnmate-swiftpm
```

说明：

- 这条链路适合开发时快速验编译
- 不负责产出正式 `.app`
- 资源与打包交付仍推荐走 XcodeGen / Xcode 链路

## 4. 生成 Xcode 工程

```bash
xcodegen generate
open SVNMate.xcodeproj
```

`project.yml` 是工程配置源，`SVNMate.xcodeproj` 是生成产物。对资源、图标和本地化目录的修改，应以 `project.yml` 为准。

## 5. Xcode 本机构建

在 Xcode 中：

1. 打开 `SVNMate.xcodeproj`
2. 选择 `SVNMate` scheme
3. 选择本机作为目标
4. 执行 Build / Run

建议在本机构建后验证：

- 应用可以正常启动
- 可打开工作副本
- 设置页可正常显示
- 主界面语言与系统/手动设置一致

## 6. 命令行生成内部测试 DMG

仓库已经内置一键打包脚本：

```bash
./scripts/package_dmg.sh
```

脚本会自动执行：

1. 根据 `project.yml` 运行 `xcodegen generate`
2. 使用 `xcodebuild` 执行 `Release` 构建
3. 提取 `SVNMate.app`
4. 打包为包含 `Applications` 快捷方式的 DMG

产物位于：

- `dist/SVNMate.app`
- `dist/SVNMate-macOS.dmg`

## 7. 当前打包链路的定位

当前打包链路面向：

- 本地开发验证
- 内部测试分发
- 功能演示和临时交付

当前打包链路不包含：

- Developer ID 正式签名
- notarization
- stapling
- 自定义 DMG 卷宗图标或安装引导

## 8. Gatekeeper 与安装行为

由于当前 DMG 属于内部测试分发，测试机上可能遇到 Gatekeeper 拦截。常见处理方式：

- 将应用拖入 `Applications`
- 首次通过 Finder 右键 `Open`
- 或在“系统设置 > 隐私与安全性”中手动放行

这类行为不代表构建失败，而是未做正式发布签名的正常表现。

## 9. 资源与本地化打包

当前 `.app` 打包中已经包含：

- `Assets.car`
- `AppIcon.icns`
- `en.lproj/Localizable.strings`
- `zh-Hans.lproj/Localizable.strings`

因此：

- 图标会进入最终 `.app`
- 本地化资源会进入最终 `.app`
- 运行时语言切换可以基于打包资源生效

## 10. 正式发布前还需要补的内容

如果项目后续要从“内部测试包”走向“正式外部发布”，建议至少补齐：

1. Developer ID Application 签名
2. Hardened Runtime 配置
3. `notarytool` 公证
4. stapling
5. 分发策略和版本发布说明

## 11. 故障排查

### 11.1 `swift build` 失败

检查：

- `xcode-select -p`
- Xcode / Swift 工具链是否可用
- 是否使用了 `--scratch-path /tmp/svnmate-swiftpm`

### 11.2 无法找到 `svn`

检查：

- `svn --version`
- `Settings` 中是否配置了错误的 `svn` 路径
- `SVN_BINARY_PATH` 是否覆盖到了错误路径

### 11.3 `package_dmg.sh` 失败

检查：

- 是否已安装 `xcodebuild`、`hdiutil`、`xcodegen`
- `project.yml` 是否有效
- 当前目录是否对 `build/`、`dist/` 可写

### 11.4 图标或本地化未更新

当前打包脚本会在每次打包前重生成 Xcode 工程。如果界面仍显示旧结果，优先排查：

- macOS 的 Finder / Dock 图标缓存
- 旧 `.app` 是否仍在 `Applications`
- 是否确实使用了新生成的 `dist/SVNMate.app`
