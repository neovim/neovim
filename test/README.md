Tests
=====

Tests are broadly divided into *unit tests* ([test/unit](https://github.com/neovim/neovim/tree/master/test/unit/)),
*functional tests* ([test/functional](https://github.com/neovim/neovim/tree/master/test/functional/)),
and *old tests* ([src/nvim/testdir/](https://github.com/neovim/neovim/tree/master/src/nvim/testdir/)).

- _Unit_ testing is achieved by compiling the tests as a shared library which is
  loaded and called by [LuaJit FFI](http://luajit.org/ext_ffi.html).
- _Functional_ tests are driven by RPC, so they do not require LuaJit (as
  opposed to Lua).

You can learn the [key concepts of Lua in 15 minutes](http://learnxinyminutes.com/docs/lua/).
Use any existing test as a template to start writing new tests.

Tests are run by `/cmake/RunTests.cmake` file, using `busted` (a Lua test-runner).
For some failures, `.nvimlog` (or `$NVIM_LOG_FILE`) may provide insight.

Depending on the presence of binaries (e.g., `xclip`) some tests will be
ignored. You must compile with libintl to prevent `E319: The command is not
available in this version` errors.


---

- [Running tests](#running-tests)
- [Writing tests](#writing-tests)
- [Lint](#lint)
- [Environment variables](#environment-variables)

---


Layout
======

- `/test/benchmark` : benchmarks
- `/test/functional` : functional tests
- `/test/unit` : unit tests
- `/test/config` : contains `*.in` files which are transformed into `*.lua`
  files using `configure_file` CMake command: this is for acessing CMake
  variables in lua tests.
- `/test/includes` : include-files for use by luajit `ffi.cdef` C definitions
  parser: normally used to make macros not accessible via this mechanism
  accessible the other way.
- `/test/*/preload.lua` : modules preloaded by busted `--helper` option
- `/test/**/helpers.lua` : common utility functions for test code
- `/test/*/**/*_spec.lua` : actual tests. Files that do not end with
  `_spec.lua` are libraries like `/test/**/helpers.lua`, except that they have
  some common topic.
- `/src/nvim/testdir` : old tests (from Vim)


Running tests
=============

Executing Tests
---------------

To run all tests (except "old" tests):

    make test

To run only _unit_ tests:

    make unittest

To run only _functional_ tests:

    make functionaltest


Legacy tests
------------

To run all legacy Vim tests:

    make oldtest

To run a *single* legacy test set `TEST_FILE`, for example:

    TEST_FILE=test_syntax.res make oldtest

- The `.res` extension (instead of `.vim`) is required.
- Specify only the test file name, not the full path.


Debugging tests
---------------

You can set `$GDB` to [run tests under gdbserver](https://github.com/neovim/neovim/pull/1527).
And if `$VALGRIND` is set it will pass `--vgdb=yes` to valgrind instead of
starting gdbserver directly.


Filtering Tests
---------------

### Filter by name

Another filter method is by setting a pattern of test name to `TEST_FILTER`.

``` lua
it('foo api',function()
  ...
end)
it('bar api',function()
  ...
end)
```

To run only test with filter name:

    TEST_TAG='foo.*api' make functionaltest

### Filter by file

To run a *specific* unit test:

    TEST_FILE=test/unit/foo.lua make unittest

To run a *specific* functional test:

    TEST_FILE=test/functional/foo.lua make functionaltest

To *repeat* a test:

    .deps/usr/bin/busted --lpath='build/?.lua' --filter 'foo' --repeat 1000 test/functional/ui/foo_spec.lua

### Filter by tag

Tests can be "tagged" by adding `#` before a token in the test description.

``` lua
it('#foo bar baz', function()
  ...
end)
it('#foo another test', function()
  ...
end)
```

To run only the tagged tests:

    TEST_TAG=foo make functionaltest

**NOTE:**

* `TEST_FILE` is not a pattern string like `TEST_TAG` or `TEST_FILTER`. The
  given value to `TEST_FILE` must be a path to an existing file.
* Both `TEST_TAG` and `TEST_FILTER` filter tests by the string descriptions
  found in `it()` and `describe()`.


Writing tests
=============

Guidelines
----------

- Consider [BDD](http://en.wikipedia.org/wiki/Behavior-driven_development)
  guidelines for organization and readability of tests. Describe what you're
  testing (and the environment if applicable) and create specs that assert its
  behavior.
- For testing static functions or functions that have side effects visible only
  in module-global variables, create accessors for the modified variables. For
  example, say you are testing a function in misc1.c that modifies a static
  variable, create a file `test/c-helpers/misc1.c` and add a function that
  retrieves the value after the function call. Files under `test/c-helpers` will
  only be compiled when building the test shared library.
- Luajit needs to know about type and constant declarations used in function
  prototypes. The
  [helpers.lua](https://github.com/neovim/neovim/blob/master/test/unit/helpers.lua)
  file automatically parses `types.h`, so types used in the tested functions
  must be moved to it to avoid having to rewrite the declarations in the test
  files (even though this is how it's currently done currently in the misc1/fs
  modules, but contributors are encouraged to refactor the declarations).
  - Macro constants must be rewritten as enums so they can be "visible" to the
    tests automatically.
- Busted supports various "output providers". The
  **[gtest](https://github.com/Olivine-Labs/busted/pull/394) output provider**
  shows verbose details that can be useful to diagnose hung tests. Either modify
  the Makefile or compile with `make
  CMAKE_EXTRA_FLAGS=-DBUSTED_OUTPUT_TYPE=gtest` to enable it.
- **Use busted's `pending()` feature** to skip tests
  ([example](https://github.com/neovim/neovim/commit/5c1dc0fbe7388528875aff9d7b5055ad718014de#diff-bf80b24c724b0004e8418102f68b0679R18)).
  Do not silently skip the test with `if-else`. If a functional test depends on
  some external factor (e.g. the existence of `md5sum` on `$PATH`), *and* you
  can't mock or fake the dependency, then skip the test via `pending()` if the
  external factor is missing. This ensures that the *total* test-count
  (success + fail + error + pending) is the same in all environments.
    - *Note:* `pending()` is ignored if it is missing an argument _unless_ it is
      [contained in an `it()` block](https://github.com/neovim/neovim/blob/d21690a66e7eb5ebef18046c7a79ef898966d786/test/functional/ex_cmds/grep_spec.lua#L11).
      Provide empty function argument if the `pending()` call is outside of `it()`
      ([example](https://github.com/neovim/neovim/commit/5c1dc0fbe7388528875aff9d7b5055ad718014de#diff-bf80b24c724b0004e8418102f68b0679R18)).
- Use `make testlint` for using the shipped luacheck program ([supported by syntastic](https://github.com/scrooloose/syntastic/blob/d6b96c079be137c83009827b543a83aa113cc011/doc/syntastic-checkers.txt#L3546))
  to lint all tests.
- Really long `source([=[...]=])` blocks may break syntax highlighting. Try
  `:syntax sync fromstart` to fix it.

Where tests go
--------------

Tests in `/test/unit` and `/test/functional` are divided into groups
by the semantic component they are testing.

- _Unit tests_
  ([test/unit](https://github.com/neovim/neovim/tree/master/test/unit)) should
  match 1-to-1 with the structure of `src/nvim/`, because they are testing
  functions directly. E.g. unit-tests for `src/nvim/undo.c` should live in
  `test/unit/undo_spec.lua`.
- _Functional tests_
  ([test/functional](https://github.com/neovim/neovim/tree/master/test/functional))
  are higher-level (plugins and user input) than unit tests; they are organized
  by concept. 
    - Try to find an existing `test/functional/*/*_spec.lua` group that makes
      sense, before creating a new one.


Lint
====

`make lint` (and `make testlint`) runs [luacheck](https://github.com/mpeterv/luacheck)
on the test code.

If a luacheck warning must be ignored, specify the warning code. Example:

    -- luacheck: ignore 621

http://luacheck.readthedocs.io/en/stable/warnings.html

Ignore the smallest applicable scope (e.g. inside a function, not at the top of
the file).


Environment variables
=====================

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

`NVIM_TEST_TRACE_ON_ERROR` (U) (1): makes unit tests yield trace on error in 
addition to regular error message.

`NVIM_TEST_MAXTRACE` (U) (N): specifies maximum number of trace lines to keep. 
Default is 1024.
