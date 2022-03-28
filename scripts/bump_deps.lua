-- Usage:
--    # bump to version
--    nvim -es +"lua require('scripts.bump_deps').version(dependency, version_tag)"
--
--    # bump to commit
--    nvim -es +"lua require('scripts.bump_deps').commit(dependency, commit_hash)"
--
--    # bump to HEAD
--    nvim -es +"lua require('scripts.bump_deps').head(dependency)"

local M = {}

local _trace = false

-- TODO: verify run from root

-- Print message
local function p(s)
	vim.cmd("set verbose=1")
	vim.api.nvim_echo({ { s, "" } }, false, {})
	vim.cmd("set verbose=0")
end

local function die()
	p("")
	vim.cmd("cquit 1")
end

-- Executes and returns the output of `cmd`, or nil on failure.
--
-- Prints `cmd` if `trace` is enabled.
local function run(cmd, or_die)
	if _trace then
		p("run: " .. vim.inspect(cmd))
	end
	local rv = vim.trim(vim.fn.system(cmd)) or ""
	if vim.v.shell_error ~= 0 then
		if or_die then
			p(rv)
			die()
		end
		return nil
	end
	return rv
end

local function get_dependency(dependency_name)
	local dependency_table = {
		["LuaJIT"] = {
			repo = "LuaJIT/LuaJIT",
			symbol = "LUAJIT",
		},
		["libuv"] = {
			repo = "libuv/libuv",
			symbol = "LIBUV",
		},
		["Luv"] = {
			repo = "luvit/luv",
			symbol = "LUV",
		},
		["tree-sitter"] = {
			repo = "tree-sitter/tree-sitter",
			symbol = "TREESITTER",
		},
	}
	local dependency = dependency_table[dependency_name]
	if dependency == nil then
		p("Not a dependency: " .. dependency_name)
		die()
	end
	return dependency
end

local nvim_src_dir = "."
local temp_dir = nvim_src_dir .. "/tmp"
run({ "mkdir", "-p", temp_dir })
local gh_res_path = temp_dir .. "/gh_res.json"

local function rm_file_if_present(path_to_file)
	run({ "rm", "-f", path_to_file }, true)
end

local function dl_gh_ref_info(repo, ref)
	rm_file_if_present(gh_res_path)
	local ref_status_code = run({
		"curl",
		"-s",
		"-H",
		"'Accept: application/vnd.github.v3+json'",
		"-w",
		"'%{http_code}'",
		"https://api.github.com/repos/" .. repo .. "/commits/" .. ref,
		"-o",
		gh_res_path,
	}, true)
	if ref_status_code ~= "'200'" then
		p("Not a valid ref: " .. ref)
		die()
	end
end

local function get_archive_info(repo, ref)
	local archive_name = ref .. ".tar.gz"
	local archive_path = temp_dir .. "/" .. archive_name
	local archive_url = "https://github.com/" .. repo .. "/archive/" .. archive_name

	rm_file_if_present(archive_path)
	run({ "curl", "-sL", archive_url, "-o", archive_path }, true)

	local archive_sha = run({ "sha256sum", archive_path }, true):gmatch("%w+")()
	return { url = archive_url, sha = archive_sha }
end

local function write_cmakelists_line(symbol, kind, value, comment)
	run({
		"sed",
		"-i",
		"-e",
		"s/set("
			.. symbol
			.. "_"
			.. kind
			.. ".*$"
			.. "/set("
			.. symbol
			.. "_"
			.. kind
			.. " "
			.. value
			.. ")"
			.. comment
			.. "/",
		nvim_src_dir .. "/" .. "third-party/CMakeLists.txt",
	}, true)
end

local function update_cmakelists(dependency, archive, comment)
	p("Updating " .. dependency.symbol .. " to " .. archive.url .. "\n")
	write_cmakelists_line(dependency.symbol, "URL", archive.url:gsub("/", "\\/"), " # " .. comment)
	write_cmakelists_line(dependency.symbol, "SHA256", archive.sha, "")
end

function M.commit(dependency_name, commit)
	local dependency = get_dependency(dependency_name)
	dl_gh_ref_info(dependency.repo, commit)
	local commit_sha = run({ "jq", "-r", ".sha", gh_res_path }, true)
	if commit_sha ~= commit then
		p("Not a commit: " .. commit .. ". Did you mean version?")
		die()
	end
	local archive = get_archive_info(dependency.repo, commit)
	update_cmakelists(dependency, archive, "commit: " .. commit)
end

function M.version(dependency_name, version)
	local dependency = get_dependency(dependency_name)
	dl_gh_ref_info(dependency.repo, version)
	local commit_sha = run({ "jq", "-r", ".sha", gh_res_path }, true)
	if commit_sha == version then
		p("Not a version: " .. version .. ". Did you mean commit?")
		die()
	end
	local archive = get_archive_info(dependency.repo, version)
	update_cmakelists(dependency, archive, "version: " .. version)
end

function M.head(dependency_name)
	local dependency = get_dependency(dependency_name)
	dl_gh_ref_info(dependency.repo, "HEAD")
	local commit_sha = run({ "jq", "-r", ".sha", gh_res_path }, true)
	local archive = get_archive_info(dependency.repo, commit_sha)
	update_cmakelists(dependency, archive, "HEAD: " .. commit_sha)
end

-- function M.main(opt)
-- 	_trace = not opt or not not opt.trace
-- end

return M
