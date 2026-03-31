-- vim: ft=lua tw=80

stds.nvim = {
  read_globals = { "jit" }
}
std = "lua51+nvim"

-- Ignore W211 (unused variable) with preload files.
files["**/preload.lua"] = {ignore = { "211" }}
-- Allow vim module to modify itself, but only here.
files["src/nvim/lua/vim.lua"] = {ignore = { "122/vim" }}

-- Don't report unused self arguments of methods.
self = false

-- Rerun tests only if their modification time changed.
cache = true

ignore = {
  "631",  -- max_line_length
  "212/_.*",  -- unused argument, for vars with "_" prefix
  "214", -- used variable with unused hint ("_" prefix)
  "121", -- setting read-only global variable 'vim'
  "122", -- setting read-only field of global variable 'vim'
  "581", -- negation of a relational operator- operator can be flipped (not for tables)
}

-- Global objects defined by the C code
read_globals = {
  "vim",
}

globals = {
  "vim.g",
  "vim.b",
  "vim.w",
  "vim.o",
  "vim.bo",
  "vim.wo",
  "vim.go",
  "vim.env",
  "_",
}

exclude_files = {
  'test/_meta.lua',
  'test/functional/fixtures/lua/syntax_error.lua',
  'runtime/lua/vim/treesitter/_meta.lua',
  'runtime/lua/vim/_meta/vimfn.lua',
  'runtime/lua/vim/_meta/api.lua',
  'runtime/lua/vim/re.lua',
  'runtime/lua/uv/_meta.lua',
  'runtime/lua/coxpcall.lua',
  'src/nvim/eval.lua',
}
