-- Vim support file to switch on loading plugins for file types

local vim = vim
local api = vim.api
local b = vim.b
local g = vim.g
local go = vim.go
local format = string.format
local nvim_exec = api.nvim_exec
local nvim_create_augroup = api.nvim_create_augroup
local nvim_create_autocmd = api.nvim_create_autocmd

if g.did_load_ftplugin ~= nil then
  return
end
g.did_load_ftplugin = 1

local function load_ftplugin(match)
  if b.undo_ftplugin ~= nil then
    local type_undo_ftplugin = type(b.undo_ftplugin)
    if type_undo_ftplugin == 'string' then
      nvim_exec(b.undo_ftplugin, false)
      vim.b.undo_ftplugin = nil
      vim.b.did_ftplugin = nil
    elseif type_undo_ftplugin == 'function' then
      b.undo_ftplugin()
      vim.b.undo_ftplugin = nil
      vim.b.did_ftplugin = nil
    elseif type_undo_ftplugin == 'table' then
      for _, value in ipairs(vim.b.undo_ftplugin) do
        local type_value = type(value)
        if type_value == 'string' then
          nvim_exec(value, false)
        elseif type_value == 'function' then
          value()
        end
      end
      vim.b.undo_ftplugin = nil
      vim.b.did_ftplugin = nil
    end
  end

  if match ~= nil and match ~= '' then
    if type(go.cpo) == 'string' and go.cpo:find('S') ~= nil and b.did_ftplugin ~= nil then
      -- In compatible mode options are reset to the global values, need to
      -- set the local values also when a plugin was already used.
      vim.b.did_ftplugin = nil
    end
    local values = {}

    -- When there is a dot it is used to separate filetype names.  Thus for
    -- "aaa.bbb" load "aaa" and then "bbb".
    -- for name in split(s, '\.')
    for _, v in ipairs(vim.split(match, '.', { plain = true, trimempty = true })) do
      -- First Vimscript
      values[#values + 1] = format('ftplugin/%s.vim', v)
      values[#values + 1] = format('ftplugin/%s_*.vim', v)
      values[#values + 1] = format('ftplugin/%s/*.vim', v)
      -- After Lua
      values[#values + 1] = format('ftplugin/%s.lua', v)
      values[#values + 1] = format('ftplugin/%s_*.lua', v)
      values[#values + 1] = format('ftplugin/%s/*.lua', v)
    end
    values.bang = true
    -- Let runtime logic decide the loading order, i.e. first user-defined plugins and then global ones.
    vim.cmd.runtime(values)
  end
end

local filetypeplugin = nvim_create_augroup('filetypeplugin', { clear = false })
local _ = nvim_create_autocmd({ 'FileType' }, {
  group = filetypeplugin,
  callback = function(ev)
    load_ftplugin(ev.match)
  end,
  desc = 'Load FileType Plugin',
})
