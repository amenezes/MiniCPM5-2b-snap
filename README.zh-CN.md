# MiniCPM5 2B 推理 snap

[![minicpm5-2b](https://snapcraft.io/minicpm5-2b/badge.svg)](https://snapcraft.io/minicpm5-2b)

<!-- README-I18N:START -->

[English](./README.md) | [Português (Brasil)](./README.pt-BR.md) | **简体中文**

<!-- README-I18N:END -->

**[MiniCPM5-2B](https://huggingface.co/openbmb/MiniCPM5-2B)** 是
[OpenBMB](https://huggingface.co/openbmb) 推出的 2.5B 稠密指令微调模型，面向端侧部署和
资源受限环境，具备推理与工具调用能力。

使用本 snap 可快速搭建一套针对 MiniCPM5 2B 优化的本地推理环境。

本 snap 包含以下针对硬件优化的推理引擎：

* cpu：针对 x64 与 ARM（armv8、armv9）CPU 优化
* nvidia-gpu：CUDA GPU 加速

系统会根据可用硬件自动选择最合适的引擎。

#### 安装
```shell
sudo snap install minicpm5-2b
```

#### 运行
```shell
minicpm5-2b
```

> [!TIP]
> 部分加速器需要额外安装[驱动程序](https://documentation.ubuntu.com/inference-snaps/how-to/setup/drivers/)才能与本 snap 配合使用。

## 资源需求

以下数据为 `llama-server` 进程的 RSS 峰值，基于本 snap 内置的 Q4_K_M 权重（1.6 GB）
与所固定的 llama.cpp 运行时，在 cpu 引擎下实测：

| 上下文长度 | 内存峰值 |
| --- | --- |
| 4 096（`--fit-ctx` 设定的下限） | 约 2.6 GB |
| 32 768 | 约 3.8 GB |
| 131 072（模型上限） | 约 7.8 GB |

安装后占用磁盘约 1.7 GB（snap、llama.cpp 组件与模型权重）；若选用 nvidia-gpu 引擎，
需再增加约 1.1 GB。

上下文长度并非固定值：llama.cpp 的 `--fit` 会依据可用内存自动设定，并以 `--fit-ctx`
（默认 4096）为下限。除约 2.5 GB 的基础占用外，请按**每 token 约 42 KB** 估算，
运行时会选取能够容纳的最大上下文。低于约 2.5 GB 时模型无法运行。

## 配置

引擎从 snap 配置中读取设置：

| 配置项 | 默认值 | 作用 |
| --- | --- | --- |
| `min-context-size` | `4096` | `--fit-ctx` 的下限；`--fit` 会将上下文扩展到模型 128K 的上限 |
| `sleep-idle-seconds` | `600` | `llama-server` 卸载模型前的空闲时间 |
| `reasoning-preserve` | `true` | 在完整历史中保留推理内容（设为 `false` 可节省 token） |
| `http.port` / `http.host` | `8354` / `127.0.0.1` | 兼容 OpenAI 的 API |
| `webui.http.port` / `webui.http.host` | `8355` / `127.0.0.1` | snap 内置的 Web UI |

使用 `minicpm5-2b get` 查看；修改需要 root（`sudo minicpm5-2b set`），并且必须重启服务才会生效：

```shell
minicpm5-2b get
sudo minicpm5-2b set reasoning-preserve=false
sudo snap restart minicpm5-2b
```

### 按请求控制思考

`reasoning-preserve` 决定*历史记录*中保留什么；模型是否在回答前思考则由每次请求决定。
MiniCPM5-2B 是推理模型，在默认模板设置下，较小的 `max_tokens` 可能被推理内容全部占用：
响应会返回 `content: ""` 和 `finish_reason: "length"`。可通过模板参数跳过思考：

```shell
curl -s http://127.0.0.1:8354/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "minicpm5-2b",
  "messages": [{"role": "user", "content": "回答 OK"}],
  "max_tokens": 256, "temperature": 1.0, "top_p": 0.95, "min_p": 0.0,
  "chat_template_kwargs": {"enable_thinking": false}}'
```

关闭思考后，回答直接写入 `message.content`，`reasoning_content` 为空。

## 相关资源

📚 **[文档](https://documentation.ubuntu.com/inference-snaps/)**，了解如何使用推理 snap

🤗 **[模型卡](https://huggingface.co/openbmb/MiniCPM5-2B)**，模型的上游文档

📦 **[GGUF 权重](https://huggingface.co/openbmb/MiniCPM5-2B-GGUF)**，本 snap 内置的量化权重

🧩 **[MiniCPM5 合集](https://huggingface.co/collections/openbmb/minicpm5)**，该系列的其他尺寸与格式

💻 **[MiniCPM 源码](https://github.com/OpenBMB/MiniCPM)**，上游仓库与部署指南

🐛 **[Issues](https://github.com/canonical/inference-snaps/issues)**，反馈问题或提出功能需求

## 关于本 snap 的说明

* **运行时版本固定：** llama.cpp 固定在构建版本 `b10344`。MiniCPM5-2B 需要 llama.cpp 的
  MiniCPM5 对话与工具调用解析器，该解析器自构建版本 `b10154` 起提供；`b10344` 同时也是
  `phi4`、`smollm2` 和 `gemma4` 三个 snap 所采用的构建版本。版本更新以 Renovate 提交的
  待审 PR 形式进入（绝不自动合并），并且必须通过工具调用冒烟测试。
* **工具调用：** 依赖 GGUF 内嵌的 chat template，由 `llama-server`（`--jinja`）应用。
  推理内容通过 `reasoning_content` 返回。模型只会*提出*调用（`finish_reason: "tool_calls"`），
  执行由客户端负责；本 snap 不包含工具执行器，因此不会以模型的名义在你的机器上运行任何命令。
* **推理内容保留：** 引擎始终显式传入 `--reasoning-preserve` 或 `--no-reasoning-preserve`，
  因为 llama.cpp 的默认值在不同构建之间发生过变化（`b10344`：关闭，`b11100`：开启）。
  默认保留；设为 `reasoning-preserve=false` 可用 token 预算换取（见[配置](#配置)）。
* **采样：** 引擎按模型卡的建议设置 `min_p=0.0`（llama.cpp 默认的 `0.05` 会导致输出
  重复）。
* **模型许可证：** Apache-2.0（OpenBMB）。打包代码为 GPL-3.0。
* **引擎选择：** 只要 PCI 总线上存在 NVIDIA GPU，就会选用 `nvidia-gpu` 引擎，即使驱动
  不可用。此时 CUDA 初始化失败，llama.cpp 会回退到 CPU 后端；可运行
  `sudo minicpm5-2b use-engine cpu` 切回并释放约 1.1 GB 的组件。引擎在安装时选择，需要
  `hardware-observe` 接口；若该接口尚未获得自动连接授权，请手动连接并重新执行选择：
  ```shell
  sudo snap connect minicpm5-2b:hardware-observe
  sudo minicpm5-2b use-engine --auto
  ```
* **Provider：** 本 snap 导出一个 `inference-provider` content 插槽，其他 snap 可直接使用该
  端点，而无需自行运行模型。
* **本地 API：** 该端点没有身份验证，并允许跨域请求（内置 Web UI 需要）。它仅监听
  `127.0.0.1` —— 请勿将 `http.host` 改为公网接口。

## 从源码构建并安装

克隆仓库：
```shell
git clone <this-repo>
```

初始化开发环境：
```shell
make init
```

默认情况下 `snapcraft` 在容器内构建，因此需要先准备构建提供程序。使用 LXD 时，先初始化一次
（`--storage-backend=dir` 可避免创建 ZFS loop 池）：

```shell
lxd init --auto --storage-backend=dir
```

若没有提供程序，可直接在主机上构建：
`sudo snapcraft pack --destructive-mode --platform amd64`。

构建并安装 snap：
```shell
make build
make install
```

`make init` 会下载固定版本的 GGUF（约 1.5 GB）并校验其 sha256。如需改用本地副本，
请将其放到 `components/model-q4-k-m-gguf/MiniCPM5-2B-Q4_K_M.gguf`，然后运行
`make verify-model`。

## 发布到 Snap Store

有两项商店侧申请是前置条件，且都需要时间，请尽早提交：

* **组件上传权限** —— 权重与 llama.cpp 运行时以
  [组件](https://snapcraft.io/docs/explanation/how-snaps-work/snap-components/)形式发布，而组件
  上传仅限商店白名单内的账号。请在
  [Snapcraft 论坛](https://forum.snapcraft.io/c/store-requests/)提交申请。
* **`hardware-observe` 的自动连接** —— 该接口默认不会自动连接，因此在申请获批前，从商店安装的
  snap 无法在 `use-engine --auto` 时检测硬件（参见
  [流程](https://snapcraft.io/docs/reference/administration/process-for-aliases-auto-connections-and-tracks/)）。

首次上传还需要注册名称，以及一个真实存在的仓库：商店页面会链接到 `snap/snapcraft.yaml` 中的
`website`、`source-code`、`issues` 和 `contact`。

```shell
snapcraft login
snapcraft register minicpm5-2b
make build
./dev/upload.sh latest/edge   # snapcraft upload <snap> --component ... --release=latest/edge
```

配置好 `SNAPCRAFT_STORE_CREDENTIALS` secret（`snapcraft export-login` 的输出）后，
`.github/workflows/cicd.yaml` 会在每次推送到 `main` 时发布到 `latest/edge`。
