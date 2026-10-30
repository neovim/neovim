-- biscide: Nvim as a graph IDE for Go and Rust, in its built-in GUI
-- (`nvim --gui` sets `vim.g.biscide`; otherwise this does nothing): the
-- options biscide needs (writes in place, the UI's own status line), the Go
-- and Rust parsers' highlight queries, the colours, the commands and the
-- keys (keys the user's configuration took are left to it). See
-- |biscide.txt|.
if not vim.g.biscide or vim.g.loaded_biscide then
  return
end
vim.g.loaded_biscide = true

local o = vim.opt
-- A write goes onto the file itself: its inode, owner, mode and links kept.
o.backupcopy = "yes"
o.swapfile = false
o.undofile = false
o.hidden = true
o.autoread = true
o.termguicolors = true
o.mouse = "a"
o.wrap = true
o.showmode = false
o.ruler = false
o.laststatus = 0
o.cmdheight = 1
o.more = false
o.belloff = "all"
o.shortmess:append("aoOstTWIcCFSq")
if vim.g.mapleader == nil then
  vim.g.mapleader = " "
end
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4

local group = vim.api.nvim_create_augroup("biscide_setup", { clear = true })

-- Go is indented with tabs.
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "go", "gomod", "gowork" },
  callback = function()
    vim.bo.expandtab = false
  end,
})

-- A card's file changed under it (another program wrote it): read again,
-- unless the buffer has changes of its own.
vim.api.nvim_create_autocmd("FileChangedShell", {
  group = group,
  callback = function(a)
    vim.v.fcs_choice = vim.bo[a.buf].modified and "" or "reload"
  end,
})

-- The grammars' highlight queries, as biscide colours them: written for a
-- highlighter where the first pattern matching a node wins, while in
-- Neovim the last one does; so their patterns go in the reverse order.
local function top_level_patterns(query)
  local patterns, cur, depth, i = {}, {}, 0, 1
  local function flush()
    local s = vim.trim(table.concat(cur))
    if s ~= "" then
      patterns[#patterns + 1] = s
    end
    cur = {}
  end
  while i <= #query do
    local c = query:sub(i, i)
    if c == ";" then
      local e = query:find("\n", i, true) or #query
      cur[#cur + 1] = "\n"
      i = e + 1
    else
      if (c == "(" or c == "[" or c == '"' or c == "_") and depth == 0
        and vim.trim(table.concat(cur)) ~= "" then
        flush()
      end
      cur[#cur + 1] = c
      if c == "(" or c == "[" then
        depth = depth + 1
      elseif c == ")" or c == "]" then
        depth = math.max(0, depth - 1)
      elseif c == '"' then
        i = i + 1
        while i <= #query do
          local d = query:sub(i, i)
          cur[#cur + 1] = d
          if d == "\\" then
            i = i + 1
            cur[#cur + 1] = query:sub(i, i)
          elseif d == '"' then
            break
          end
          i = i + 1
        end
      end
      i = i + 1
    end
  end
  flush()
  return patterns
end

-- The grammars' own queries (biscide/grammars/<lang>/highlights.scm on
-- 'runtimepath'), patterns reversed.
for _, lang in ipairs({ "go", "rust" }) do
  local file = vim.api.nvim_get_runtime_file("biscide/grammars/" .. lang .. "/highlights.scm", false)[1]
  local f = file and io.open(file, "r")
  if f then
    local text = f:read("*a")
    f:close()
    local patterns = top_level_patterns(text)
    local reversed = {}
    for k = #patterns, 1, -1 do
      reversed[#reversed + 1] = patterns[k]
    end
    pcall(vim.treesitter.query.set, lang, "highlights", table.concat(reversed, "\n\n") .. "\n")
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "go", "rust" },
  callback = function(ev)
    pcall(vim.treesitter.start, ev.buf, ev.match)
  end,
})

if not vim.g.colors_name then
  pcall(vim.cmd.colorscheme, "biscide")
end

-- The names that link the cards (biscide marks them in the code): each
-- underlined in the colour of its curve, red when it points outward.
-- Defaults, under any colour scheme (a scheme may set its own).
local function link_highlights()
  local links = {
    BiscideLinkCall = "#3871E1",
    BiscideLinkParameter = "#2AACB8",
    BiscideLinkField = "#C77DBB",
    BiscideLinkTypeUse = "#6DB083",
    BiscideLinkReference = "#9FA2A8",
    BiscideLinkReceiver = "#D59637",
  }
  for name, color in pairs(links) do
    vim.api.nvim_set_hl(0, name, { underline = true, sp = color, bold = true, default = true })
  end
  vim.api.nvim_set_hl(0, "BiscideLinkOutward", { undercurl = true, sp = "#F57E84", bold = true, default = true })
  vim.api.nvim_set_hl(0, "BiscideGoFile", { fg = "#2AACB8", default = true })
  vim.api.nvim_set_hl(0, "BiscideRustFile", { fg = "#CF8E6D", default = true })
end
link_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = link_highlights })

require("biscide.commands").setup()
-- After the user's init.lua: a GUI keymap of theirs keeps its keys.
require("biscide.keymaps").setup()

-- The project: the directory given (`nvim --gui DIR`), the git work tree of
-- the file given (that file in the middle), else the current directory.
local function project()
  -- The arguments as given (`nvim --gui` noted them before any plugin could
  -- rename their buffers).
  local args = vim.g.biscide_argv or vim.fn.argv()
  local arg = args[1] or ""
  if arg == "" then
    return { root = vim.uv.cwd() }
  end
  local path = vim.fs.normalize(vim.fn.fnamemodify(arg, ":p"))
  local stat = vim.uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return { root = path:gsub("/$", "") }
  end
  local dir = vim.fs.dirname(path)
  local top = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait()
  local root = top.code == 0 and vim.trim(top.stdout) or dir
  return { root = root, file = path }
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  once = true,
  callback = function()
    require("biscide.ui").install()
    require("biscide").start(project())
  end,
})
