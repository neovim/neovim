#!/usr/bin/env bash

# Helper script to build Nvim with profile-guided optimization (PGO), and to
# benchmark the result.  For the default (Nvim-only) PGO no build-system change
# is needed: the flags are injected through CMAKE_C_FLAGS/CMAKE_EXE_LINKER_FLAGS.
# The optional --pgo-deps uses the opt-in DEPS_EXTRA_CFLAGS variable in
# cmake.deps to optimize the bundled dependencies as well.
#
# PGO is a three-stage process:
#
#   1. generate  build an instrumented `nvim` (profiling counters enabled)
#   2. train     run the instrumented `nvim` over a workload, collecting the
#                profile data (.gcda for GCC, .profraw for Clang)
#   3. use       rebuild `nvim` with the collected profiles
#
# All three stages share the same build directory on purpose: GCC writes the
# profile data next to the object files, and the final stage must find it
# there.  Do not run `make clean`/`distclean` in between.
#
# Usage:
#   contrib/pgo.sh [command] [options]
#
# Commands (default: all):
#   all        generate + train + use
#   generate   instrumented build only
#   train      run the training workload (instrumented build must exist)
#   use        rebuild with profiles     (profiles must have been collected)
#   bench BIN...  compare `nvim` binaries: startup and the micro-benchmarks in
#              contrib/pgo_bench.lua, or the project's own benchmark suite with
#              --suite.  Runs shuffled rounds from one shared path and reports
#              the median ratio with its IQR; the reference binary is also
#              benchmarked twice, as a noise control.
#   clean      remove the build directory and the bundled-deps build directory
#
# Options:
#   --pgo-deps         also PGO-optimize the bundled dependencies (GCC only):
#                      LuaJIT and the libraries built by cmake.deps (libuv,
#                      tree-sitter, unibilium, utf8proc, luv).  Mostly
#                      interesting for the bundled tree-sitter parsers, which
#                      parse ~1.6x faster; see BUILD.md for the details.
#   --native           shorthand for --march=native
#   --march LEVEL      add -march=LEVEL to both the instrumented and the
#                      optimized build (e.g. x86-64-v3; the binary is then not
#                      portable to older CPUs).  --march=LEVEL also works.
#   --clang            use Clang (IR PGO + llvm-profdata) instead of GCC
#   --jobs N           parallel jobs (default: nproc, or sysctl -n hw.ncpu)
#   --build-dir DIR    build directory (default: <repo>/build)
#   --rounds N         benchmark rounds for `bench` (default 5, $PGO_BENCH_ROUNDS)
#   --no-control       do not add a same-binary control to `bench`
#   --perf             also report hardware counters for `bench` (needs `perf`)
#   --suite            with `bench`: use Neovim's own benchmark suite
#                      (test/benchmark, what `make benchmark` runs) instead of
#                      the micro-benchmarks, one runner process per spec file.
#                      A round takes minutes; TEST_FILE selects a subset.
#   --no-functional    skip the functional test suite while training
#   --oldtest          also run the legacy test suite while training (slow)
#   --keep             reuse the existing build directory (skip the fresh wipe)
#   -h, --help         show this help
#
# Environment:
#   JOBS, CC               as for a normal build
#   PGO_STARTUP_RUNS       startup runs per benchmark round (default 50)
#   PGO_BENCH_ROUNDS       shuffled rounds for `bench` (default 5)
#   TEST_FILE              `bench --suite`: benchmark file(s) to run
#   PGO_PERF_RUNS          `bench --perf`: runs per binary (default 5)
#   PGO_PERF_EVENTS        `bench --perf`: perf events to count
#
# Requires a Unix-like system with GCC or Clang; the instrumented binary has to
# be run to collect the profile, so cross-compilation and Windows are not
# supported.

set -euo pipefail

die() { echo "contrib/pgo.sh: $*" >&2; exit 1; }

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

compiler=gcc
run_functional=1
run_oldtest=0
fresh=1
pgo_deps=0
march=
jobs=
build=
bench_rounds=
bench_control=1
bench_perf=0
bench_suite=0
cmd=all
positional=()

