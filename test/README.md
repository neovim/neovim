# Tests

Tests are run by `/cmake/RunTests.cmake` file, using busted.

For some failures, `.nvimlog` (or `$NVIM_LOG_FILE`) may provide insight.

## Directory structure

Directories with tests: `/test/benchmark` for benchmarks, `/test/functional` for 
functional tests, `/test/unit` for unit tests. `/test/config` contains `*.in` 
files (currently a single one) which are transformed into `*.lua` files using 
`configure_file` CMake command: this is for acessing CMake variables in lua 
tests. `/test/includes` contains include files for use by luajit `ffi.cdef` 
C definitions parser: normally used to make macros not accessible via this 
mechanism accessible the other way.

Files `/test/*/preload.lua` contain modules which will be preloaded by busted, 
via `--helper` option. `/test/**/helpers.lua` contain various “library” 
functions, (intended to be) used by a number of tests and not just a single one.

`/test/*/**/*_spec.lua` are files containing actual tests. Files that do not end 
with a `_spec.lua` are libraries like `/test/**/helpers.lua`, except that they 
have some common topic.

Tests inside `/test/unit` and `/test/functional` are normally divided into 
groups by the semantic component they are testing.

## Environment variables

Test behaviour is affected by environment variables. Currently supported 
(Functional, Unit, Benchmarks) (when Defined; when set to _1_; when defined, 
treated as Integer; when defined, treated as String; when defined, treated as 
Number; !must be defined to function properly):

`GDB` (F) (D): makes nvim instances to be run under `gdbserver`. It will be 
accessible on `localhost:7777`: use `gdb build/bin/nvim`, type `target remote 
:7777` inside.

`GDBSERVER_PORT` (F) (I): overrides port used for `GDB`.

`VALGRIND` (F) (D): makes nvim instances to be run under `valgrind`. Log files 
are named `valgrind-%p.log` in this case. Note that non-empty valgrind log may 
fail tests. Valgrind arguments may be seen in `/test/functional/helpers.lua`. 
May be used in conjunction with `GDB`.

`VALGRIND_LOG` (F) (S): overrides valgrind log file name used for `VALGRIND`.

`TEST_SKIP_FRAGILE` (F) (D): makes test suite skip some fragile tests.

`NVIM_PROG`, `NVIM_PRG` (F) (S): override path to Neovim executable (default to 
`build/bin/nvim`).

`CC` (U) (S): specifies which C compiler to use to preprocess files. Currently 
only compilers with gcc-compatible arguments are supported.

`NVIM_TEST_MAIN_CDEFS` (U) (1): makes `ffi.cdef` run in main process. This 
raises a possibility of bugs due to conflicts in header definitions, despite the 
counters, but greatly speeds up unit tests by not requiring `ffi.cdef` to do 
parsing of big strings with C definitions.

`NVIM_TEST_PRINT_I` (U) (1): makes `cimport` print preprocessed, but not yet 
filtered through `formatc` headers. Used to debug `formatc`. Printing is done 
with the line numbers.

`NVIM_TEST_PRINT_CDEF` (U) (1): makes `cimport` print final lines which will be 
then passed to `ffi.cdef`. Used to debug errors `ffi.cdef` happens to throw 
sometimes.

`NVIM_TEST_PRINT_SYSCALLS` (U) (1): makes it print to stderr when syscall 
wrappers are called and what they returned. Used to debug code which makes unit 
tests be executed in separate processes.

`NVIM_TEST_RUN_FAILING_TESTS` (U) (1): makes `itp` run tests which are known to 
fail (marked by setting third argument to `true`).

`LOG_DIR` (FU) (S!): specifies where to seek for valgrind and ASAN log files.

`NVIM_TEST_CORE_*` (FU) (S): a set of environment variables which specify where 
to search for core files. Are supposed to be defined all at once.

`NVIM_TEST_CORE_GLOB_DIRECTORY` (FU) (S): directory where core files are 
located. May be `.`. This directory is then recursively searched for core files. 
Note: this variable must be defined for any of the following to have any effect.

`NVIM_TEST_CORE_GLOB_RE` (FU) (S): regular expression which must be matched by 
core files. E.g. `/core[^/]*$`. May be absent, in which case any file is 
considered to be matched.

`NVIM_TEST_CORE_EXC_RE` (FU) (S): regular expression which excludes certain 
directories from searching for core files inside. E.g. use `^/%.deps$` to not 
search inside `/.deps`. If absent, nothing is excluded.

`NVIM_TEST_CORE_DB_CMD` (FU) (S): command to get backtrace out of the debugger. 
E.g. `gdb -n -batch -ex "thread apply all bt full" "$_NVIM_TEST_APP" -c 
"$_NVIM_TEST_CORE"`. Defaults to the example command. This debug command may use 
environment variables `_NVIM_TEST_APP` (path to application which is being 
debugged: normally either nvim or luajit) and `_NVIM_TEST_CORE` (core file to 
get backtrace from).

`NVIM_TEST_CORE_RANDOM_SKIP` (FU) (D): makes `check_cores` not check cores after 
approximately 90% of the tests. Should be used when finding cores is too hard 
for some reason. Normally (on OS X or when `NVIM_TEST_CORE_GLOB_DIRECTORY` is 
defined and this variable is not) cores are checked for after each test.

`NVIM_TEST_RUN_TESTTEST` (U) (1): allows running `test/unit/testtest_spec.lua` 
used to check how testing infrastructure works.

`NVIM_TEST_TRACE_LEVEL` (U) (N): specifies unit tests tracing level: `0` 
disables tracing (the fastest, but you get no data if tests crash and there was 
no core dump generated), `1` or empty/undefined leaves only C function cals and 
returns in the trace (faster then recording everything), `2` records all 
function calls, returns and lua source lines exuecuted.
