# CodexUsageMonitor

<img src="app/mascot.png" alt="白龙娘图标" width="96" align="right">

一个中文 Windows 桌面用量便签，查看 Codex 额度和本机 token 活动，尽量少占桌面空间。如果你也需要，希望能帮你少造一个轮子。

**[下载最新版 EXE](https://github.com/amashigeo/CodexUsageMonitor/releases/latest)**

## v1.8.2 本地用量存档

按日和会话保存 token、API 折算金额、会话名称和模型。首次启动导入本机仍可读取的历史，之后增量保存。原始日志清理后，可以从扩展统计右上角切换年份，查看已保存的用量。

## v1.8.1 启动兼容修复

修复新版可能复用旧后台，导致便签有数据但扩展页 404 的问题。启动时检查后台版本及扩展页面，确认是本程序的旧后台后自动替换；解压目录缺少统计页资源时重新补齐。扩展按钮打开前检查服务，启动失败会显示错误并保留 startup-error.log，不再静默失败。

## v1.8.0 扩展统计

便签底部新增 **扩展统计** 按钮，在独立窗口查看本日、本周、本月、本年的 token 与 API 金额。每日用量以 GitHub 风格方块图显示，支持按 token 或金额着色，点击日期查看数据。各时间范围按会话汇总花费，支持搜索与金额 / token 排序。

本周从周一开始。首次扫描完成前，页面会提示当前统计尚未完整。

## 功能

- 5 小时、每周已用额度与重置时间。
- 额度消耗速度、预计可用时间，额外重置次数及最早到期日。
- 今日缓存命中、未命中、缓存命中率和输出 token。
- 今日、本月 token 汇总与 API 等价美元费用。
- 最近三条会话：名称、模型、累计 token、API 费用和上下文 token / 百分比。
- 窗口置顶、拖动、边框缩放；收起到系统托盘，不占任务栏。
- 使用时每 5 秒读取日志；空闲 10 分钟后主动查询账户额度。

## 使用

1. 使用 Windows 10 / 11，先安装并登录 Codex。
2. 从 Releases 下载 `CodexUsageMonitor.exe`，双击启动。EXE 内置 Node.js，无需另外安装 Node.js 或填写 API Key。
3. 拖动标题移动窗口，拖动边框调整大小；右上角按钮切换置顶。
4. 减号或叉号收起到托盘。单击托盘图标显示 / 隐藏，右键可置顶或退出。找不到图标时查看托盘的“∧”。

首次启动会将程序解压到 `%LOCALAPPDATA%\CodexUsageMonitor\app-1.8.2`，启动本地统计服务。首次扫描可能稍慢。托盘“退出”关闭便签。彻底停止后台服务可运行该目录里的 `停止监控.cmd`。升级前先停止旧版服务，再运行新 EXE。

也可以直接运行源码目录 `app/启动面板.cmd`，需要 Node.js 20+；启动器也会尝试查找本机 Codex 附带的 Node.js。

## 数据与隐私

额度通过 Codex 官方 `account/rateLimits/read` 查询，并结合本机日志更新。Token 来自 `%USERPROFILE%\.codex\sessions`，会话名称来自 `session_index.jsonl`；支持使用 `CODEX_HOME` 指定目录。登录由本机 Codex CLI 管理，本程序不自行读取或复制登录凭据。

用量存档位于 `%LOCALAPPDATA%\CodexUsageMonitor\usage-history-*.json`，按 Codex 数据目录分开保存。存档仅记录用量汇总和会话列表所需信息，不含聊天正文、原始日志或登录凭据。窗口设置和额外重置缓存各自保存于程序目录。

**发布包仅包含程序和运行所需的资源。** 每台电脑根据自身日志建立用量存档。

本地 HTTP 服务只监听 `127.0.0.1:47831`，不向局域网开放。程序会为额度查询联系 Codex 服务；不会将本地聊天正文上传到本仓库或其他服务。

## 统计口径

- Token 汇总覆盖本机已读取并存档的日志。“今日”按电脑本地时区，“本月”从本月 1 日开始。首次存档前已缺失的记录无法补算。
- 缓存命中率 = 缓存命中输入 / 全部输入。未命中输入 = 全部输入 − 缓存命中。
- 输出 token 已包含推理 token，不重复相加。
- Token 速度为近 60 秒日志增量 / 60，包含工具、等待和空闲时间，并非模型流式生成速度。
- 额度速度按近 1 小时同一窗口内的变化计算；预计可用时间为线性推算，样本不足时显示“采样中”。
- 会话运行状态根据本机任务开始 / 完成日志估计，10 分钟无新活动后不再视为运行中；上下文是上次请求 token 相对窗口的近似比例。
- 美元金额按各请求记录的模型、未缓存输入、缓存命中和输出 token，参考标准 API 价格折算，**不是订阅扣费或实际账单**。未知模型参考 GPT-6.1 Sol；未单独计工具、图片和 Fast / Ultrafast 差价。参考价及核对日期见 [`app/pricing.json`](app/pricing.json)。

## 开发与测试

```powershell
node --test app/test.cjs app/quota-client.test.cjs app/cost.test.cjs app/analytics.test.cjs
node app/server.cjs
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app/widget.ps1 -SelfTest
```

本地完整统计页：`http://127.0.0.1:47831`。

### 构建 EXE

在 Windows 上安装 Node.js，使用系统自带 Windows PowerShell 和 .NET Framework C# 编译器：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/build-exe.ps1
```

输出为 `dist/CodexUsageMonitor.exe`。`scripts/pack-icon.ps1` 可从现有图片重新生成多尺寸图标。构建只打包清单中列出的程序文件。

### 配置

| 环境变量 | 用途 |
| --- | --- |
| `CODEX_HOME` | Codex 本地目录 |
| `CODEX_USAGE_CLI` | Codex CLI 路径 |
| `CODEX_USAGE_REFRESH_MINUTES` | 空闲额度查询间隔，默认 10 分钟 |
| `CODEX_USAGE_PORT` | 本地服务端口；便签和启动器固定使用默认 47831 |
| `CODEX_USAGE_DISABLE_REMOTE=1` | 仅统计日志，禁用主动额度查询 |

## 图标与依赖

图标为参考社区 GPT 白龙娘形象生成的 Q 版：白发、紫瞳、双龙角。它不是 OpenAI 官方角色或官方应用。参考出处及 Node.js 许可证见 [第三方说明](THIRD_PARTY_NOTICES.md)。

接口参考：[Codex App Server](https://learn.chatgpt.com/docs/app-server)；价格参考：[OpenAI API Pricing](https://developers.openai.com/api/docs/pricing)。