while [ $# -gt 0 ]; do
  case "$1" in
    all|generate|train|use|bench|clean) cmd=$1 ;;
    --pgo-deps) pgo_deps=1 ;;
    --native) march=native ;;
    --march)
      [ $# -ge 2 ] || die "--march requires an argument"
      case $2 in ''|-*) die "--march: invalid value: '$2'" ;; esac
      march=$2; shift ;;
    --march=*)
      march=${1#--march=}
      [ -n "$march" ] || die "--march: empty value" ;;
    --clang) compiler=clang ;;
    --jobs)
      [ $# -ge 2 ] || die "--jobs requires an argument"
      jobs=$2; shift ;;
    --jobs=*) jobs=${1#--jobs=} ;;
    --build-dir)
      [ $# -ge 2 ] || die "--build-dir requires an argument"
      build=$2; shift ;;
    --build-dir=*) build=${1#--build-dir=} ;;
    --rounds)
      [ $# -ge 2 ] || die "--rounds requires an argument"
      bench_rounds=$2; shift ;;
    --rounds=*) bench_rounds=${1#--rounds=} ;;
    --no-control) bench_control=0 ;;
    --perf) bench_perf=1 ;;
    --suite) bench_suite=1 ;;
    --no-functional) run_functional=0 ;;
    --oldtest) run_oldtest=1 ;;
    --keep) fresh=0 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) positional+=("$1") ;;
  esac
  shift
done

if [ "${#positional[@]}" -gt 0 ] && [ "$cmd" != bench ]; then
  die "unexpected argument: ${positional[0]}"
fi

if [ -n "$jobs" ]; then
  case "$jobs" in *[!0-9]*) die "--jobs: not a positive integer: '$jobs'" ;; esac
  [ "$jobs" -gt 0 ] || die "--jobs must be greater than 0"
fi

bench_rounds=${bench_rounds:-${PGO_BENCH_ROUNDS:-5}}
case "$bench_rounds" in *[!0-9]*) die "--rounds: not a positive integer: '$bench_rounds'" ;; esac
[ "$bench_rounds" -gt 0 ] || die "--rounds must be greater than 0"

# Resolve the repository root.  Fall back to the script location outside a git
# checkout so that --help and an explicit --build-dir still work.
if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
  root=$(cd "$(dirname "$0")/.." && pwd -P)
fi
# Run from the repository root: the training/benchmark scripts glob repo-relative
# paths, so running from a subdirectory would silently collect almost no profile.
cd "$root"

