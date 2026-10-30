# MiniCPM5-2.6B-DSpark.gguf

DSpark draft model for speculative decoding with [MiniCPM5-2B](https://huggingface.co/openbmb/MiniCPM5-2B),
published by OpenBMB in
[openbmb/MiniCPM5-2B-DSpark-GGUF](https://huggingface.co/openbmb/MiniCPM5-2B-DSpark-GGUF).

It is not a standalone model: it is trained for the exact MiniCPM5-2B tokenizer and is only
loaded by `llama-server` as the `--model-draft` of the `minicpm5-2b-dspark` variant. The draft
never answers on its own -- the target model verifies every proposed token.

The weights are **not** committed (`.gitignore` excludes `*.gguf`). They are optional, so neither
`make init` nor `make build` needs them; download them only when you build/install the DSpark
variant:

```shell
make download-dspark   # hf download $(DSPARK_REPO) $(DSPARK_FILE) --local-dir components/model-dspark-gguf
make verify-dspark     # sha256sum --check against DSPARK_SHA256 in the Makefile
```

`make init-all` downloads and verifies it along with the other variants. To build offline (or from
an internal mirror), place the file here yourself and run `make verify-dspark`; the
`DSPARK_REPO`/`DSPARK_FILE`/`DSPARK_SHA256` variables in the `Makefile` are overridable.

| Field | Value |
| --- | --- |
| File | `MiniCPM5-2.6B-DSpark.gguf` |
| Size | 652 730 240 bytes (653 MB) |
| sha256 | `57df08640f0534a1aac075d1c8bdacdb2b7e5815da6f4e5cfd39ecac3a3f0c26` |
| Quantization | BF16 (single file, no shards) |
| Draft layers / parameters | 5 / 323 776 001 |
| Draft tokens per forward pass | 7 |
| Target hidden-state layers | `[1, 10, 20, 30, 39]` |
| License | Apache-2.0 (OpenBMB) |

Single-file GGUF, so `models/minicpm5-2b-dspark/model.yaml` needs no `layout`/symlinks: the draft is
mounted by the `model-dspark-gguf` component at `$SNAP_COMPONENTS/model-dspark-gguf/` and exposed
as `DRAFT_FILE`.

## Why this README is tracked

`snap/snapcraft.yaml` has a `local-component-files` part with `source: components`. Keeping this
directory in git makes a fresh clone buildable (and fails with a clear "file not found" instead of
a missing source directory) while the 653 MB weight stays out of the repository. The part
organizes only the `.gguf` into the component and prunes everything else, so this file is never
shipped inside the snap.
