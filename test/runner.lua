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

local root = repo_root()
prepend_package_roots({ root, root .. '/test', '.', './test' })

local exit_code = require('test.harness').main(_G.arg)
io.stdout:flush()
io.stderr:flush()

-- Close the standalone Lua state before exit so sanitizers see Lua-owned cleanup.
os.exit(exit_code, true)
