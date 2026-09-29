# MiniCPM5-2B-Q5_K_M.gguf

Model weights for [MiniCPM5-2B](https://huggingface.co/openbmb/MiniCPM5-2B), the 2.5B dense
instruction-tuned model from OpenBMB, quantized to Q5_K_M by bartowski and published in
[bartowski/MiniCPM5-2B-GGUF](https://huggingface.co/bartowski/MiniCPM5-2B-GGUF).

The weights are **not** committed (`.gitignore` excludes `*.gguf`). `make init-all` downloads them
into this directory and verifies the pinned checksum:

```shell
make download-extra-models   # hf download $(GGUF_EXTRA_REPO) $(Q5KM_FILE) --local-dir components/model-q5-k-m-gguf
make verify-extra-models     # sha256sum --check against Q5KM_SHA256 in the Makefile
```

To build offline (or from an internal mirror), place the file here yourself and run
`make verify-extra-models`; the `GGUF_EXTRA_REPO`/`Q5KM_FILE`/`Q5KM_SHA256` variables in the
`Makefile` are overridable.

| Field | Value |
| --- | --- |
| File | `MiniCPM5-2B-Q5_K_M.gguf` |
| Size | 1 920 175 328 bytes (1.79 GB) |
| sha256 | `c32c4e0203ac181f5771291725a76dfd94bdc6c54ee79fcb17ebaea3c19c500b` |
| Quantization | Q5_K_M (single file, no shards) |
| License | Apache-2.0 (OpenBMB) |

Single-file GGUF, so `models/minicpm5-2b-q5km/model.yaml` needs no `layout`/symlinks: the weight is
mounted by the `model-q5-k-m-gguf` component at `$SNAP_COMPONENTS/model-q5-k-m-gguf/` and exposed
as `MODEL_FILE`.

## Why this README is tracked

`snap/snapcraft.yaml` has a `local-component-files` part with `source: components`. Keeping this
directory in git makes a fresh clone buildable (and fails with a clear "file not found" instead of
a missing source directory) while the 1.79 GB weight stays out of the repository. The part
organizes only the `.gguf` into the component and prunes everything else, so this file is never
shipped inside the snap.
