#!/usr/bin/env -S nvim -l

-- Usage:
--    ./scripts/bump_deps.lua -h

local _trace = false
local required_branch_prefix = 'bump-'
local commit_prefix = 'build(deps): '

local repos = {
  'LuaJIT/LuaJIT',
  'libuv/libuv',
  'luvit/luv',
  'neovim/unibilium',
  'JuliaStrings/utf8proc',
  'tree-sitter/tree-sitter',
  'tree-sitter/tree-sitter-c',
  'tree-sitter-grammars/tree-sitter-lua',
  'tree-sitter-grammars/tree-sitter-vim',
  'neovim/tree-sitter-vimdoc',
  'tree-sitter-grammars/tree-sitter-query',
  'tree-sitter-grammars/tree-sitter-markdown',
  'bytecodealliance/wasmtime',
  'uncrustify/uncrustify',
}

local dependency_table = {} --- @type table<string, string>
for _, repo in pairs(repos) do
  dependency_table[vim.fs.basename(repo)] = repo
end

-- Print message
local function p(s)
  vim.cmd('set verbose=1')
  vim.api.nvim_echo({ { s, '' } }, false, {})
  vim.cmd('set verbose=0')
end

local function die()
  p('')
  vim.cmd('cquit 1')
end

-- Executes and returns the output of `cmd`, or nil on failure.
-- if die_on_fail is true, process dies with die_msg on failure
--
-- Prints `cmd` if `trace` is enabled.
local function _run(cmd, die_on_fail, die_msg)
  if _trace then
    p('run: ' .. vim.inspect(cmd))
  end
  local rv = vim.trim(vim.fn.system(cmd)) or ''
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
  return _run(cmd, false, '')
end

-- Run a command, die on failure with err_msg
local function run_die(cmd, err_msg)
  return _run(cmd, true, err_msg)
end

local nvim_src_dir = vim.fn.getcwd()
local deps_file = nvim_src_dir .. '/' .. 'cmake.deps/deps.txt'
local temp_dir = nvim_src_dir .. '/tmp'
run({ 'mkdir', '-p', temp_dir })

local function get_dependency(name_preformat)
  -- Allow all variations of tree-sitter, treesitter, tree_sitter_c, tree_sitter-c etc
  local name = string.gsub(name_preformat, 'treesitter', 'tree-sitter'):gsub('_', '-')
  local repo = dependency_table[name]

  local symbol = name:gsub('tree%-sitter', 'treesitter'):gsub('%-', '_'):upper()

  return name, repo, symbol
end

local function get_gh_commit_sha(repo, ref)
  assert(vim.fn.executable('gh') == 1)

  local sha = run_die(
    { 'gh', 'api', 'repos/' .. repo .. '/commits/' .. ref, '--jq', '.sha' },
    'Failed to get commit hash from GitHub. Not a valid ref?'
  )
  return assert(sha)
end

--- @param repo string
--- @param ref string
local function get_archive_info(repo, ref)
  assert(vim.fn.executable('curl') == 1)

  local archive_name = ref .. '.tar.gz'
  local archive_path = temp_dir .. '/' .. archive_name
  local archive_url = 'https://github.com/' .. repo .. '/archive/' .. archive_name

  vim.fs.rm(archive_path, { force = true })
  run_die(
    { 'curl', '-sL', archive_url, '-o', archive_path },
    'Failed to download archive from GitHub'
  )

  local shacmd = (
    vim.fn.executable('sha256sum') == 1 and { 'sha256sum', archive_path }
    or { 'shasum', '-a', '256', archive_path }
  )
  local archive_sha = run(shacmd):gmatch('%w+')()
  return { url = archive_url, sha = archive_sha }
end

local function update_deps_file(symbol, kind, value)
  assert(vim.fn.executable('sed') == 1)

  run_die({
    'sed',
    '-i',
    '-e',
    's/' .. symbol .. '_' .. kind .. '.*$' .. '/' .. symbol .. '_' .. kind .. ' ' .. value .. '/',
    deps_file,
  }, 'Failed to write ' .. deps_file)
end

local function verify_branch(branch_suffix)
  branch_suffix = ''
  local checked_out_branch = assert(run({ 'git', 'rev-parse', '--abbrev-ref', 'HEAD' }))
  if not checked_out_branch:match('^' .. required_branch_prefix) then
    p(
      "Current branch '"
        .. checked_out_branch
        .. "' doesn't seem to start with "
        .. required_branch_prefix
    )
    p('Checking out to bump-' .. branch_suffix)
    run_die({ 'git', 'checkout', '-b', 'bump-' .. branch_suffix }, 'git failed to create branch')
  end
end

local function update_deps_file_wrapper(name, symbol, archive, comment)
  verify_branch(name)

  p('Updating ' .. name .. ' to ' .. archive.url .. '\n')
  update_deps_file(symbol, 'URL', archive.url:gsub('/', '\\/'))
  update_deps_file(symbol, 'SHA256', archive.sha)
  run_die({
    'git',
    'commit',
    deps_file,
    '-m',
    commit_prefix .. 'bump ' .. name .. ' to ' .. comment,
  }, 'git failed to commit')
end

-- return first 9 chars of commit
local function short_commit(commit)
  return string.sub(commit, 1, 9)
end

local function ref(dependency_name, _ref)
  local name, repo, symbol = get_dependency(dependency_name)
  run_die(
    { 'git', 'diff', '--quiet', 'HEAD', '--', deps_file },
    deps_file .. ' has uncommitted changes'
  )
  local commit_sha = get_gh_commit_sha(repo, _ref)
  local archive = get_archive_info(repo, commit_sha)
  update_deps_file_wrapper(name, symbol, archive, short_commit(_ref))
end

local function usage()
  local this_script = vim.fs.basename(_G.arg[0])
  print(([=[
    Bump Nvim dependencies

    Usage:  nvim -l %s [options]
        Bump to HEAD, tagged version, commit, or branch:
            nvim -l %s --dep luv --head
            nvim -l %s --dep luv --ref 1.43.0-0
            nvim -l %s --dep luv --ref abc123

    Options:
        -h                    show this message and exit.
        --dep <dependency>    bump to a specific release or tag.

    Dependency Options:
        --ref <ref>           bump to a specific commit or tag.
        --head                bump to a current head.

        <dependency> is one of:
        "luajit", "libuv", "luv", "treesitter"
  ]=]):format(this_script, this_script, this_script, this_script, this_script, this_script))
end

local function parseargs()
  local args = {}
  for i = 1, #_G.arg do
    if _G.arg[i] == '-h' then
      args.h = true
    elseif _G.arg[i] == '--dep' then
      args.dep = _G.arg[i + 1]
    elseif _G.arg[i] == '--ref' then
      args.ref = _G.arg[i + 1]
    elseif _G.arg[i] == '--head' then
      args.ref = 'HEAD'
    end
  end
  return args
end

assert(vim.fn.executable('git') == 1)

local args = parseargs()
if args.h then
  usage()
elseif args.ref then
  ref(args.dep, args.ref)
else
  print('missing required arg\n')
  os.exit(1)
end
