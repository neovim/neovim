local M = {}

local report_ok = vim.fn['health#report_ok']
local report_error = vim.fn['health#report_error']

local function check_runtime_file(name)
  local path = vim.env.VIMRUNTIME .. '/' .. name
  if vim.loop.fs_stat(path) then
    report_error(string.format('%s detected. Please delete %s', name, path))
  else
    report_ok(string.format('%s not in $VIMRUNTIME', name))
  end
end

function M.check()
  check_runtime_file('plugin/man.vim')
  check_runtime_file('autoload/man.vim')
end

return M
