# Runs plugin tests with the Nvim test harness, see ":help dev-test-plugin".
#
# Copy this file to your plugin (as "Makefile", or "include" it from yours), then:
#   make test
#   make test TEST_FILE=test/foo_spec.lua TEST_FILTER=foo
#   make test NVIM_PRG=/path/to/bin/nvim
#
#  TODO:
#  - https://github.com/neovim/neovim/issues/34592

NVIM_PRG ?= nvim
TEST_FILE ?= test
TEST_FILTER ?=
# Git ref of the harness modules: should match $(NVIM_PRG).
# Cached in .deps/ ("rm -rf .deps" to update).
NVIM_TEST_VERSION ?= master
NVIM_TEST_URL ?= https://raw.githubusercontent.com/neovim/neovim/$(NVIM_TEST_VERSION)/test
TEST_DEPS := .deps/neovim/$(NVIM_TEST_VERSION)

# Downloads to a temp dir, renamed after all downloads succeed.
$(TEST_DEPS):
	rm -rf "$@.tmp"
	curl --parallel --fail --location --silent --show-error --create-dirs \
		--output "$@.tmp/test/#1" "$(NVIM_TEST_URL)/{\
	assert.lua,\
	client/rpc_stream.lua,\
	client/session.lua,\
	client/uv_stream.lua,\
	functional/preload.lua,\
	functional/testnvim.lua,\
	functional/testnvim/exec_lua.lua,\
	functional/ui/screen.lua,\
	harness.lua,\
	reporter.lua,\
	runner.lua,\
	testutil.lua}"
	mv "$@.tmp" "$@"

# LUA_PATH: `exec_lua` requires test modules in the Nvim under test.
.PHONY: test
test: $(TEST_DEPS)
	NVIM_LOG_FILE="$(abspath .deps/nvim.log)" LUA_PATH="$(abspath $(TEST_DEPS))/?.lua;;" \
		"$(NVIM_PRG)" --clean -l "$(TEST_DEPS)/test/runner.lua" -X"$(abspath .deps/xdg)" -v \
		--helper="$(TEST_DEPS)/test/functional/preload.lua" \
		$(if $(TEST_FILTER),--filter="$(TEST_FILTER)") "$(TEST_FILE)"
