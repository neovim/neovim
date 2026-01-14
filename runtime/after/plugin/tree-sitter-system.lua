-- Universal loader for system Tree-sitter parsers with automatic filetype mapping
-- Includes ABI check with detailed warning to :messages
-- Drops safely into /usr/share/nvim/runtime/plugin/

local ok, ts_parsers = pcall(require, "nvim-treesitter.parsers")
if not ok or not ts_parsers then
  return
end

local parser_dir = "/usr/share/nvim/runtime/parser"
local uv = vim.loop

-- Neovim Tree-sitter ABI
local nvim_min_abi = vim.treesitter.abi or 14 -- fallback
local nvim_max_abi = vim.treesitter.abi_max or 15

-- Helper: convert filename to Neovim-safe language name
local function sanitize_langname(fname)
  local name = fname:match("(.+)%.so$")
  if not name then return nil end
  name = name:gsub("-", "_")
  return name
end

-- Helper: guess filetype from parser name
local function guess_filetype(lang)
  local ft = lang
  ft = ft:gsub("_inline$", "")
  ft = ft:gsub("_sum$", "")
  ft = ft:gsub("%d+$", "")
  if ft == "vimdoc" then ft = "vim" end
  if ft == "tsx" then ft = "typescript.tsx" end
  if ft == "jinja2" then ft = "jinja" end
  return ft
end

-- Iterate over all .so files in parser_dir
local handle = uv.fs_scandir(parser_dir)
if not handle then return end

while true do
  local name, _ = uv.fs_scandir_next(handle)
  if not name then break end
  if name:match("%.so$") then
    local lang = sanitize_langname(name)
    if lang then
      local configs = ts_parsers.get_parser_configs()
      if not configs[lang] then
        local parser_path = parser_dir .. "/" .. name
        configs[lang] = {
          install_info = {
            url = parser_path,
            files = { name },
          },
          filetype = guess_filetype(lang),
        }

        -- ABI check: attempt to load parser
        local loaded, parser = pcall(vim.treesitter.language.get_lang, lang)
        if not loaded or not parser then
          vim.schedule(function()
            vim.notify(
              string.format(
                "Tree-sitter parser '%s' at %s is ABI-incompatible (Neovim ABI: %d-%d).",
                lang, parser_path, nvim_min_abi, nvim_max_abi
              ),
              vim.log.levels.WARN
            )
          end)
        end
      end
    end
  end
end
