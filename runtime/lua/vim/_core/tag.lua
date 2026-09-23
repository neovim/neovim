local N_ = vim.fn.gettext
local api = vim.api

local M = {}

--- @class vim._core.tag.Match
--- @field tag string
--- @field kind? string
--- @field pri string  Priority code, e.g. "FSC" — see `:h tag-priority`.
--- @field file string
--- @field extra? string
--- @field cur boolean True if this is the currently-active tagstack match.

--- Implements `do_tag()` (`:tselect`, ambiguous `:tag`, …) via vim.ui.select().
---
--- async: returns immediately, the chosen tag is applied later by re-running
--- `:[mods] [idx]tag {tagname}` (or `stag`) from `on_choice`.
---
--- @param eap vim._core.ExCmdArgs Original :tselect/:stselect/… invocation.
--- @param extra { items: vim._core.tag.Match[], tagname: string }
function M.select_tag(eap, extra)
  local items, tagname = extra.items, extra.tagname
  -- :stag/:stselect/:stjump need a split when re-invoked.
  local stag = eap.name:sub(1, 1) == 's'
  -- `eap.mods` is the raw modifier string (e.g. ":vert silent").
  local mods_str = eap.mods ~= '' and (eap.mods .. ' ') or ''

  local taglen = 18
  for _, m in ipairs(items) do
    taglen = math.max(taglen, vim.fn.strdisplaywidth(m.tag) + 2)
  end

  vim.ui.select(items, {
    prompt = N_('Select a tag:'),
    kind = 'tag',
    format_item = function(m)
      local marker = m.cur and '>' or ' '
      local kind = m.kind or ''
      return ('%s %s %-4s %-' .. taglen .. 's %s%s'):format(
        marker,
        m.pri,
        kind,
        m.tag,
        m.file,
        m.extra and (' ' .. m.extra) or ''
      )
    end,
  }, function(_, idx)
    if not idx then
      return
    end
    -- Queue ":[mods] [idx](s)tag {tagname}" as user input, so the recursive do_tag runs via the
    -- normal input-dispatch loop. Using vim.schedule + vim.cmd can hang bc of "Press ENTER".
    local cmd = stag and 'stag' or 'tag'
    vim.fn.feedkeys(vim.keycode(('<Cmd>%s%d%s %s<CR>'):format(mods_str, idx, cmd, tagname)), 'in')
  end)
end

--- GitHub-style heading slug: lowercase, strip punctuation, spaces to hyphens.
--- @param s string
--- @return string
local function slug(s)
  return (s:lower():gsub('[^%w%s_-]', ''):gsub('%s+', '-'))
end

--- Jump to a named tag in the current buffer (|gF| `{fname}#{tag}`).
---
--- Tries, in order: LSP document symbols (|gO|), Treesitter headings,
--- help tags (`*tag*`), then a word search.
---
--- @param tag string Tag name without the leading '#'.
--- @return boolean success
function M.jump_to_file_tag(tag)
  if type(tag) ~= 'string' or tag == '' then
    return false
  end
  local bufnr = api.nvim_get_current_buf()
  local winid = api.nvim_get_current_win()

  --- @param lnum integer 1-based
  --- @return boolean
  local function jump(lnum)
    local line_count = api.nvim_buf_line_count(bufnr)
    lnum = math.max(1, math.min(lnum, line_count))
    api.nvim_win_set_cursor(winid, { lnum, 0 })
    vim.cmd('normal! zv')
    return true
  end

  -- LSP document symbols (|gO| locations).
  local lsp_ok, symbols = pcall(function()
    local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/documentSymbol' })
    if #clients == 0 then
      return nil
    end
    local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
    local results = vim.lsp.buf_request_sync(bufnr, 'textDocument/documentSymbol', params, 1000)
    if not results then
      return nil
    end
    --- @type { name: string, lnum: integer }[]
    local out = {}
    --- @param items table[]
    local function walk(items)
      for _, item in ipairs(items) do
        local range = item.selectionRange or item.range
        local lnum
        if range and range.start then
          lnum = range.start.line + 1
        elseif item.location and item.location.range then
          lnum = item.location.range.start.line + 1
        end
        if item.name and lnum then
          out[#out + 1] = { name = item.name, lnum = lnum }
        end
        if item.children then
          walk(item.children)
        end
      end
    end
    for _, resp in pairs(results) do
      if resp.result then
        walk(resp.result)
      end
    end
    return out
  end)

  if lsp_ok and symbols then
    local tag_lower = tag:lower()
    for _, sym in ipairs(symbols) do
      if sym.name == tag then
        return jump(sym.lnum)
      end
    end
    for _, sym in ipairs(symbols) do
      if sym.name:lower() == tag_lower then
        return jump(sym.lnum)
      end
    end
  end

  -- Treesitter headings (Markdown, vimdoc).
  local ok, headings = pcall(function()
    return require('vim.treesitter._headings').find_heading(tag, bufnr)
  end)
  if ok and headings then
    return jump(headings.lnum)
  end

  -- Help tags: `*tag*`.
  local tag_pat = vim.fn.escape(tag, '\\')
  local help_lnum = vim.fn.searchpos(string.format('\\V*%s*', tag_pat), 'nw')[1]
  if help_lnum > 0 then
    return jump(help_lnum)
  end

  -- Word search.
  local word_pat = string.format('\\V\\<%s\\>', tag_pat)
  local word_lnum = vim.fn.searchpos(word_pat, 'nw')[1]
  if word_lnum > 0 then
    return jump(word_lnum)
  end

  vim.notify(string.format('E370: Could not find tag "%s"', tag), vim.log.levels.ERROR)
  return false
end

return M
