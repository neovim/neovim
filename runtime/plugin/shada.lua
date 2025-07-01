if vim.g.loaded_shada_plugin then
  return
end
vim.g.loaded_shada_plugin = 1

local augroup = vim.api.nvim_create_augroup('nvim.shada', {})
local pattern = { '*.shada', '*.shada.tmp.[a-z]' }

---Ensures that pattern and augroup are set correctly.
---@param event string|string[]
---@param opts vim.api.keyset.create_autocmd
local function shada_autocmd(event, opts)
  opts.group = augroup
  opts.pattern = pattern
  vim.api.nvim_create_autocmd(event, opts)
end

---@type fun(binstrings: string[]): string[]
local shada_get_strings = vim.fn['shada#get_strings']
---@type fun(strings: string[]): string[]
local shada_get_binstrings = vim.fn['shada#get_binstrings']

---Read shada strings from file.
---@param file string Filename
---@return string[] # lines from shada file
local function read_strings(file)
  local f = assert(io.open(file, 'rb'))
  local strings = f:read('*a')
  f:close()
  return shada_get_strings(strings)
end

shada_autocmd('BufReadCmd', {
  callback = function(ev)
    if vim.v.cmdarg ~= '' then
      error('++opt not supported')
    end
    local lines = read_strings(ev.file)
    vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, lines)
    vim.bo[ev.buf].filetype = 'shada'
  end,
})

shada_autocmd('FileReadCmd', {
  callback = function(ev)
    if vim.v.cmdarg ~= '' then
      error('++opt not supported')
    end
    local lines = read_strings(ev.file)
    local lnum = vim.fn.line("'[")
    vim.api.nvim_buf_set_lines(ev.buf, lnum, lnum, true, lines)
  end,
})

shada_autocmd('BufWriteCmd', {
  callback = function(ev)
    if vim.v.cmdarg ~= '' then
      error('++opt not supported')
    end
    local buflines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local err = vim.fn.writefile(shada_get_binstrings(buflines), ev.file, 'b')
    if not err then
      vim.bo[ev.buf].modified = false
    end
  end,
})

shada_autocmd({ 'FileWriteCmd', 'FileAppendCmd' }, {
  callback = function(ev)
    if vim.v.cmdarg ~= '' then
      error('++opt not supported')
    end
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
  end,
})

shada_autocmd('SourceCmd', {
  callback = function(ev)
    vim.cmd.rshada(vim.fn.fnameescape(ev.file))
  end,
})
