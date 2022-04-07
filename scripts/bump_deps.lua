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
--
--    # create branch
--    nvim -es +"lua require('scripts.bump_deps').create_branch()"

local M = {}

local _trace = false
local required_branch_prefix = "bump-"
local commit_prefix = "build(deps): "

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
-- if die_on_fail is true, process dies with die_msg on failure
--
-- Prints `cmd` if `trace` is enabled.
local function _run(cmd, die_on_fail, die_msg)
	if _trace then
		p("run: " .. vim.inspect(cmd))
	end
	local rv = vim.trim(vim.fn.system(cmd)) or ""
	if vim.v.shell_error ~= 0 then
		if die_on_fail then
			if _trace then
				p(rv)
			end
			p(die_msg)
			die()
		end
		return nil
	end
	return rv
end

-- Run a command, return nil on failure
local function run(cmd)
	return _run(cmd, false, "")
end

-- Run a command, die on failure with err_msg
local function run_die(cmd, err_msg)
	return _run(cmd, true, err_msg)
end

local function require_executable(cmd)
	local cmd_path = run_die({ "command", "-v", cmd }, cmd .. " not found!")
	run_die({ "test", "-x", cmd_path }, cmd .. " is not executable")
end

local function rm_file_if_present(path_to_file)
	run({ "rm", "-f", path_to_file })
end

local nvim_src_dir = vim.fn.getcwd()
local temp_dir = nvim_src_dir .. "/tmp"
run({ "mkdir", "-p", temp_dir })

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
	dependency.name = dependency_name
	return dependency
end

local function get_gh_commit_sha(repo, ref)
	require_executable("gh")

	local sha = run_die(
		{ "gh", "api", "repos/" .. repo .. "/commits/" .. ref, "--jq", ".sha" },
		"Failed to get commit hash from GitHub. Not a valid ref?"
	)
	return sha
end

local function get_archive_info(repo, ref)
	require_executable("curl")

	local archive_name = ref .. ".tar.gz"
	local archive_path = temp_dir .. "/" .. archive_name
	local archive_url = "https://github.com/" .. repo .. "/archive/" .. archive_name

	rm_file_if_present(archive_path)
	run_die({ "curl", "-sL", archive_url, "-o", archive_path }, "Failed to download archive from GitHub")

	local archive_sha = run({ "sha256sum", archive_path }):gmatch("%w+")()
	return { url = archive_url, sha = archive_sha }
end

local function write_cmakelists_line(symbol, kind, value)
	require_executable("sed")

	local cmakelists_path = nvim_src_dir .. "/" .. "third-party/CMakeLists.txt"
	run_die({
		"sed",
		"-i",
		"-e",
		"s/set(" .. symbol .. "_" .. kind .. ".*$" .. "/set(" .. symbol .. "_" .. kind .. " " .. value .. ")" .. "/",
		cmakelists_path,
	}, "Failed to write " .. cmakelists_path)
end

local function explicit_create_branch(dep)
	require_executable("git")

	local checked_out_branch = run({ "git", "rev-parse", "--abbrev-ref", "HEAD" })
	if checked_out_branch ~= "master" then
		p("Not on master!")
		die()
	end
	run_die({ "git", "checkout", "-b", "bump-" .. dep }, "git failed to create branch")
end

local function verify_branch(new_branch_suffix)
	require_executable("git")

	local checked_out_branch = run({ "git", "rev-parse", "--abbrev-ref", "HEAD" })
	if not checked_out_branch:match("^" .. required_branch_prefix) then
		p("Current branch '" .. checked_out_branch .. "' doesn't seem to start with " .. required_branch_prefix)
		p("Checking out to bump-" .. new_branch_suffix)
		explicit_create_branch(new_branch_suffix)
	end
end

local function update_cmakelists(dependency, archive, comment)
	require_executable("git")

	verify_branch(dependency.name)

	local changed_file = nvim_src_dir .. "/" .. "third-party/CMakeLists.txt"

	p("Updating " .. dependency.name .. " to " .. archive.url .. "\n")
	write_cmakelists_line(dependency.symbol, "URL", archive.url:gsub("/", "\\/"))
	write_cmakelists_line(dependency.symbol, "SHA256", archive.sha)
	run_die(
		{ "git", "commit", changed_file, "-m", commit_prefix .. "bump " .. dependency.name .. " to " .. comment },
		"git failed to commit"
	)
end

