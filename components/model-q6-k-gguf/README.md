# MiniCPM5-2B-Q6_K.gguf

Model weights for [MiniCPM5-2B](https://huggingface.co/openbmb/MiniCPM5-2B), the 2.5B dense
instruction-tuned model from OpenBMB, quantized to Q6_K by bartowski and published in
[bartowski/MiniCPM5-2B-GGUF](https://huggingface.co/bartowski/MiniCPM5-2B-GGUF).

The weights are **not** committed (`.gitignore` excludes `*.gguf`). `make init-all` downloads them
into this directory and verifies the pinned checksum:

```shell
make download-extra-models   # hf download $(GGUF_EXTRA_REPO) $(Q6K_FILE) --local-dir components/model-q6-k-gguf
make verify-extra-models     # sha256sum --check against Q6K_SHA256 in the Makefile
```

To build offline (or from an internal mirror), place the file here yourself and run
`make verify-extra-models`; the `GGUF_EXTRA_REPO`/`Q6K_FILE`/`Q6K_SHA256` variables in the
`Makefile` are overridable.

| Field | Value |
| --- | --- |
| File | `MiniCPM5-2B-Q6_K.gguf` |
| Size | 2 107 305 184 bytes (1.96 GB) |
| sha256 | `c9f424852aa737b3f5f2f83096a6214d86a8ea2516f3a0fbaa04a3b4feba477d` |
| Quantization | Q6_K (single file, no shards) |
| License | Apache-2.0 (OpenBMB) |

Single-file GGUF, so `models/minicpm5-2b-q6k/model.yaml` needs no `layout`/symlinks: the weight is
mounted by the `model-q6-k-gguf` component at `$SNAP_COMPONENTS/model-q6-k-gguf/` and exposed
as `MODEL_FILE`.

## Why this README is tracked

`snap/snapcraft.yaml` has a `local-component-files` part with `source: components`. Keeping this
directory in git makes a fresh clone buildable (and fails with a clear "file not found" instead of
a missing source directory) while the 1.96 GB weight stays out of the repository. The part
organizes only the `.gguf` into the component and prunes everything else, so this file is never
shipped inside the snap.
