local uv = vim.uv

---@return string
local function repo_root()
  local source = debug.getinfo(1, 'S').source
  assert(type(source) == 'string' and vim.startswith(source, '@'), 'failed to resolve runner path')
  local script_path = assert(uv.fs_realpath(source:sub(2)), 'failed to resolve runner path')
  return vim.fs.dirname(vim.fs.dirname(script_path))
end

---@param roots string[]
local function prepend_package_roots(roots)
  local entries = {}
  for _, root in ipairs(roots) do
    entries[#entries + 1] = root .. '/?.lua'
    entries[#entries + 1] = root .. '/?/init.lua'
  end

  package.path = table.concat(entries, ';') .. ';' .. package.path
end

_G.c_include_path = {}
while _G.arg[1] and vim.startswith(_G.arg[1], '-I') do
  table.insert(_G.c_include_path, string.sub(table.remove(_G.arg, 1), 3))
end
-- TODO(bfredl): use also for cmake?
if _G.arg[1] and vim.startswith(_G.arg[1], '-P') then
  local build_dir = string.sub(table.remove(_G.arg, 1), 3)
  _G.nvim_build_dir = build_dir

  -- TMPDIR: for testutil.tmpname() and Nvim tempname().
  vim.env.TMPDIR = build_dir .. '/Xtest_tmpdir'
  vim.fn.mkdir(vim.env.TMPDIR, 'p')
end
if _G.arg[1] and vim.startswith(_G.arg[1], '-X') then
  local xdg_dir = string.sub(table.remove(_G.arg, 1), 3)
  vim.env.NVIM_LOG_FILE = xdg_dir .. '/Xtest_nvimlog'
  vim.env.NVIM_RPLUGIN_MANIFEST = xdg_dir .. '/Xtest_rplugin_manifest'
  vim.env.XDG_CONFIG_HOME = xdg_dir .. '/config'
  vim.env.XDG_DATA_HOME = xdg_dir .. '/share'
  vim.env.XDG_STATE_HOME = xdg_dir .. '/state'
end

local root = repo_root()
prepend_package_roots({ root, root .. '/test', '.', './test' })
local entries = { root .. '/src/?.lua', root .. '/runtime/lua/?.lua' }
package.path = table.concat(entries, ';') .. ';' .. package.path
vim.env.VIMRUNTIME = root .. '/runtime'

-- The harness is not an Nvim instance under test. If its startup server stays
-- visible, serverlist({ peer = true }) can connect back to the runner and wait
-- forever for an RPC response.
if vim.v.servername ~= '' then
  assert(vim.fn.serverstop(vim.v.servername) == 1)
end

local exit_code = require('test.harness').main(_G.arg)
io.stdout:flush()
io.stderr:flush()

os.exit(exit_code)
