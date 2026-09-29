# MiniCPM5-2B-Q4_K_M.gguf

Model weights for [MiniCPM5-2B](https://huggingface.co/openbmb/MiniCPM5-2B), the 2.5B dense
instruction-tuned model from OpenBMB, quantized to Q4_K_M by the model authors and published in
[openbmb/MiniCPM5-2B-GGUF](https://huggingface.co/openbmb/MiniCPM5-2B-GGUF).

The weights are **not** committed (`.gitignore` excludes `*.gguf`). `make init` downloads them
into this directory and verifies the pinned checksum:

```shell
make download-models   # hf download $(GGUF_REPO) $(GGUF_FILE) --local-dir components/model-q4-k-m-gguf
make verify-model      # sha256sum --check against GGUF_SHA256 in the Makefile
```

To build offline (or from an internal mirror), place the file here yourself and run
`make verify-model`; the `GGUF_REPO`/`GGUF_FILE`/`GGUF_SHA256` variables in the `Makefile` are
overridable.

| Field | Value |
| --- | --- |
| File | `MiniCPM5-2B-Q4_K_M.gguf` |
| Size | 1 561 318 368 bytes (1.56 GB) |
| sha256 | `ec2d5801640099e97d8d7e8003ad4d81f336e757811f03a26173dddf386602fd` |
| Quantization | Q4_K_M (single file, no shards) |
| License | Apache-2.0 (OpenBMB) |

Single-file GGUF, so `models/minicpm5-2b/model.yaml` needs no `layout`/symlinks: the weight is
mounted by the `model-q4-k-m-gguf` component at `$SNAP_COMPONENTS/model-q4-k-m-gguf/` and exposed
as `MODEL_FILE`.

## Why this README is tracked

`snap/snapcraft.yaml` has a `local-component-files` part with `source: components`. Keeping this
directory in git makes a fresh clone buildable (and fails with a clear "file not found" instead of
a missing source directory) while the 1.56 GB weight stays out of the repository. The part
organizes only the `.gguf` into the component and prunes everything else, so this file is never
shipped inside the snap.
