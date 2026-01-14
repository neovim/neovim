-- Universal loader for system Tree-sitter parsers with automatic filetype mapping
-- Includes ABI check with detailed warning to :messages
-- Self-contained: only depends on Neovim built-ins

-- Neovim Tree-sitter ABI
---@type integer
local nvim_min_abi = vim.treesitter.abi or 14 -- fallback
---@type integer
local nvim_max_abi = vim.treesitter.abi_max or 15

local FILETYPE_OVERRIDES = {
  vimdoc = 'vim',
  tsx = 'typescript.tsx',
  jinja2 = 'jinja',
}

local parser_dir = '/usr/share/nvim/runtime/parser'
local uv = vim.uv

-- Helper: convert filename to Neovim-safe language name
---@param fname string # The filename to sanitize (e.g., 'python.so')
---@return string? # Returns the sanitized language name or nil if no match
local function sanitize_langname(fname)
  local name = fname:match('(.+)%.so$')
  if name then
    ---@cast name string
    name = name:gsub('-', '_')
    return name
  else
    vim.notify(
      string.format('Failed to sanitize filename: %s', fname),
      vim.log.levels.DEBUG
    )
    return nil
  end
end

-- Helper: guess filetype from parser name
---@param lang string
---@return string
local function guess_filetype(lang)
  local ft = lang:gsub('_inline$', ''):gsub('_sum$', ''):gsub('%d+$', '')
  return FILETYPE_OVERRIDES[ft] or ft
end

-- Iterate over all .so files in parser_dir
local handle = uv.fs_scandir(parser_dir)
if not handle then
  vim.notify(
    string.format('Tree-sitter parser directory not found: %s', parser_dir),
    vim.log.levels.DEBUG
  )
  return
end

while true do
  local filename = uv.fs_scandir_next(handle)
  if not filename then
    break
  end

  if filename:match('%.so$') then
    local lang = sanitize_langname(filename)
    if lang then
      -- ABI check: attempt to load parser
      ---@diagnostic disable-next-line: no-unknown
      local loaded, _ = pcall(vim.treesitter.language.require_lang, lang)

      if loaded then
        -- Only register if parser loaded successfully
        local ft = guess_filetype(lang)
        vim.treesitter.language.register(lang, ft)
      else
        vim.schedule(function()
          vim.notify(
            string.format(
              "Tree-sitter parser '%s' failed to load (likely ABI mismatch: Neovim ABI: %d-%d).",
              lang,
              nvim_min_abi,
              nvim_max_abi
            ),
            vim.log.levels.WARN
          )
        end)
      end
    end
  end
end