# Make an explicit (possibly relative) --build-dir absolute, so that the profile
# paths mean the same thing to the compiler and to the instrumented binary.
[ -n "$build" ] || build=$root/build
case "$build" in /*) ;; *) build=$root/$build ;; esac

depsdir=$root/.deps

if [ -z "$jobs" ]; then
  jobs=${JOBS:-}
fi
if [ -z "$jobs" ]; then
  if command -v nproc >/dev/null 2>&1; then
    jobs=$(nproc)
  elif command -v sysctl >/dev/null 2>&1; then
    jobs=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
  else
    jobs=4
  fi
fi

export CCACHE_DISABLE=true

if [ "$compiler" = clang ]; then
  CC=${CC:-clang}
else
  CC=${CC:-gcc}
fi

profdir=$build/pgo-profile

if [ "$compiler" = clang ]; then
  gen_cflags='-fprofile-instr-generate'
  gen_ldflags='-fprofile-instr-generate'
  use_cflags="-fprofile-instr-use=$profdir/merged.profdata"
  use_ldflags="-fprofile-instr-use=$profdir/merged.profdata"
else
  gen_cflags='-fprofile-generate -fprofile-update=atomic'
  gen_ldflags='-fprofile-generate'
  use_cflags='-fprofile-use -fprofile-correction -Wno-missing-profile'
  use_ldflags='-fprofile-use'
fi

if [ "$pgo_deps" = 1 ] && [ "$compiler" != gcc ]; then
  echo "contrib/pgo.sh: --pgo-deps is currently supported with GCC only" >&2
  exit 1
fi

# -march must be used in *both* stages: the instrumented build records the
# control-flow graph, and -fprofile-use rejects a profile whose CFG no longer
# matches (a hard error by default, -Wno-coverage-mismatch would not help).
if [ -n "$march" ]; then
  gen_cflags="$gen_cflags -march=$march"
  gen_ldflags="$gen_ldflags -march=$march"
  use_cflags="$use_cflags -march=$march"
  use_ldflags="$use_ldflags -march=$march"
fi

luajit_root=$depsdir/build/src/luajit

build_deps() {
  local extra=${1:-}
  cmake -S "$root/cmake.deps" -B "$depsdir" -G Ninja \
    -D CMAKE_BUILD_TYPE=Release \
    -D "CMAKE_C_COMPILER=$CC" \
    -D "DEPS_EXTRA_CFLAGS=$extra"
  cmake --build "$depsdir"
}

# Remove a build directory, refusing obviously-wrong paths.  A typo in
# --build-dir (or an unset variable) must not cost the user their home.
wipe_build() {
  case "$build" in /|"$HOME"|"$root") die "refusing to remove '$build'" ;; esac
  if [ -e "$build" ] && [ ! -f "$build/CMakeCache.txt" ] && [ ! -f "$build/build.ninja" ] \
    && [ -n "$(ls -A "$build" 2>/dev/null)" ]; then
    die "refusing to remove '$build': it is not a CMake build directory"
  fi
  rm -rf "$build"
}

# Wall-clock seconds with sub-second resolution; BSD/macOS `date` has no %N.
now() {
  local t
  t=$(date +%s.%N 2>/dev/null || true)
  case "$t" in
    ''|*[!0-9.]*) ;;
    *) printf '%s\n' "$t"; return ;;
  esac
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time; print("%.6f" % time.time())'
  elif command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes=time -e 'printf "%.6f\n", time'
  else
    date +%s
  fi
}

# Rebuild the bundled LuaJIT in place: it has its own Makefile, so the flags go
# through TARGET_CFLAGS/TARGET_LDFLAGS.  Its "install" target does not rebuild
# existing artifacts, so the objects are removed first.  The .gcda files are
# kept, because the "use" stage reads them from here.
deps_pgo_luajit() {
  local flags=$1
  if [ ! -f "$luajit_root/src/Makefile" ]; then
    echo "contrib/pgo.sh: bundled LuaJIT not found at $luajit_root" >&2
    exit 1
  fi
  find "$luajit_root/src" -maxdepth 1 \
    \( -name '*.o' -o -name luajit -o -name 'libluajit*.a' -o -name 'libluajit*.so*' \) \
    -delete
  make -C "$luajit_root" -j "$jobs" \
    CC="$CC" CFLAGS=-fPIC 'CFLAGS+=-DLUA_USE_APICHECK' 'CFLAGS+=-funwind-tables' \
    'CCDEBUG+=-g' Q= \
    "TARGET_CFLAGS+=$flags" \
    "TARGET_LDFLAGS+=$flags" \
    "TARGET_SHLDFLAGS+=$flags" \
    PREFIX="$depsdir/usr" install
}

configure() {
  local cflags=$1 ldflags=$2
  cmake -B "$build" -G Ninja \
    -D "CMAKE_BUILD_TYPE=Release" \
    -D "CMAKE_C_COMPILER=$CC" \
    -D "CMAKE_C_FLAGS=$cflags" \
    -D "CMAKE_EXE_LINKER_FLAGS=$ldflags" \
    "$root"
}

stage_generate() {
  if [ "$fresh" = 1 ]; then
    wipe_build
  fi
  if [ "$pgo_deps" = 1 ]; then
    build_deps "$gen_cflags"
    echo "--- instrumenting bundled LuaJIT ---"
    # Start from an empty profile even when the build dir is reused (--keep).
    find "$depsdir/build" -name '*.gcda' -delete 2>/dev/null || true
    deps_pgo_luajit "$gen_cflags"
  else
    build_deps
  fi
  echo "=== PGO stage 1/3: instrumented build (generate) ==="
  configure "$gen_cflags" "$gen_ldflags"
  cmake --build "$build" -j "$jobs"
}

stage_train() {
  echo "=== PGO stage 2/3: training workload ==="
  [ -f "$build/CMakeCache.txt" ] || die "no build directory at $build; run 'generate' first"
  grep -qE -- '-fprofile-(generate|instr-generate)' "$build/CMakeCache.txt" ||
    die "$build was not built with instrumentation; run 'generate' first"
  if [ "$compiler" = clang ]; then
    mkdir -p "$profdir"
    rm -f "$profdir"/*.profraw
    # Export for the whole stage: the functional tests spawn nvim processes too,
    # and without this their .profraw files land in unrelated directories (and
    # are then missing from the merge below).
    export LLVM_PROFILE_FILE="$profdir/nvim-%p-%m.profraw"
  fi
  if [ "$run_functional" = 1 ]; then
    echo "--- functional test suite ---"
    # -k 0: keep going even if some tests fail, we want the coverage.
    cmake --build "$build" --target functionaltest-parallel -j "$jobs" -- -k 0 || true
  fi
  if [ "$run_oldtest" = 1 ]; then
    echo "--- legacy (old) test suite ---"
    make -C "$root" oldtest NVIM_PRG="$build/bin/nvim" || true
  fi
  echo "--- editing workload (contrib/pgo_train.lua) ---"
  if ! VIMRUNTIME="$root/runtime" "$build/bin/nvim" --clean -l "$root/contrib/pgo_train.lua"; then
    echo "contrib/pgo.sh: warning: the editing workload exited non-zero" >&2
  fi

  if [ "$compiler" = clang ]; then
    command -v llvm-profdata >/dev/null ||
      die "llvm-profdata not found (needed for Clang PGO)"
    local npr
    npr=$(find "$profdir" -name '*.profraw' | wc -l)
    echo "collected $npr .profraw files"
    [ "$npr" -gt 0 ] || die "no profile data collected!"
    llvm-profdata merge -o "$profdir/merged.profdata" "$profdir"/*.profraw
  else
    local n
    n=$(find "$build" -name '*.gcda' | wc -l)
    echo "collected $n .gcda files"
    [ "$n" -gt 0 ] || die "no profile data collected!"
  fi

  if [ "$pgo_deps" = 1 ]; then
    local nd
    nd=$(find "$luajit_root" -name '*.gcda' | wc -l)
    echo "collected $nd LuaJIT .gcda files"
    [ "$nd" -gt 0 ] || die "no LuaJIT profile data collected!"
  fi
}

stage_use() {
  echo "=== PGO stage 3/3: optimized build (use) ==="
  [ -f "$build/CMakeCache.txt" ] || die "no build directory at $build; run 'generate' first"
  if [ "$compiler" = clang ]; then
    [ -f "$profdir/merged.profdata" ] ||
      die "no Clang profile at $profdir/merged.profdata; run 'train' first"
  else
    local n
    n=$(find "$build" -name '*.gcda' 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] || die "no .gcda profile data under $build; run 'train' first"
  fi
  if [ "$pgo_deps" = 1 ]; then
    build_deps "$use_cflags"
    echo "--- rebuilding bundled LuaJIT with profiles ---"
    deps_pgo_luajit "$use_cflags"
  fi
  configure "$use_cflags" "$use_ldflags"
  cmake --build "$build" -j "$jobs"
}

# Mean startup time of a fixed number of `--headless +q` runs, in microseconds.
bench_startup() {
  local bin=$1 out=$2
  local n=${PGO_STARTUP_RUNS:-50}
  local t0 t1 i
  t0=$(now)
  for ((i = 0; i < n; i++)); do
    VIMRUNTIME="$root/runtime" "$bin" --headless +q >/dev/null 2>&1
  done
  t1=$(now)
  awk -v a="$t0" -v b="$t1" -v n="$n" \
    'BEGIN {printf "BENCH\tstartup\t%.2f\n", (b - a) * 1000000 / n}' >> "$out"
}

# Micro-benchmarks: startup plus contrib/pgo_bench.lua (microseconds).
bench_micro() {
  local bin=$1 out=$2
  bench_startup "$bin" "$out"
  VIMRUNTIME="$root/runtime" "$bin" --clean -l "$root/contrib/pgo_bench.lua" >> "$out"
}

# Copy a binary into the shared slot, so that every variant runs from the same
# path: two byte-identical binaries at different paths can differ by several
# percent (the loader lays the process out differently).  Nvim loads its parsers
# from `../lib`, which is therefore a symlink to the variant's own lib.
bench_slot() {
  local bin=$1 slot=$2
  local dir lib=
  if [ -d "$(dirname "$bin")/../lib" ]; then
    lib=$(cd "$(dirname "$bin")/../lib" && pwd -P)
  fi
  dir=$(dirname "$(dirname "$slot")")
  mkdir -p "$dir/bin"
  cp -f "$bin" "$slot.new"
  mv -f "$slot.new" "$slot"
  chmod +x "$slot"
  if [ -n "$lib" ]; then
    ln -sfn "$lib" "$dir/lib"
  else
    rm -f "$dir/lib"
  fi
}

# Turn `test/runner.lua` output (colors off) into BENCH lines.  A test is
# identified by its name, not by the `T<n>` id, because the ids shift when a
# test is skipped.  Short tests report on the RUN line itself, longer ones on
# the following `<elapsed> ms OK` line.
bench_suite_parse() {
  awk '
    function name(line) {
      sub(/[ \t]*[0-9]+\.[0-9]+ *ms.*$/, "", line)  # drop the spec own output
      sub(/^RUN[ \t]+/, "", line)
      sub(/[ \t]*:$/, "", line)
      sub(/^T[0-9]+ /, "", line)  # the id can shift, the name cannot
      return line
    }
    /^-------- Running tests from / {
      file = $0
      sub(/^-------- Running tests from /, "", file)
      sub(/.*\//, "", file)
      next
    }
    # Per-file total.  The suite summary at the end ("======== N tests from M
    # test files of X ran. (...)") is deliberately not matched: it starts with
    # "========" and would be a confusing second total.
    /^-------- [0-9]+ tests? from .*\([0-9.]+ ms total\)/ {
      total = $0
      sub(/^.*\(/, "", total)
      sub(/ ms total\).*$/, "", total)
      path = $0
      sub(/ \(.*$/, "", path)
      sub(/^.* from /, "", path)
      sub(/.*\//, "", path)
      printf "BENCH\t%s\t%.2f\n", path, total
      next
    }
    {
      if ($0 ~ /^RUN[ \t]/) {
        pending = name($0)
        have = 1
        # Short tests report their result on the RUN line itself; a spec may
        # also print a `... ms` value there, which must not be mistaken for the
        # elapsed time, so require the trailing status word.
        if ($0 !~ /[0-9]+\.[0-9][0-9] ms (OK|SKIP|FAIL|ERR)[ \t]*$/) next
        line = $0
      } else if (!have) {
        next
      } else {
        line = $0
      }
      if (match(line, /(SKIP|FAIL|ERR|OK)[ \t]*$/)) {
        status = substr(line, RSTART, RLENGTH)
        gsub(/[ \t]+$/, "", status)
        if (status == "OK") {
          done = line
          sub(/[ \t]*OK[ \t]*$/, "", done)
          match(done, /[0-9]+\.[0-9][0-9] ms$/)
          printf "BENCH\t%s::%s\t%.2f\n", file, pending, substr(done, RSTART, RLENGTH - 3)
        } else {
          printf "STATUS\t%s\t%s::%s\n", status, file, pending
        }
        have = 0
      }
    }'
}

# The project's own benchmark suite (test/benchmark), run through
# test/runner.lua the way `make benchmark` runs it, but with one process per
# spec file.  In a single process a same-binary control deviates by 10-20% on
# tests shorter than 200 ms; per file it stays within ~2%.  TEST_FILE selects a
# subset, as for `make benchmark`; a directory is expanded to its spec files.
bench_suite() {
  local bin=$1 out=$2 tmp=$3
  local xdg=$tmp/xdg
  local st=0 link spec path paths=()
  mkdir -p "$xdg" "$tmp/tmp"
  for link in runtime src test README.md; do
    ln -sfn "$root/$link" "$xdg/$link"
  done
  for path in ${TEST_FILE:-"$root"/test/benchmark/*_spec.lua}; do
    if [ -d "$path" ]; then
      for spec in "$path"/*_spec.lua; do paths+=("$spec"); done
    else
      paths+=("$path")
    fi
  done
  for spec in "${paths[@]}"; do
    ( cd "$xdg" && env -u XDG_DATA_DIRS -u NVIM -u TMUX \
        NVIM_PRG="$bin" NVIM_TEST=1 LC_ALL=en_US.UTF-8 TEST_COLORS=off \
        NVIM_LOG_FILE="$tmp/nvim.log" TMPDIR="$tmp/tmp" HISTFILE=/dev/null \
        TEST_TIMEOUT="${TEST_TIMEOUT:-1200}" SYSTEM_NAME="$(uname -s)" SHELL=sh \
        "$bin" -l "$root/test/runner.lua" -X"$xdg" -v --summary-file=- \
        --helper="$root/test/benchmark/preload.lua" --lpath="$build/?.lua" \
        "$spec" ) | bench_suite_parse >> "$out" || st=$?
  done
  if [ "$st" != 0 ]; then
    bench_tmp_keep=1
    echo "contrib/pgo.sh: the benchmark suite exited with status $st (see $tmp/nvim.log)" >&2
  fi
}

# Per-benchmark ratio variant/reference over the rounds: median and [Q1, Q3],
# so that both the effect and its noise are visible (< 1.0 is faster).
bench_ratios() {
  awk -F'\t' '
    function sort(a, n,   i, j, t) {
      for (i = 2; i <= n; i++) {
        t = a[i]; j = i - 1
        while (j >= 1 && a[j] > t) { a[j + 1] = a[j]; j-- }
        a[j + 1] = t
      }
    }
    function med(a, n) { return (n % 2) ? a[(n + 1) / 2] : (a[n / 2] + a[n / 2 + 1]) / 2 }
    function pct(a, n, p,   k) {
      k = int(p * n + 0.9999)
      if (k < 1) k = 1
      if (k > n) k = n
      return a[k]
    }
    FNR == NR { if ($1 == "BENCH") { an[$2]++; a[$2, an[$2]] = $3 + 0 } next }
    $1 == "BENCH" { bn[$2]++; b[$2, bn[$2]] = $3 + 0 }
    END {
      for (name in an) all[name] = 1
      for (name in bn) all[name] = 1
      for (name in all) if (length(name) > w) w = length(name)
      for (name in all) {
        if (!(name in an) || !(name in bn)) { printf "%-*s %7s\n", w, name, "n/a"; continue }
        m = (an[name] < bn[name]) ? an[name] : bn[name]
        for (j = 1; j <= m; j++) r[j] = (a[name, j] == 0) ? 0 : b[name, j] / a[name, j]
        sort(r, m)
        printf "%-*s %7.3f [%.3f, %.3f]\n", w, name, med(r, m), pct(r, m, 0.25), pct(r, m, 0.75)
      }
    }' "$1" "$2" | sort
}

# Same as bench_ratios, for `perf stat` counter files.
bench_counter_ratios() {
  awk -F, '
    function sort(a, n,   i, j, t) {
      for (i = 2; i <= n; i++) { t = a[i]; j = i - 1
        while (j >= 1 && a[j] > t) { a[j + 1] = a[j]; j-- } a[j + 1] = t }
    }
    function med(a, n) { return (n % 2) ? a[(n + 1) / 2] : (a[n / 2] + a[n / 2 + 1]) / 2 }
    function ev() { return $3 ~ /^(cycles|instructions|branches|branch-misses):u$/ }
    FNR == NR { if (ev() && $1 ~ /^[0-9]+$/) { an[$3]++; a[$3, an[$3]] = $1 + 0 } next }
    ev() && $1 ~ /^[0-9]+$/ { bn[$3]++; b[$3, bn[$3]] = $1 + 0 }
    END {
      for (e in an) {
        m = (an[e] < bn[e]) ? an[e] : bn[e]
        for (j = 1; j <= m; j++) r[j] = (a[e, j] == 0) ? 0 : b[e, j] / a[e, j]
        sort(r, m)
        printf "%-16s %7.3f\n", e, med(r, m)
      }
    }' "$1" "$2" | sort
}

# Absolute medians of one run file (microseconds for the micro-benchmarks,
# milliseconds for --suite).
bench_abs() {
  awk -F'\t' '
    function sort(a, n,   i, j, t) {
      for (i = 2; i <= n; i++) { t = a[i]; j = i - 1
        while (j >= 1 && a[j] > t) { a[j + 1] = a[j]; j-- } a[j + 1] = t }
    }
    function med(a, n) { return (n % 2) ? a[(n + 1) / 2] : (a[n / 2] + a[n / 2 + 1]) / 2 }
    $1 == "BENCH" { v[$2, ++n[$2]] = $3 + 0 }
    END {
      for (k in n) if (length(k) > w) w = length(k)
      for (k in n) {
        for (j = 1; j <= n[k]; j++) r[j] = v[k, j]
        sort(r, n[k])
        printf "%-*s %12.1f\n", w, k, med(r, n[k])
      }
    }' "$1" | sort
}

# Benchmark several binaries: one shared path per variant, a fresh shuffle per
# round, and the median of the per-round ratios with its IQR.  The reference
# binary is benchmarked twice by default, which shows the noise floor.  --perf
# adds hardware counters.
stage_bench() {
  local bins=("$@")
  [ "${#bins[@]}" -gt 0 ] || bins=("$build/bin/nvim")
  local reference="${bins[0]}"
  local labels=("${bins[@]}")
  local nb=${#bins[@]}
  local tmpdir slot unit='us'
  tmpdir=$(mktemp -d)
  slot=$tmpdir/slot/bin/nvim
  bench_tmp_keep=0

  local b
  for b in "${bins[@]}"; do
    [ -x "$b" ] || die "not an executable file: $b"
  done

  if [ "$bench_suite" = 1 ]; then
    unit='ms'
    [ -f "$build/test/cmakeconfig/paths.lua" ] || die \
      "bench --suite needs '$build/test/cmakeconfig/paths.lua' (build first, or pass --build-dir)"
    echo "note: bench --suite runs ${TEST_FILE:-test/benchmark}; each round takes" >&2
    echo "      minutes, so consider --rounds 1..3, or TEST_FILE=<one spec>." >&2
  fi

  # Same-binary control: benchmark the reference twice.  Its ratio is the
  # run-to-run noise floor on this machine (identical binary, identical path).
  if [ "$bench_control" = 1 ]; then
    bins=("${bins[0]}" "${bins[@]}")
    labels=("${labels[0]}" "[control] same binary as $(basename "$reference")" "${labels[@]:1}")
    nb=$((nb + 1))
  fi

  echo "benchmarking $nb binaries, $bench_rounds rounds, shuffled order, one shared path"
  local order i k r t
  for ((r = 1; r <= bench_rounds; r++)); do
    order=()
    for ((i = 0; i < nb; i++)); do order+=("$i"); done
    # Fisher-Yates shuffle (no dependency on shuf).
    for ((i = nb - 1; i > 0; i--)); do
      k=$((RANDOM % (i + 1)))
      t=${order[i]}
      order[i]=${order[k]}
      order[k]=$t
    done
    for i in "${order[@]}"; do
      bench_slot "${bins[i]}" "$slot"
      if [ "$bench_suite" = 1 ]; then
        bench_suite "$slot" "$tmpdir/run$i.txt" "$tmpdir"
      else
        bench_micro "$slot" "$tmpdir/run$i.txt"
      fi
    done
  done

  if grep -qs '^STATUS' "$tmpdir"/run*.txt; then
    echo "note: skipped or failed tests are not compared:" >&2
    awk -F'\t' '$1 == "STATUS" { print $2 " " $3 }' "$tmpdir"/run*.txt \
      | sort -u | sed 's/^/  /' >&2
  fi

  echo ""
  echo "absolute medians ($unit), reference: $reference"
  bench_abs "$tmpdir/run0.txt"
  for ((i = 1; i < nb; i++)); do
    echo ""
    echo "## ${labels[$i]}"
    echo "   ratio to reference, median [IQR] of $bench_rounds rounds (< 1.0 is faster)"
    bench_ratios "$tmpdir/run0.txt" "$tmpdir/run$i.txt"
  done

  if [ "$bench_perf" = 1 ]; then
    if ! command -v perf >/dev/null 2>&1; then
      echo "perf not found; skipping --perf" >&2
    else
      local runs=${PGO_PERF_RUNS:-5}
      local events=${PGO_PERF_EVENTS:-cycles:u,instructions:u,branches:u,branch-misses:u}
      [ "$bench_suite" = 0 ] \
        || echo "note: --perf uses the micro-benchmarks, not the suite" >&2
      for ((i = 0; i < nb; i++)); do
        bench_slot "${bins[i]}" "$slot"
        for ((r = 0; r < runs; r++)); do
          VIMRUNTIME="$root/runtime" perf stat -x, -e "$events" -- \
            "$slot" --clean -l "$root/contrib/pgo_bench.lua" \
            >/dev/null 2>>"$tmpdir/perf$i.txt"
        done
      done
      echo ""
      echo "## hardware counters, median of $runs runs (< 1.0 means fewer)"
      for ((i = 1; i < nb; i++)); do
        echo "# ${labels[$i]}"
        bench_counter_ratios "$tmpdir/perf0.txt" "$tmpdir/perf$i.txt"
      done
    fi
  fi

  if [ "$bench_tmp_keep" = 1 ]; then
    echo "kept $tmpdir (the benchmark suite reported failures)" >&2
  else
    rm -rf "$tmpdir"
  fi
}

case "$cmd" in
  all)
    stage_generate
    stage_train
    stage_use
    ;;
  generate) stage_generate ;;
  train) stage_train ;;
  use) stage_use ;;
  bench) stage_bench "${positional[@]}" ;;
  clean)
    wipe_build
    rm -rf "$depsdir"
    ;;
esac
