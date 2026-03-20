# SVNMate 安装部署手册

## 1. 目标读者

本手册面向以下角色：

- 开发人员
- 测试人员
- 构建发布人员
- 内部 IT / 桌面运维人员

## 2. 系统要求

### 2.1 运行环境

- macOS 13.0 及以上
- Apple Silicon 或 Intel Mac
- 已安装 SVN 命令行

### 2.2 开发环境

- Xcode 15 或兼容版本
- Swift 5.9 及以上工具链
- 可选：XcodeGen

## 3. 依赖安装

### 3.1 安装 Xcode Command Line Tools

```bash
xcode-select --install
```

### 3.2 安装 SVN

可选两种方式。

#### 方式 A：使用系统自带 SVN

通常安装 Xcode Command Line Tools 后即可获得 `/usr/bin/svn`。

#### 方式 B：使用 Homebrew 安装

```bash
brew install svn
```

常见安装路径：

- `/opt/homebrew/bin/svn`
- `/usr/local/bin/svn`

### 3.3 可选：安装 XcodeGen

如果需要根据 `project.yml` 生成 Xcode 工程，可安装：

```bash
brew install xcodegen
```

## 4. 获取源码

```bash
cd /path/to/workspace
git clone <your-repository-url> svn-mac-client
cd svn-mac-client
```

如果你的源码并非通过 Git 获取，只需保证目录中包含：

- `Package.swift`
- `project.yml`
- `SVNMate/Sources/`

## 5. 本地开发构建

### 5.1 通过 SwiftPM 构建

适用于快速验证编译是否通过。

```bash
swift build
```

如果本地环境存在 SwiftPM 缓存权限问题，可改用：

```bash
swift build --scratch-path /tmp/svnmate-swiftpm
```

### 5.2 运行构建产物

```bash
open .build/debug/SVNMate
```

注意：

- SwiftPM 构建适合开发调试
- 真正的发布交付建议走 Xcode 工程与 Archive 流程

## 6. 通过 XcodeGen 生成工程

### 6.1 生成 Xcode 工程

```bash
xcodegen generate
```

生成完成后，通常会得到：

```text
SVNMate.xcodeproj
```

### 6.2 使用 Xcode 打开

```bash
open SVNMate.xcodeproj
```

## 7. Xcode 构建与本机安装

### 7.1 Debug 构建

在 Xcode 中：

1. 选择 `SVNMate` scheme
2. 选择本机作为运行目标
3. 执行 Build / Run

### 7.2 本机安装验证项

首次运行前建议验证：

- 应用可以正常启动
- 可以打开已有 SVN 工作副本
- 可以执行 `Update`
- 可以执行 `Commit`
- 可以正常显示 diff

## 8. 命令行构建发布包

### 8.1 Archive

```bash
xcodebuild \
  -project SVNMate.xcodeproj \
  -scheme SVNMate \
  -configuration Release \
  archive \
  -archivePath build/SVNMate.xcarchive
```

### 8.2 导出 `.app`

如需通过命令行导出，可使用 `xcodebuild -exportArchive`。示例：

```bash
xcodebuild \
  -exportArchive \
  -archivePath build/SVNMate.xcarchive \
  -exportOptionsPlist /path/to/ExportOptions.plist \
  -exportPath build/export
```

如果是内部测试分发，也可以直接在 Xcode Organizer 中手动导出。

## 9. 签名与发布建议

当前工程配置适合开发阶段。若用于正式交付，建议增加以下流程：

- 配置正式 `Development Team`
- 配置 `Code Signing`
- 开启 Hardened Runtime
- 进行 notarization
- 对外发布前做 Gatekeeper 验证

### 9.1 当前权限模型

项目配置中已关闭 App Sandbox，并允许用户选择的文件读写。

这意味着：

- 开发和内部交付阶段更容易访问本地工作副本
- 如果未来进入 Mac App Store 路径，需要重新评估权限模型

## 10. SVN 二进制发现策略

应用按以下顺序查找 `svn`：

1. 环境变量 `SVN_BINARY_PATH`
2. `UserDefaults` 中的 `SVNMate.svnBinaryPath`
3. 默认路径
   - `/usr/bin/svn`
   - `/opt/homebrew/bin/svn`
   - `/usr/local/bin/svn`

## 11. 运行前检查清单

部署或安装前建议执行以下检查：

- `svn --version` 正常
- 应用目标机器可访问 SVN 服务器
- 目标用户对本地工作目录有读写权限
- 若使用自签或企业证书，确认 SVN 命令行已具备对应访问能力

## 12. 测试环境部署建议

建议至少准备以下测试场景：

- 场景 A：系统自带 `/usr/bin/svn`
- 场景 B：Homebrew 安装 `/opt/homebrew/bin/svn`
- 场景 C：已有工作副本打开
- 场景 D：新 checkout
- 场景 E：包含冲突、missing、ignored 文件的复杂工作副本

## 13. 故障排查

### 13.1 `swift build` 失败

排查顺序：

1. 检查 Xcode / Swift 工具链是否可用
2. 执行 `xcode-select -p`
3. 尝试 `swift build --scratch-path /tmp/svnmate-swiftpm`

### 13.2 启动后无法识别 SVN

排查顺序：

1. 执行 `svn --version`
2. 检查 `svn` 是否位于支持的默认路径
3. 如有必要，使用环境变量指定路径：

```bash
SVN_BINARY_PATH=/opt/homebrew/bin/svn open .build/debug/SVNMate
```

### 13.3 打包后打开仓库失败

可能原因：

- 用户未授予目录访问权限
- 目标目录不是工作副本
- 打包环境与测试环境的 `svn` 路径不一致

### 13.4 认证相关失败

当前版本未内置完整的认证设置界面。若命令行 `svn` 本身已能访问仓库，而桌面端失败，建议优先从以下方向排查：

- 凭据缓存
- 证书信任链
- 代理配置
- 服务器访问控制

## 14. 推荐发布流程

对于团队内部交付，建议采用以下最小闭环：

1. 使用 XcodeGen 生成工程
2. 在 Xcode 中完成 Release Archive
3. 在测试机验证打开仓库、update、commit、diff
4. 完成签名与 notarization
5. 通过内部软件分发平台或 DMG 分发

## 15. 文档关联

- 设计文档：说明系统架构、模块职责和演进边界
- 使用手册：说明最终用户如何操作客户端
- 本手册：说明开发构建、安装和交付流程
