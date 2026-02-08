# Neovim Fuzz Testing

This directory contains [libFuzzer](https://llvm.org/docs/LibFuzzer.html)-based
fuzz targets for neovim internals.

## Targets

| Target | Description | Depends on |
|--------|-------------|------------|
| `fuzz_vterm` | Terminal escape-sequence parser (`vterm_input_write`) | libnvim |
| `fuzz_base64` | Base64 encode/decode round-trip (`base64_encode`, `base64_decode`) | libnvim |
| `fuzz_mpack` | Msgpack tokenizer (`mpack_read`) | standalone (mpack_core.c only) |

## Building

```bash
# Configure with fuzzing enabled (requires Clang)
cmake -B build -DENABLE_FUZZING=ON \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_C_FLAGS="-fsanitize=address,fuzzer-no-link -g -O1" \
      -DFUZZ_ENGINE="-fsanitize=fuzzer"

# Build all fuzz targets
cmake --build build --target fuzz

# Or build individual targets
cmake --build build --target fuzz_vterm
cmake --build build --target fuzz_base64
cmake --build build --target fuzz_mpack
```

## Running

```bash
# Create a corpus directory and run
mkdir -p corpus_vterm
./build/bin/fuzz_vterm -dict=test/fuzz/vterm.dict corpus_vterm/

mkdir -p corpus_base64
./build/bin/fuzz_base64 -dict=test/fuzz/base64.dict corpus_base64/

mkdir -p corpus_mpack
./build/bin/fuzz_mpack -dict=test/fuzz/mpack.dict corpus_mpack/
```

## With other sanitizers

```bash
# Memory Sanitizer
cmake -B build -DENABLE_FUZZING=ON \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_C_FLAGS="-fsanitize=memory,fuzzer-no-link -g -O1" \
      -DFUZZ_ENGINE="-fsanitize=fuzzer"

# Undefined Behavior Sanitizer
cmake -B build -DENABLE_FUZZING=ON \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_C_FLAGS="-fsanitize=undefined,fuzzer-no-link -g -O1" \
      -DFUZZ_ENGINE="-fsanitize=fuzzer"
```

## OSS-Fuzz

These targets are integrated into [OSS-Fuzz](https://github.com/google/oss-fuzz)
for continuous fuzzing on Google's infrastructure.
