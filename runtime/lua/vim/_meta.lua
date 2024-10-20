--- @meta

--- @alias elem_or_list<T> T|T[]

---@type uv
vim.uv = ...

--- The following modules are loaded specially in _init_packages.lua

vim.F = require('vim.F')
vim._watch = require('vim._watch')
vim.diagnostic = require('vim.diagnostic')
vim.filetype = require('vim.filetype')
vim.fs = require('vim.fs')
vim.func = require('vim.func')
vim.glob = require('vim.glob')
vim.health = require('vim.health')
vim.hl = require('vim.hl')
vim.iter = require('vim.iter')
vim.keymap = require('vim.keymap')
vim.loader = require('vim.loader')
vim.lsp = require('vim.lsp')
vim.re = require('vim.re')
vim.secure = require('vim.secure')
vim.snippet = require('vim.snippet')
vim.text = require('vim.text')
vim.treesitter = require('vim.treesitter')
vim.ui = require('vim.ui')
vim.version = require('vim.version')

local uri = require('vim.uri')

vim.uri_from_fname = uri.uri_from_fname
vim.uri_from_bufnr = uri.uri_from_bufnr
vim.uri_to_fname = uri.uri_to_fname
vim.uri_to_bufnr = uri.uri_to_bufnr

vim.provider = require('vim.provider')
