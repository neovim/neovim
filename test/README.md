Tests
=====

Tests are broadly divided into *unit tests* ([test/unit](https://github.com/neovim/neovim/tree/master/test/unit/)),
*functional tests* ([test/functional](https://github.com/neovim/neovim/tree/master/test/functional/)),
and *old tests* ([test/old/testdir/](https://github.com/neovim/neovim/tree/master/test/old/testdir/)).

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
- [Configuration](#configuration)

---


Layout
======

- `/test/benchmark` : benchmarks
- `/test/functional` : functional tests
- `/test/unit` : unit tests
- `/test/old/testdir` : old tests (from Vim)
- `/test/config` : contains `*.in` files which are transformed into `*.lua`
  files using `configure_file` CMake command: this is for accessing CMake
  variables in lua tests.
- `/test/includes` : include-files for use by luajit `ffi.cdef` C definitions
  parser: normally used to make macros not accessible via this mechanism
  accessible the other way.
- `/test/*/preload.lua` : modules preloaded by busted `--helper` option
- `/test/**/testutil.lua` : common utility functions in the context of the test
  runner
- `/test/**/testnvim.lua` : common utility functions in the context of the
  test session (RPC channel to the Nvim child process created by clear() for each test)
- `/test/*/**/*_spec.lua` : actual tests. Files that do not end with
  `_spec.lua` are libraries like `/test/**/testutil.lua`, except that they have
  some common topic.


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

To run a *single* legacy test file you can use either:

    make oldtest TEST_FILE=test_syntax.vim

or:

    make test/old/testdir/test_syntax.vim

- Specify only the test file name, not the full path.


Debugging tests
---------------

- Each test gets a test id which looks like "T123". This also appears in the
  log file. Child processes spawned from a test appear in the logs with the
  *parent* name followed by "/c". Example:
  ```
    DBG 2022-06-15T18:37:45.226 T57.58016.0   UI: flush
    DBG 2022-06-15T18:37:45.226 T57.58016.0   inbuf_poll:442: blocking... events_enabled=0 events_pending=0
    DBG 2022-06-15T18:37:45.227 T57.58016.0/c UI: stop
    INF 2022-06-15T18:37:45.227 T57.58016.0/c os_exit:595: Nvim exit: 0
    DBG 2022-06-15T18:37:45.229 T57.58016.0   read_cb:118: closing Stream (0x7fd5d700ea18): EOF (end of file)
    INF 2022-06-15T18:37:45.229 T57.58016.0   on_proc_exit:400: exited: pid=58017 status=0 stoptime=0
  ```
- You can set `$GDB` to [run functional tests under gdbserver](https://github.com/neovim/neovim/pull/1527):

  ```sh
  GDB=1 TEST_FILE=test/functional/api/buffer_spec.lua TEST_FILTER='nvim_buf_set_text works$' make functionaltest
  ```

  Read more about [filtering tests](#filtering-tests).

  Then, in another terminal:

  ```sh
  gdb -ex 'target remote localhost:7777' build/bin/nvim
  ```

  If `$VALGRIND` is also set it will pass `--vgdb=yes` to valgrind instead of
  starting gdbserver directly.

  See `nvim_argv` in https://github.com/neovim/neovim/blob/master/test/functional/testnvim.lua.

- Hanging tests can happen due to unexpected "press-enter" prompts. The
  default screen width is 50 columns. Commands that try to print lines longer
  than 50 columns in the command-line, e.g. `:edit very...long...path`, will
  trigger the prompt. Try using a shorter path, or `:silent edit`.
- If you can't figure out what is going on, try to visualize the screen. Put
  this at the beginning of your test:
  ```lua
  local Screen = require('test.functional.ui.screen')
  local screen = Screen.new()
  screen:attach()
  ```
  Then put `screen:snapshot_util()` anywhere in your test. See the comments in
  `test/functional/ui/screen.lua` for more info.

Filtering Tests
---------------

### Filter by name

Tests can be filtered by setting a pattern of test name to `TEST_FILTER` or `TEST_FILTER_OUT`.

``` lua
it('foo api',function()
  ...
end)
it('bar api',function()
  ...
end)
```

To run only test with filter name:

    TEST_FILTER='foo.*api' make functionaltest

To run all tests except ones matching a filter:

    TEST_FILTER_OUT='foo.*api' make functionaltest

### Filter by file

To run a *specific* unit test:

    TEST_FILE=test/unit/foo.lua make unittest

or

    cmake -E env "TEST_FILE=test/unit/foo.lua" cmake --build build --target unittest

To run a *specific* functional test:

    TEST_FILE=test/functional/foo.lua make functionaltest

or

    cmake -E env "TEST_FILE=test/functional/foo.lua" cmake --build build --target functionaltest

To *repeat* a test:

    BUSTED_ARGS="--repeat=100 --no-keep-going" TEST_FILE=test/functional/foo_spec.lua make functionaltest

or

    cmake -E env "TEST_FILE=test/functional/foo_spec.lua" cmake -E env BUSTED_ARGS="--repeat=100 --no-keep-going" cmake --build build --target functionaltest

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

- Luajit needs to know about type and constant declarations used in function
  prototypes. The
  [testutil.lua](https://github.com/neovim/neovim/blob/master/test/unit/testutil.lua)
  file automatically parses `types.h`, so types used in the tested functions
  could be moved to it to avoid having to rewrite the declarations in the test
  files.
  - `#define` constants must be rewritten `const` or `enum` so they can be
    "visible" to the tests.
- Use **pending()** to skip tests
  ([example](https://github.com/neovim/neovim/commit/5c1dc0fbe7388528875aff9d7b5055ad718014de#diff-bf80b24c724b0004e8418102f68b0679R18)).
  Do not silently skip the test with `if-else`. If a functional test depends on
  some external factor (e.g. the existence of `md5sum` on `$PATH`), *and* you
  can't mock or fake the dependency, then skip the test via `pending()` if the
  external factor is missing. This ensures that the *total* test-count
  (success + fail + error + pending) is the same in all environments.
    - *Note:* `pending()` is ignored if it is missing an argument, unless it is
      [contained in an `it()` block](https://github.com/neovim/neovim/blob/d21690a66e7eb5ebef18046c7a79ef898966d786/test/functional/ex_cmds/grep_spec.lua#L11).
      Provide empty function argument if the `pending()` call is outside `it()`
      ([example](https://github.com/neovim/neovim/commit/5c1dc0fbe7388528875aff9d7b5055ad718014de#diff-bf80b24c724b0004e8418102f68b0679R18)).
- Really long `source([=[...]=])` blocks may break Vim's Lua syntax
  highlighting. Try `:syntax sync fromstart` to fix it.

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

`make lint` (and `make lualint`) runs [luacheck](https://github.com/mpeterv/luacheck)
on the test code.

If a luacheck warning must be ignored, specify the warning code. Example:

    -- luacheck: ignore 621

http://luacheck.readthedocs.io/en/stable/warnings.html

Ignore the smallest applicable scope (e.g. inside a function, not at the top of
the file).


Configuration
=============

Test behaviour is affected by environment variables. Currently supported
(Functional, Unit, Benchmarks) (when Defined; when set to _1_; when defined,
treated as Integer; when defined, treated as String; when defined, treated as
Number; !must be defined to function properly):

- `BUSTED_ARGS` (F) (U): arguments forwarded to `busted`.

- `CC` (U) (S): specifies which C compiler to use to preprocess files.
  Currently only compilers with gcc-compatible arguments are supported.

- `GDB` (F) (D): makes nvim instances to be run under `gdbserver`. It will be
  accessible on `localhost:7777`: use `gdb build/bin/nvim`, type `target remote
  :7777` inside.

- `GDBSERVER_PORT` (F) (I): overrides port used for `GDB`.

- `LOG_DIR` (FU) (S!): specifies where to seek for valgrind and ASAN log files.

- `VALGRIND` (F) (D): makes nvim instances to be run under `valgrind`. Log
  files are named `valgrind-%p.log` in this case. Note that non-empty valgrind
  log may fail tests. Valgrind arguments may be seen in
  `/test/functional/testnvim.lua`. May be used in conjunction with `GDB`.

- `VALGRIND_LOG` (F) (S): overrides valgrind log file name used for `VALGRIND`.

- `TEST_COLORS` (F) (U) (D): enable pretty colors in test runner. Set to true by default.

- `TEST_SKIP_FRAGILE` (F) (D): makes test suite skip some fragile tests.

- `TEST_TIMEOUT` (FU) (I): specifies maximum time, in seconds, before the test
  suite run is killed

- `NVIM_LUA_NOTRACK` (F) (D): disable reference counting of Lua objects

- `NVIM_PRG` (F) (S): path to Nvim executable (default: `build/bin/nvim`).

- `NVIM_TEST_MAIN_CDEFS` (U) (1): makes `ffi.cdef` run in main process. This
  raises a possibility of bugs due to conflicts in header definitions, despite
  the counters, but greatly speeds up unit tests by not requiring `ffi.cdef` to
  do parsing of big strings with C definitions.

- `NVIM_TEST_PRINT_I` (U) (1): makes `cimport` print preprocessed, but not yet
  filtered through `formatc` headers. Used to debug `formatc`. Printing is done
  with the line numbers.

- `NVIM_TEST_PRINT_CDEF` (U) (1): makes `cimport` print final lines which will
  be then passed to `ffi.cdef`. Used to debug errors `ffi.cdef` happens to
  throw sometimes.

- `NVIM_TEST_PRINT_SYSCALLS` (U) (1): makes it print to stderr when syscall
  wrappers are called and what they returned. Used to debug code which makes
  unit tests be executed in separate processes.

- `NVIM_TEST_RUN_FAILING_TESTS` (U) (1): makes `itp` run tests which are known
  to fail (marked by setting third argument to `true`).

- `NVIM_TEST_CORE_*` (FU) (S): a set of environment variables which specify
  where to search for core files. Are supposed to be defined all at once.

- `NVIM_TEST_CORE_GLOB_DIRECTORY` (FU) (S): directory where core files are
  located. May be `.`. This directory is then recursively searched for core
  files. Note: this variable must be defined for any of the following to have
  any effect.

- `NVIM_TEST_CORE_GLOB_RE` (FU) (S): regular expression which must be matched
  by core files. E.g. `/core[^/]*$`. May be absent, in which case any file is
  considered to be matched.

- `NVIM_TEST_CORE_EXC_RE` (FU) (S): regular expression which excludes certain
  directories from searching for core files inside. E.g. use `^/%.deps$` to not
  search inside `/.deps`. If absent, nothing is excluded.

- `NVIM_TEST_CORE_DB_CMD` (FU) (S): command to get backtrace out of the
  debugger. E.g. `gdb -n -batch -ex "thread apply all bt full"
  "$_NVIM_TEST_APP" -c "$_NVIM_TEST_CORE"`. Defaults to the example command.
  This debug command may use environment variables `_NVIM_TEST_APP` (path to
  application which is being debugged: normally either nvim or luajit) and
  `_NVIM_TEST_CORE` (core file to get backtrace from).

- `NVIM_TEST_CORE_RANDOM_SKIP` (FU) (D): makes `check_cores` not check cores
  after approximately 90% of the tests. Should be used when finding cores is
  too hard for some reason. Normally (on OS X or when
  `NVIM_TEST_CORE_GLOB_DIRECTORY` is defined and this variable is not) cores
  are checked for after each test.

- `NVIM_TEST_RUN_TESTTEST` (U) (1): allows running
  `test/unit/testtest_spec.lua` used to check how testing infrastructure works.

- `NVIM_TEST_TRACE_LEVEL` (U) (N): specifies unit tests tracing level:
  - `0` disables tracing (the fastest, but you get no data if tests crash and
    there no core dump was generated),
  - `1` leaves only C function calls and returns in the trace (faster than
    recording everything),
  - `2` records all function calls, returns and executed Lua source lines.

- `NVIM_TEST_TRACE_ON_ERROR` (U) (1): makes unit tests yield trace on error in
  addition to regular error message.

- `NVIM_TEST_MAXTRACE` (U) (N): specifies maximum number of trace lines to
  keep. Default is 1024.
