local vim = vim
local b = vim.b
local l = vim.opt_local
local gl = vim.opt_global
local go = vim.go
local g = vim.g
local v = vim.v
local has = vim.fn.has

if b.did_ftplugin ~= nil then
  return
end
b.did_ftplugin = 1

local cpo = go.cpo
vim.cmd([[set cpo&vim]])

l.formatoptions:remove('t')
l.formatoptions:append('croql')

l.comments = ':--'
l.commentstring = '-- %s'

l.define = [[\<function\|\<local\%(\s\+function\)\=]]
l.includeexpr, _ = v.fname:gsub('/', '.')
l.suffixesadd = '.lua'

local function undo()
  l.formatoptions = gl.formatoptions:get()

  l.comments = gl.comments:get()
  l.commentstring = gl.commentstring:get()

  l.define = gl.define:get()
  l.includeexpr = gl.includeexpr:get()
  l.suffixesadd = gl.suffixesadd:get()

  b.lua_undo_ftplugin = nil
end

b.undo_ftplugin = { undo }

if g.loaded_matchit ~= nil and b.match_words == nil then
  b.match_ignorecase = 0
  b.match_words = [[\<\%(do\|function\|if\)\>:]]
    .. [[\<\%(return\|else\|elseif\)\>:]]
    .. [[\<end\>,]]
    .. [[\<repeat\>:\<until\>,]]
    .. [=[\%(--\)\=\[\(=*\)\[:]\1]]=]

  local function undo_match()
    b.match_ignorecase = nil
    b.match_words = nil
  end

  b.undo_ftplugin[#b.undo_ftplugin + 1] = undo_match
end

if (has('gui_win32') or has('gui_gtk')) and b.browsefilter == nil then
  b.browsefilter = [[Lua Source Files (*.lua)\t*.lua\n]] .. [[All Files (*.*)\t*.*\n]]

  local function undo_browser()
    b.browsefilter = nil
  end

  b.undo_ftplugin[#b.undo_ftplugin + 1] = undo_browser
end

go.cpo = cpo

if vim.g.ts_highlight_lua then
  vim.treesitter.start()
end
