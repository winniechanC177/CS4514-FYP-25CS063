#!/usr/bin/env bash
set -euo pipefail


mkdir -p assets/whisper
mkdir -p assets/kokoro-int8-multi-lang-v1_0

if [[ ! -f .env ]]; then
  printf '# CI stub\n' > .env
fi

[[ -f assets/silero_vad.onnx ]] || : > assets/silero_vad.onnx
[[ -f assets/whisper/base-encoder.int8.onnx ]] || : > assets/whisper/base-encoder.int8.onnx
[[ -f assets/whisper/base-decoder.int8.onnx ]] || : > assets/whisper/base-decoder.int8.onnx
[[ -f assets/whisper/base-tokens.txt ]] || printf 'stub\n' > assets/whisper/base-tokens.txt
[[ -f assets/kokoro-int8-multi-lang-v1_0/model.int8.onnx ]] || : > assets/kokoro-int8-multi-lang-v1_0/model.int8.onnx

echo 'CI asset stubs prepared.'