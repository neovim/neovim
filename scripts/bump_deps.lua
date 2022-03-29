-- Usage:
--    # bump to version
--    nvim -es +"lua require('scripts.bump_deps').version(dependency, version_tag)"
--
--    # bump to commit
--    nvim -es +"lua require('scripts.bump_deps').commit(dependency, commit_hash)"
--
--    # bump to HEAD
--    nvim -es +"lua require('scripts.bump_deps').head(dependency)"
--
--    # submit PR
--    nvim -es +"lua require('scripts.bump_deps').submit_pr()"

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
local function run(cmd, die_msg)
	if _trace then
		p("run: " .. vim.inspect(cmd))
	end
	local rv = vim.trim(vim.fn.system(cmd)) or ""
	if vim.v.shell_error ~= 0 then
		if die_msg ~= nil then
			p(rv)
			p(die_msg)
			die()
		end
		return nil
	end
	return rv
end

local function check_executable(cmd)
	local cmd_path = run({ "command", "-v", cmd }, nil)
	if cmd_path == nil then
		return false
	end
	local rv = run({ "test", "-x", cmd_path }, nil)
	return rv ~= nil
end

local function require_executable(cmd)
	local cmd_path = run({ "command", "-v", cmd }, cmd .. " not found!")
	run({ "test", "-x", cmd_path }, cmd .. " is not executable")
end

local function rm_file_if_present(path_to_file)
	run({ "rm", "-f", path_to_file }, true)
end

local nvim_src_dir = vim.fn.getcwd()
local temp_dir = nvim_src_dir .. "/tmp"
run({ "mkdir", "-p", temp_dir }, nil)
local gh_res_path = temp_dir .. "/gh_res.json"

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

local function dl_gh_ref_info(repo, ref)
	require_executable("curl")
	require_executable("jq")

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
	}, "Failed to fetch commit details from GitHub")
	if ref_status_code ~= "'200'" then
		p("Not a valid ref: " .. ref)
		die()
	end
end

local function get_archive_info(repo, ref)
	require_executable("curl")

	local archive_name = ref .. ".tar.gz"
	local archive_path = temp_dir .. "/" .. archive_name
	local archive_url = "https://github.com/" .. repo .. "/archive/" .. archive_name

	rm_file_if_present(archive_path)
	run({ "curl", "-sL", archive_url, "-o", archive_path }, "Failed to download archive from GitHub")

	local archive_sha = run({ "sha256sum", archive_path }, true):gmatch("%w+")()
	return { url = archive_url, sha = archive_sha }
end

local function write_cmakelists_line(symbol, kind, value, comment)
	require_executable("sed")

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
	local changed_file = nvim_src_dir .. "/" .. "third-party/CMakeLists.txt"
	run(
		{ "git", "commit", changed_file, "-m", "bump_deps: " .. dependency.symbol .. " to " .. comment },
		"git failed to commit"
	)
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

local function gh_pr(pr_title, pr_body)
	run({
		"gh",
		"pr",
		"create",
		"--title",
		pr_title,
		"--body",
		pr_body,
	}, "Failed to create PR")
end

local function git_hub_pr(pr_title, pr_body)
	local pr_message = pr_title .. "\n\n" .. pr_body .. "\n"
	run({
		"git",
		"hub",
		"pull",
		"new",
		"-m",
		pr_message,
	}, "Failed to create PR")
end

local function find_git_remote(fork)
	local remotes = run({ "git", "remote", "-v" }, "")
	local git_remote = ""
	for remote in remotes:gmatch("[^\r\n]+") do
		local words = {}
		for word in remote:gmatch("%w+") do
			table.insert(words, word)
		end
		local match = words[1]:match("/github.com[:/]neovim/neovim/")
		if fork == "fork" then
			match = not match
		end
		if match and words[3] == "(fetch)" then
			git_remote = words[0]
			break
		end
	end
	if git_remote == "" then
		git_remote = "origin"
	end
	return git_remote
end

local function create_pr(pr_title, pr_body)
	require_executable("git")

	local push_first = true
	local submit_fn

	if check_executable("gh") then
		submit_fn = gh_pr
	elseif check_executable("git_hub") then
		push_first = false
		submit_fn = git_hub_pr
	else
		p("Both gh and git_hub are not executable")
		die()
	end

	local branch_prefix = "bump_deps_"
	local checked_out_branch = run({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, "")
	if not checked_out_branch:match("^" .. branch_prefix) then
		p("Current branch '" .. checked_out_branch .. "' doesn't seem to start with " .. branch_prefix)
		die()
	end

	if push_first then
		local push_remote = run({ "git", "config", "--get", "branch." .. checked_out_branch .. ".pushRemote" }, nil)
		if push_remote == nil then
			push_remote = run({ "git", "config", "--get", "remote.pushDefault" }, nil)
			if push_remote == nil then
				push_remote = run({ "git", "config", "--get", "branch." .. checked_out_branch .. ".remote" }, nil)
				if push_remote == nil or push_remote == find_git_remote(nil) then
					push_remote = find_git_remote("fork")
				end
			end
		end

		p("Pushing to " .. push_remote .. "/" .. checked_out_branch)
		run({ "git", "push", push_remote, checked_out_branch }, "Git failed to push")
	end

	submit_fn(pr_title, pr_body)
	p("\nCreated PR\n")
end

function M.submit_pr()
	local nvim_remote = find_git_remote(nil)
	local pr_title = "bump deps"
	local pr_body = run(
		{ "git", "log", "--grep=bump_deps", "--reverse", "--format='%s'", nvim_remote .. "/master..HEAD" },
		""
	)
	pr_body = pr_body:gsub("bump_deps: ", "")
	p(pr_title .. "\n" .. pr_body .. "\n")
	create_pr(pr_title, pr_body)
end

-- function M.main(opt)
-- 	_trace = not opt or not not opt.trace
-- end

return M
