#!/usr/bin/env -S nvim -l

-- Usage:
--    ./scripts/bump_deps.lua -h

assert(vim.fn.executable('gh') == 1)
assert(vim.fn.executable('sed') == 1)

local required_branch_prefix = 'bump-'
local commit_prefix = 'build(deps): '

local repos = {
  'luajit/luajit',
  'libuv/libuv',
  'luvit/luv',
  'neovim/unibilium',
  'juliastrings/utf8proc',
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

local zig_mode = {
  luajit = false,
  uncrustify = false,
  wasmtime = false,
  unibilium = 'nested',
  utf8proc = 'nested',
  libuv = 'nested',
}

local dependency_table = {} --- @type table<string, string>
for _, repo in pairs(repos) do
  dependency_table[vim.fs.basename(repo)] = repo
end

local function die(msg)
  print(msg)
  vim.cmd('cquit 1')
end

-- Executes and returns the output of `cmd`, or nil on failure.
-- if die_on_fail is true, process dies with die_msg on failure
local function _run(cmd, die_on_fail, die_msg)
  local rv = vim.system(cmd):wait()
  if rv.code ~= 0 then
    if die_on_fail then
      die(die_msg)
    end
    return nil
  end
  return vim.trim(rv.stdout)
end

-- Run a command, return nil on failure
local function run(cmd)
  return _run(cmd, false, '')
end

-- Run a command, die on failure with err_msg
local function run_die(cmd, err_msg)
  -- print(vim.inspect(table.concat(cmd, ' ')))
  return _run(cmd, true, err_msg)
end

local nvim_src_dir = run({ 'git', 'rev-parse', '--show-toplevel' })
local deps_file = nvim_src_dir .. '/' .. 'cmake.deps/deps.txt'

--- @param repo string
--- @param ref string
local function get_archive_info(repo, ref)
  local temp_dir = os.getenv('TMPDIR') or os.getenv('TEMP') or '/tmp'

  local archive_name = ref .. '.tar.gz'
  local archive_path = temp_dir .. '/' .. archive_name
  local archive_url = 'https://github.com/' .. repo .. '/archive/' .. archive_name

  run_die(
    { 'curl', '-sfL', archive_url, '-o', archive_path },
    'Failed to download archive from GitHub'
  )

  local shacmd = (
    vim.fn.executable('sha256sum') == 1 and { 'sha256sum', archive_path }
    or { 'shasum', '-a', '256', archive_path }
  )
  local archive_sha = run(shacmd):gmatch('%w+')()
  return { url = archive_url, sha = archive_sha }
end

local function get_gh_commit_sha(repo, ref)
  local full_repo = string.format('https://github.com/%s.git', repo)
  local tag_exists = run_die({ 'git', 'ls-remote', full_repo, 'refs/tags/' .. ref }) ~= ''
  -- We'd rather use the git tag over commit sha if possible
  if tag_exists then
    return ref
  end

  local sha = assert(
    run_die(
      { 'gh', 'api', 'repos/' .. repo .. '/commits/' .. ref, '--jq', '.sha' },
      'Failed to get commit hash from GitHub. Not a valid ref?'
    )
  )
  return sha
end

local function update_deps_file(symbol, kind, value)
  run_die({
    'sed',
    '-i',
    '-e',
    's/' .. symbol .. '_' .. kind .. '.*$' .. '/' .. symbol .. '_' .. kind .. ' ' .. value .. '/',
    deps_file,
  }, 'Failed to write ' .. deps_file)
end

local function ref(name, _ref)
  local repo = dependency_table[name]
  local symbol = string.gsub(name, 'tree%-sitter', 'treesitter'):gsub('%-', '_')
  local symbol_upper = symbol:upper()

  run_die(
    { 'git', 'diff', '--quiet', 'HEAD', '--', deps_file },
    deps_file .. ' has uncommitted changes'
  )

  _ref = get_gh_commit_sha(repo, _ref)

  local archive = get_archive_info(repo, _ref)
  local comment = string.sub(_ref, 1, 9)

  local checked_out_branch = assert(run({ 'git', 'rev-parse', '--abbrev-ref', 'HEAD' }))
  if not checked_out_branch:match('^' .. required_branch_prefix) then
    print(
      "Current branch '"
        .. checked_out_branch
        .. "' doesn't seem to start with "
        .. required_branch_prefix
    )
    print('Checking out to bump-' .. name)
    run_die({ 'git', 'checkout', '-b', 'bump-' .. name }, 'git failed to create branch')
  end

  print('Updating ' .. name .. ' to ' .. archive.url .. '\n')
  update_deps_file(symbol_upper, 'URL', archive.url:gsub('/', '\\/'))
  update_deps_file(symbol_upper, 'SHA256', archive.sha)
  run_die({ 'git', 'add', deps_file })

  local zig = zig_mode[symbol]
  if zig ~= false then
    if zig == 'nested' then
      -- don't care about un-cding, "git commit" doesn't care and then we die
      vim.fn.chdir('deps/' .. symbol)
    end
    -- note: get_gh_commit_sha is likely superfluous with zig. but use the same resolved hash, for consistency.
    run_die({
      'zig',
      'fetch',
      '--save=' .. symbol,
      'git+https://github.com/' .. repo .. '#' .. _ref,
    })
    run_die({ 'git', 'add', 'build.zig.zon' })
  end

  run_die({
    'git',
    'commit',
    '-m',
    commit_prefix .. 'bump ' .. name .. ' to ' .. comment,
  }, 'git failed to commit')
end

local function usage()
  local this_script = tostring(vim.fs.basename(_G.arg[0]))
  local script_exe = './' .. this_script
  local help = ([=[
    Bump Nvim dependencies

    Usage:  %s [options]
        Bump to HEAD, tagged version or commit:
            %s luv --head
            %s luv --ref 1.43.0-0
            %s luv --ref abc123

    Options:
        -h, --help            show this message and exit.
        --list                list all dependencies

    Dependency Options:
        --ref <ref>           bump to a specific commit or tag.
        --head                bump to a current head.
  ]=]):format(script_exe, script_exe, script_exe, script_exe)
  print(help)
end

local function list_deps()
  local l = 'Dependencies:\n'
  for k in vim.spairs(dependency_table) do
    l = string.format('%s\n%s%s', l, string.rep(' ', 2), k)
  end
  print(l)
end

do
  local args = {}
  local i = 1
  while i <= #_G.arg do
    if _G.arg[i] == '-h' or _G.arg[i] == '--help' then
      args.h = true
    elseif _G.arg[i] == '--list' then
      args.list = true
    elseif _G.arg[i] == '--ref' then
      args.ref = _G.arg[i + 1]
      i = i + 1
    elseif _G.arg[i] == '--head' then
      args.ref = 'HEAD'
    elseif vim.startswith(_G.arg[i], '--') then
      die(string.format('Invalid argument %s\n', _G.arg[i]))
    else
      args.dep = _G.arg[i]
    end
    i = i + 1
  end

  if args.h then
    usage()
  elseif args.list then
    list_deps()
  elseif args.ref then
    ref(args.dep, args.ref)
  else
    die('missing required arg\n')
  end
end
