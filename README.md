# CodexUsageMonitor

<img src="app/mascot.png" alt="白龙娘图标" width="96" align="right">

一个中文 Windows 桌面用量便签，查看 Codex 额度和本机 token 活动，尽量少占桌面空间。如果你也需要，希望能帮你少造一个轮子。

**[下载最新版 EXE](https://github.com/amashigeo/CodexUsageMonitor/releases/latest)**

## v1.8.0 扩展统计

便签底部新增 **扩展统计** 按钮，在独立窗口查看本日、本周、本月、本年的 token 与 API 金额。每日用量以 GitHub 风格方块图显示，支持按 token 或金额着色，点击日期查看数据。各时间范围按会话汇总花费，支持搜索与金额 / token 排序。

本周从周一开始。本年数据来自本机仍保留的日志；首次启动会扫描年度历史，完成前页面提示部分统计。年度统计按日期和会话聚合在内存中，不新增聊天存档。

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

首次启动会将程序解压到 `%LOCALAPPDATA%\CodexUsageMonitor\app-1.8.0`，启动本地统计服务。首次扫描可能稍慢。托盘“退出”关闭便签；彻底停止后台服务可运行该目录里的 `停止监控.cmd`。升级前请先停止旧版服务，再运行新 EXE。

也可以直接运行源码目录 `app/启动面板.cmd`，需要 Node.js 20+；启动器也会尝试查找本机 Codex 附带的 Node.js。

## 数据与隐私

额度通过 Codex 官方 `account/rateLimits/read` 查询，并结合本机日志更新。Token 来自 `%USERPROFILE%\.codex\sessions`，会话名称来自 `session_index.jsonl`；支持使用 `CODEX_HOME` 指定目录。登录由本机 Codex CLI 管理，本程序不自行读取或复制登录凭据。

程序不复制、另存或上传聊天正文。统计在内存中计算，重启后重新读取日志。只持久保存窗口设置，以及额外重置次数 / 到期日期缓存。接口偶尔仅返回次数时，会保留同次数下最近确认的未过期日期；次数变化或日期过期后不沿用旧日期。

**发布的 EXE 不包含作者的聊天记录、会话名称、登录凭据、窗口设置、重置缓存或真实预览截图。** 其他人运行时使用自己电脑上的登录和日志。

本地 HTTP 服务只监听 `127.0.0.1:47831`，不向局域网开放。程序会为额度查询联系 Codex 服务；不会将本地聊天正文上传到本仓库或其他服务。

## 统计口径

- Token 汇总仅覆盖本机保留的日志，不代表账号所有设备或云端的全部用量；“今日”按电脑本地时区，“本月”从本月 1 日开始。
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

输出为 `dist/CodexUsageMonitor.exe`。图标已经包含在仓库中；`scripts/pack-icon.ps1` 可从现有图片重新生成多尺寸图标。构建不包含个人设置、额度缓存或日志。

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
