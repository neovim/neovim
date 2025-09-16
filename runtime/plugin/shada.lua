if vim.g.loaded_shada_plugin then
  return
end
vim.g.loaded_shada_plugin = 1

local augroup = vim.api.nvim_create_augroup('nvim.shada', {})

---@type fun(binstrings: string[]): string[]
local shada_get_strings = vim.fn['shada#get_strings']

---@type fun(strings: string[]): string[]
local shada_get_binstrings = vim.fn['shada#get_binstrings']

---Ensures that pattern and augroup are set correctly.
---@param event string|string[]
---@param opts vim.api.keyset.create_autocmd
---@param fn fun(args: vim.api.keyset.create_autocmd.callback_args): boolean?
local function def_autocmd(event, opts, fn)
  opts = opts or {}
  opts.group = augroup
  opts.pattern = { '*.shada', '*.shada.tmp.[a-z]' }
  opts.callback = function(ev)
    if vim.v.cmdarg ~= '' then
      error('++opt not supported')
    end
    fn(ev)
  end
  vim.api.nvim_create_autocmd(event, opts)
end

---Read shada strings from file.
---@param file string Filename
---@return string[] # lines from shada file
local function read_strings(file)
  local f = assert(io.open(file, 'rb'))
  local strings = f:read('*a')
  f:close()
  return shada_get_strings(strings)
end

def_autocmd('BufReadCmd', {}, function(ev)
  local lines = read_strings(ev.file)
  vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, lines)
  vim.bo[ev.buf].filetype = 'shada'
end)

def_autocmd('FileReadCmd', {}, function(ev)
  local lines = read_strings(ev.file)
  local lnum = vim.fn.line("'[")
  vim.api.nvim_buf_set_lines(ev.buf, lnum, lnum, true, lines)
end)

def_autocmd('BufWriteCmd', {}, function(ev)
  local buflines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local ret = vim.fn.writefile(shada_get_binstrings(buflines), ev.file, 'b')
  if ret == 0 then
    vim.bo[ev.buf].modified = false
  end
end)

def_autocmd({ 'FileWriteCmd', 'FileAppendCmd' }, {}, function(ev)
  vim.fn.writefile(
    shada_get_binstrings(
      vim.fn.getline(
        math.min(vim.fn.line("'["), vim.fn.line("']")),
        math.max(vim.fn.line("'["), vim.fn.line("']"))
      ) --[=[@as string[]]=]
    ),
    ev.file,
    ev.event == 'FileAppendCmd' and 'ab' or 'b'
  )
end)

def_autocmd('SourceCmd', {}, function(ev)
  vim.cmd.rshada(vim.fn.fnameescape(ev.file))
end)
