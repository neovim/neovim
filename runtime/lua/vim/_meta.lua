--- @meta

--- @alias elem_or_list<T> T|T[]

---@type uv
vim.uv = ...

--- The following modules are loaded specially in _init_packages.lua

---@type vim.F
vim.F = require('vim.F')
---@type vim._watch
vim._watch = require('vim._watch')
---@type vim.diagnostic
vim.diagnostic = require('vim.diagnostic')
---@type vim.filetype
vim.filetype = require('vim.filetype')
---@type vim.fs
vim.fs = require('vim.fs')
---@type vim.func
vim.func = require('vim.func')
---@type vim.glob
vim.glob = require('vim.glob')
---@type vim.health
vim.health = require('vim.health')
---@type vim.hl
vim.hl = require('vim.hl')
---@type IterMod
vim.iter = require('vim.iter')
---@type vim.keymap
vim.keymap = require('vim.keymap')
---@type vim.loader
vim.loader = require('vim.loader')
---@type vim.lsp
vim.lsp = require('vim.lsp')
---@type vim.re
vim.re = require('vim.re')
---@type vim.secure
vim.secure = require('vim.secure')
---@type vim.snippet
vim.snippet = require('vim.snippet')
---@type vim.text
vim.text = require('vim.text')
---@type vim.treesitter
vim.treesitter = require('vim.treesitter')
---@type vim.ui
vim.ui = require('vim.ui')
---@type vim.version
vim.version = require('vim.version')

---@type vim.uri
local uri = require('vim.uri')

vim.uri_from_fname = uri.uri_from_fname
vim.uri_from_bufnr = uri.uri_from_bufnr
vim.uri_to_fname = uri.uri_to_fname
vim.uri_to_bufnr = uri.uri_to_bufnr

---@type vim.provider
vim.provider = require('vim.provider')