local function verify_cmakelists_committed()
	require_executable("git")

	local cmakelists_path = nvim_src_dir .. "/" .. "third-party/CMakeLists.txt"
	run_die({ "git", "diff", "--quiet", "HEAD", "--", cmakelists_path }, cmakelists_path .. " has uncommitted changes")
end

local function warn_luv_symbol()
	p("warning: " .. get_dependency("Luv").symbol .. "_VERSION will not be updated")
end

-- return first 9 chars of commit
local function short_commit(commit)
	return string.sub(commit, 1, 9)
end

-- TODO: remove hardcoded fork
local function gh_pr(pr_title, pr_body)
	require_executable("gh")

	local pr_url = run_die({
		"gh",
		"pr",
		"create",
		"--title",
		pr_title,
		"--body",
		pr_body,
	}, "Failed to create PR")
	return pr_url
end

local function find_git_remote(fork)
	require_executable("git")

	local remotes = run({ "git", "remote", "-v" })
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

	local checked_out_branch = run({ "git", "rev-parse", "--abbrev-ref", "HEAD" })
	if push_first then
		local push_remote = run({ "git", "config", "--get", "branch." .. checked_out_branch .. ".pushRemote" })
		if push_remote == nil then
			push_remote = run({ "git", "config", "--get", "remote.pushDefault" })
			if push_remote == nil then
				push_remote = run({ "git", "config", "--get", "branch." .. checked_out_branch .. ".remote" })
				if push_remote == nil or push_remote == find_git_remote(nil) then
					push_remote = find_git_remote("fork")
				end
			end
		end

		p("Pushing to " .. push_remote .. "/" .. checked_out_branch)
		run_die({ "git", "push", push_remote, checked_out_branch }, "Git failed to push")
	end

	local pr_url = gh_pr(pr_title, pr_body)
	p("\nCreated PR: " .. pr_url .. "\n")
end

function M.commit(dependency_name, commit)
	local dependency = get_dependency(dependency_name)
	verify_cmakelists_committed()
	local commit_sha = get_gh_commit_sha(dependency.repo, commit)
	if commit_sha ~= commit then
		p("Not a commit: " .. commit .. ". Did you mean version?")
		die()
	end
	local archive = get_archive_info(dependency.repo, commit)
	if dependency_name == "Luv" then
		warn_luv_symbol()
	end
	update_cmakelists(dependency, archive, short_commit(commit))
end

function M.version(dependency_name, version)
	local dependency = get_dependency(dependency_name)
	verify_cmakelists_committed()
	local commit_sha = get_gh_commit_sha(dependency.repo, version)
	if commit_sha == version then
		p("Not a version: " .. version .. ". Did you mean commit?")
		die()
	end
	local archive = get_archive_info(dependency.repo, version)
	if dependency_name == "Luv" then
		write_cmakelists_line(dependency.symbol, "VERSION", version)
	end
	update_cmakelists(dependency, archive, version)
end

function M.head(dependency_name)
	local dependency = get_dependency(dependency_name)
	verify_cmakelists_committed()
	local commit_sha = get_gh_commit_sha(dependency.repo, "HEAD")
	local archive = get_archive_info(dependency.repo, commit_sha)
	if dependency_name == "Luv" then
		warn_luv_symbol()
	end
	update_cmakelists(dependency, archive, "HEAD - " .. short_commit(commit_sha))
end

function M.create_branch(dep)
	explicit_create_branch(dep)
end

function M.submit_pr()
	require_executable("git")

	verify_branch("deps")

	local nvim_remote = find_git_remote(nil)
	local relevant_commit = run_die({
		"git",
		"log",
		"--grep=" .. commit_prefix,
		"--reverse",
		"--format='%s'",
		nvim_remote .. "/master..HEAD",
		"-1",
	}, "Failed to fetch commits")

	local pr_title
	local pr_body

	if relevant_commit == "" then
		pr_title = commit_prefix .. "bump some dependencies"
		pr_body = "bump some dependencies"
	else
		relevant_commit = relevant_commit:gsub("'", "")
		pr_title = relevant_commit
		pr_body = relevant_commit:gsub(commit_prefix:gsub("%(", "%%("):gsub("%)", "%%)"), "")
	end
	pr_body = pr_body .. "\n\n(add explanations if needed)"
	p(pr_title .. "\n" .. pr_body .. "\n")
	create_pr(pr_title, pr_body)
end

return M
