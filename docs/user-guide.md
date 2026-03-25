# User Guide

本文档面向日常使用 SVNMate 的研发、测试和技术支持人员，覆盖当前版本已实现的主要工作流。

## 1. 主界面结构

SVNMate 主界面采用典型的双栏结构：

- 左侧：仓库列表
- 右侧：欢迎页或当前仓库详情

仓库详情页又分为两部分：

- 左侧：文件树
- 右侧：详情区 / 批量操作区 / issue 区

## 2. 仓库管理

### 2.1 打开已有工作副本

操作路径：

1. 点击 `Open Repository...`
2. 选择本地 SVN 工作副本目录
3. 应用会执行 `svn info`
4. 校验通过后，仓库加入左侧列表并切换为当前选中项

### 2.2 删除仓库记录

在左侧仓库列表对目标仓库执行 `Remove`。

注意：

- 这只会移除应用中的记录
- 不会删除本地工作副本目录

## 3. 检出远程仓库

操作路径：

1. 点击 `New Checkout...`
2. 输入仓库 URL
3. 选择本地目录
4. 点击 `Checkout`

当前检出过程支持：

- 在弹窗中实时显示输出日志
- 展示当前正在处理的路径
- 统计已输出的文件项数量

检出成功后，应用会尝试自动将目标目录加入仓库列表。

## 4. 浏览工作副本

文件树不是简单的 `svn status` 列表，而是：

- 基于磁盘真实目录构建
- 隐藏 `.svn`
- 再叠加 SVN 状态 overlay

这意味着：

- 已提交且无变更的普通文件也会显示
- 未纳管文件会显示
- 缺失但仍被 SVN 跟踪的路径不会伪造进主树，而会进入 issue 区

### 4.1 文件树交互

- 单击文件或目录：选中并在右侧显示详情
- 双击目录：展开或收起，同时保持该目录选中
- 点击左侧箭头：展开或收起目录
- 勾选框：加入右侧批量操作面板

### 4.2 状态说明

| 状态 | 含义 |
|------|------|
| Normal | 正常、无待处理变更 |
| Modified | 文件已修改 |
| Added | 已纳入版本控制但未提交 |
| Deleted | 已删除 |
| Unversioned | 尚未纳入版本控制 |
| Conflict | 存在冲突 |
| Ignored | 被忽略 |
| Missing | SVN 记录仍在，但磁盘已缺失 |
| Replaced | 被替换 |
| External | 外部引用 |

### 4.3 勾选规则

当前文件树勾选是“按可操作性开放”，不是所有文件都允许勾选：

- `Normal`：可查看，不可勾选
- `Unversioned`：可勾选，用于 `Add to SVN`
- `Modified / Added / Deleted / Replaced`：可勾选，用于提交
- `Conflict / Missing / Ignored / External`：默认不进入批量操作流

## 5. 查看文件详情与差异

选中一个文件后，右侧会显示：

- 文件名和相对路径
- 当前状态
- 可执行操作
- 可选的 diff 结果

对可比较文件，可点击 `View Diff` 查看文本差异。

当前版本提供：

- 文本 diff 展示
- 等宽字体显示
- 适合代码或文本类文件

当前不提供：

- 图形化 diff
- 图像或 Office 文档的可视化差异对比

## 6. 批量 Add 和 Commit

### 6.1 Add 未纳管文件

操作路径：

1. 在文件树中勾选一个或多个 `Unversioned` 文件
2. 右侧进入批量操作面板
3. 点击 `Add to SVN`

当前行为：

- 使用 `svn add --non-interactive --force --parents`
- 自动补齐需要的父目录
- 完成后刷新状态树

### 6.2 提交已选变更

操作路径：

1. 勾选一个或多个可提交文件
2. 在右侧填写 `Commit Message`
3. 点击 `Commit Selected`

当前行为：

- 只提交所选路径
- 若存在 `.added` 祖先目录，会自动补齐必须一起提交的父目录
- 提交完成后刷新状态树

### 6.3 阻断提交的条件

以下情况会阻止提交：

- 提交说明为空
- 选中项本身不可提交
- 选中项或其祖先目录存在冲突

如果是树冲突导致的阻断，右侧会直接给出阻断路径和冲突详情。

## 7. Update、Cleanup 与 Resolve

### 7.1 Update

点击工具栏中的 `Update` 可执行：

- `svn update --non-interactive`

适用场景：

- 拉取服务器最新变更
- 检查本地与远端是否发生冲突

### 7.2 Cleanup

点击 `Cleanup` 可执行：

- `svn cleanup`

适用于：

- 工作副本锁定
- 异常中断后状态不一致

### 7.3 Resolve

对冲突文件或冲突目录，可执行：

- `svn resolve --accept working`

当前版本采用的是“保留 working copy 内容并标记为已解决”的策略，不提供多策略冲突解决 UI。

## 8. Tree Conflict 与 SVN Issues

### 8.1 Tree Conflict

当路径存在树冲突时，右侧会展示：

- 冲突摘要
- victim
- reason / action / operation
- source-left / source-right
- 仓库内路径与版本号

这有助于判断：

- 本地改动是什么
- 服务器传入变更是什么
- 冲突发生在 update / switch / merge 的哪个操作阶段

### 8.2 SVN Issues

某些问题不会直接体现在主树中，例如：

- 磁盘缺失但仍被 SVN 跟踪的路径
- 其他需要额外关注的 working copy 问题

这些内容会汇总在右侧 `SVN Issues` 区域。

## 9. Settings

Settings 支持以下配置：

- 语言
  - System Default
  - 简体中文
  - English
- `svn` 基础路径
- 默认/网络/checkout/log 超时
- 强调色
- 文件状态颜色

### 9.1 语言策略

- 默认跟随系统语言
- 系统语言为 `zh*` 时使用简体中文
- 系统语言为 `en*` 时使用英文
- 其他系统语言回退到简体中文

### 9.2 `svn` 路径策略

应用按以下顺序查找 `svn`：

1. 环境变量 `SVN_BINARY_PATH`
2. Settings 中用户配置路径
3. 默认路径
   - `/usr/bin/svn`
   - `/opt/homebrew/bin/svn`
   - `/usr/local/bin/svn`

## 10. 菜单栏入口

应用额外提供了菜单栏图标，便于：

- 唤起主窗口
- 新建 checkout
- 打开仓库
- 打开 Settings
- 查看当前选中仓库的摘要

菜单栏摘要会显示：

- 当前选中仓库
- 仓库数量
- 当前仓库 issue 数量或摘要错误

## 11. 常见问题

### 11.1 打开仓库失败

常见原因：

- 目录不是合法 SVN 工作副本
- 本机未安装 `svn`
- `svn` 路径配置错误

### 11.2 Update / Commit 超时

建议检查：

- 网络连通性
- 仓库服务器响应
- Settings 中的超时配置
- 是否存在认证或证书交互阻塞

### 11.3 文件状态看起来不对

当前目录树会在展开目录时按需刷新状态。如果外部程序刚改动了 working copy，重新展开目录或手动刷新通常即可同步状态。

## 12. 更多资料

- 环境与打包请看 [Installation and Packaging](installation-and-packaging.md)
- 架构实现请看 [Architecture](architecture.md)
- 功能边界请看 [Limitations](limitations.md)
