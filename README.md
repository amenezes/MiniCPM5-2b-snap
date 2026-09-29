# MiniCPM5 2B inference snap

[![minicpm5-2b](https://snapcraft.io/minicpm5-2b/badge.svg)](https://snapcraft.io/minicpm5-2b)

<!-- README-I18N:START -->

**English** | [Português (Brasil)](./README.pt-BR.md) | [简体中文](./README.zh-CN.md)

<!-- README-I18N:END -->

**[MiniCPM5-2B](https://huggingface.co/openbmb/MiniCPM5-2B)** is
[OpenBMB](https://huggingface.co/openbmb)'s 2.5B dense instruction-tuned model, built for
on-device and resource-constrained deployment, with reasoning and tool-calling capabilities.

Use this snap to quickly install an optimized environment for local inference with
MiniCPM5 2B.

The snap includes the following hardware-optimized inference engines:

* cpu: Optimized for x64 and ARM (armv8, armv9) CPUs
* nvidia-gpu: CUDA-enabled GPU acceleration

The most suitable engine is automatically selected based on the available hardware.

#### Install
```shell
sudo snap install minicpm5-2b
```

#### Run
```shell
minicpm5-2b
```

> [!TIP]
> Some accelerators require extra [drivers](https://documentation.ubuntu.com/inference-snaps/how-to/setup/drivers/) to be usable with this snap.

## Quantization variants

Three quantization levels are available. Q4_K_M is the default; switch with
`sudo minicpm5-2b use-model <variant>` and restart the service:

| Variant | Model weights | Disk (installed) | Notes |
| --- | --- | --- | --- |
| `minicpm5-2b` (Q4_K_M) | 1.5 GB | ~1.7 GB | Best size/quality trade-off, recommended |
| `minicpm5-2b-q5km` (Q5_K_M) | 1.8 GB | ~2.0 GB | Better reasoning and tool-calling quality |
| `minicpm5-2b-q6k` (Q6_K) | 2.0 GB | ~2.2 GB | Near-FP16 quality for accuracy-sensitive workloads |

```shell
sudo minicpm5-2b use-model minicpm5-2b-q5km
sudo snap restart minicpm5-2b
```

## Requirements

Measured as the peak RSS of the `llama-server` process, with the bundled Q4_K_M weights
(1.6 GB) and the pinned llama.cpp runtime on the cpu engine:

| Context size | Peak memory |
| --- | --- |
| 4 096 (floor set by `--fit-ctx`) | ~2.6 GB |
| 32 768 | ~3.8 GB |
| 131 072 (model maximum) | ~7.8 GB |

Disk usage is ~1.7 GB once installed (snap, llama.cpp component and model weights),
plus ~1.1 GB if the nvidia-gpu engine is selected. Larger quantizations add ~300-500 MB.

The context size is not fixed: llama.cpp's `--fit` feature sizes it to the memory
available, using `--fit-ctx` (default 4096) as the floor. Budget **~42 KB per token** of
context on top of ~2.5 GB, and the runtime picks the largest context that fits. Below
~2.5 GB the model does not run.

## Configuration

The engine reads its settings from the snap configuration:

| Setting | Default | Purpose |
| --- | --- | --- |
| `min-context-size` | `4096` | Floor for `--fit-ctx`; `--fit` grows the context up to the model's 128K limit |
| `sleep-idle-seconds` | `600` | Idle time before `llama-server` unloads the model |
| `reasoning-preserve` | `true` | Keep the reasoning trace in the full history (`false` saves tokens) |
| `http.port` / `http.host` | `8354` / `127.0.0.1` | OpenAI-compatible API |
| `webui.http.port` / `webui.http.host` | `8355` / `127.0.0.1` | Bundled web UI |

Read them with `minicpm5-2b get`; changing them needs root (`sudo minicpm5-2b set`), and the
service has to be restarted to apply:

```shell
minicpm5-2b get
sudo minicpm5-2b set reasoning-preserve=false
sudo snap restart minicpm5-2b
```

### Thinking per request

`reasoning-preserve` decides what is kept in the *history*; whether the model thinks before
answering is a per-request decision. MiniCPM5-2B is a thinking model, so with the default template
settings a small `max_tokens` can be consumed entirely by the reasoning trace: the reply comes back
with `content: ""` and `finish_reason: "length"`. Skip it with the template kwarg:

```shell
curl -s http://127.0.0.1:8354/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "minicpm5-2b",
  "messages": [{"role": "user", "content": "Say OK"}],
  "max_tokens": 256, "temperature": 1.0, "top_p": 0.95, "min_p": 0.0,
  "chat_template_kwargs": {"enable_thinking": false}}'
```

With thinking disabled the answer goes straight to `message.content` and `reasoning_content` is
empty.

## Resources

📚 **[Documentation](https://documentation.ubuntu.com/inference-snaps/)**, learn how to use inference snaps

🤗 **[Model card](https://huggingface.co/openbmb/MiniCPM5-2B)**, upstream documentation for the model

📦 **[GGUF weights](https://huggingface.co/openbmb/MiniCPM5-2B-GGUF)**, the quantized weights this snap bundles

🧩 **[MiniCPM5 collection](https://huggingface.co/collections/openbmb/minicpm5)**, the other sizes and formats in the family

💻 **[MiniCPM source](https://github.com/OpenBMB/MiniCPM)**, upstream repository and deployment guides

🐛 **[Issues](https://github.com/canonical/inference-snaps/issues)**, report bugs and request features

## Notes on this snap

* **Runtime pin:** llama.cpp is pinned to `b10344`. MiniCPM5-2B needs the llama.cpp
  MiniCPM5 chat/tool-call parser, which first appeared in build `b10154`; `b10344` is the
  build also used by the `phi4`, `smollm2` and `gemma4` snaps. Bumps arrive as reviewed
  Renovate PRs (never automerged) and must pass the tool-calling smoke test.
* **Tool calling:** requires the GGUF's embedded chat template, applied by `llama-server`
  (`--jinja`). Reasoning is returned in `reasoning_content`. The model only *proposes* a call
  (`finish_reason: "tool_calls"`) and executing it is the client's job -- the snap ships no tool
  executor, so nothing runs commands on your machine on the model's behalf.
* **Reasoning trace:** the engine always passes `--reasoning-preserve` or
  `--no-reasoning-preserve` explicitly, because the llama.cpp default changed between builds
  (`b10344`: off, `b11100`: on). Preservation is on by default; set `reasoning-preserve=false`
  to trade it for token budget (see [Configuration](#configuration)).
* **Sampling:** the engine sets `min_p=0.0` as recommended by the model card (the
  llama.cpp default of `0.05` leads to repetitive output).
* **Model license:** Apache-2.0 (OpenBMB). The packaging code is GPL-3.0.
* **Engine selection:** the `nvidia-gpu` engine is picked whenever an NVIDIA GPU is
  present on the PCI bus, even if the driver is not usable. CUDA then fails to
  initialise and llama.cpp falls back to the CPU backend; run
  `sudo minicpm5-2b use-engine cpu` to switch back and free the ~1.1 GB component. Selection runs
  at install time and needs the `hardware-observe` interface; if its auto-connection has not been
  granted, connect it and re-run the selection manually:
  ```shell
  sudo snap connect minicpm5-2b:hardware-observe
  sudo minicpm5-2b use-engine --auto
  ```
* **Provider:** the snap exports an `inference-provider` content slot, so another snap can consume
  this endpoint instead of running its own model.
* **Local API:** the endpoint has no authentication and allows cross-origin requests, which the
  bundled web UI needs. It listens on `127.0.0.1` only -- do not rebind `http.host` to a public
  interface.

## Build and install from source

Clone the repo:
```shell
git clone <this-repo>
```

Initialize the development environment:
```shell
make init
```

`snapcraft` builds inside a container by default, so a build provider must be available first.
With LXD, initialize it once (`--storage-backend=dir` avoids a ZFS loop pool):

```shell
lxd init --auto --storage-backend=dir
```

Without a provider, build on the host with `sudo snapcraft pack --destructive-mode
--platform amd64` instead.

Build and install snap:
```shell
make build
make install
```

`make init` downloads the default Q4_K_M GGUF (~1.5 GB) and verifies its sha256. To
download all quantization variants (Q4_K_M, Q5_K_M, Q6_K), use `make init-all` instead.
To use a local copy, place it at `components/model-q4-k-m-gguf/MiniCPM5-2B-Q4_K_M.gguf`
(and similarly for the other variants) and run `make verify-model` (or
`make verify-extra-models`).

## Publishing to the Snap Store

Two store-side requests are prerequisites, and both take time, so open them early:

* **Component upload access** -- the weights and the llama.cpp runtime ship as
  [components](https://snapcraft.io/docs/explanation/how-snaps-work/snap-components/), and
  uploading components is limited to accounts on the store's allow-list. Request it on the
  [Snapcraft forum](https://forum.snapcraft.io/c/store-requests/).
* **Auto-connection of `hardware-observe`** -- the interface is not auto-connected by default, so
  a store install cannot detect the hardware during `use-engine --auto` until the request is
  granted (see the
  [process](https://snapcraft.io/docs/reference/administration/process-for-aliases-auto-connections-and-tracks/)).

The first upload also requires a registered name, and a repository that actually exists: the store
listing links to `website`, `source-code`, `issues` and `contact` from `snap/snapcraft.yaml`.

```shell
snapcraft login
snapcraft register minicpm5-2b
make build
./dev/upload.sh latest/edge   # snapcraft upload <snap> --component ... --release=latest/edge
```

`.github/workflows/cicd.yaml` publishes to `latest/edge` on every push to `main` once the
`SNAPCRAFT_STORE_CREDENTIALS` secret (the output of `snapcraft export-login`) is configured.
