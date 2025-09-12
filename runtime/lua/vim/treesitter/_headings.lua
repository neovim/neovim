local ts = vim.treesitter
local api = vim.api

--- Treesitter-based navigation functions for headings
local M = {}

-- TODO(clason): use runtimepath queries (for other languages)
local heading_queries = {
  vimdoc = [[
    (h1 (heading) @h1)
    (h2 (heading) @h2)
    (h3 (heading) @h3)
    (column_heading (heading) @h4)
  ]],
  markdown = [[
    (setext_heading
      heading_content: (_) @h1
      (setext_h1_underline))
    (setext_heading
      heading_content: (_) @h2
      (setext_h2_underline))
    (atx_heading
      (atx_h1_marker)
      heading_content: (_) @h1)
    (atx_heading
      (atx_h2_marker)
      heading_content: (_) @h2)
    (atx_heading
      (atx_h3_marker)
      heading_content: (_) @h3)
    (atx_heading
      (atx_h4_marker)
      heading_content: (_) @h4)
    (atx_heading
      (atx_h5_marker)
      heading_content: (_) @h5)
    (atx_heading
      (atx_h6_marker)
      heading_content: (_) @h6)
  ]],
}

---@class TS.Heading
---@field bufnr integer
---@field lnum integer
---@field text string
---@field level integer

--- Extract headings from buffer
--- @param bufnr integer buffer to extract headings from
--- @return TS.Heading[]
local get_headings = function(bufnr)
  local lang = ts.language.get_lang(vim.bo[bufnr].filetype)
  if not lang then
    return {}
  end
  local parser = assert(ts.get_parser(bufnr, lang, { error = false }))
  local query = ts.query.parse(lang, heading_queries[lang])
  local root = parser:parse()[1]:root()
  local headings = {}
  for id, node, _, _ in query:iter_captures(root, bufnr) do
    local text = ts.get_node_text(node, bufnr)
    local row, col = node:start()
    --- why can't you just be normal?!
    local skip ---@type boolean|integer
    if lang == 'vimdoc' then
      -- only column_headings at col 1 are headings, otherwise it's code examples
      skip = (id == 4 and col > 0)
        -- ignore tabular material
        or (id == 4 and (text:find('\t') or text:find('  ')))
        -- ignore tag-only headings
        or (node:child_count() == 1 and node:child(0):type() == 'tag')
    end
    if not skip then
      table.insert(headings, {
        bufnr = bufnr,
        lnum = row + 1,
        text = text,
        level = id,
      })
    end
  end
  return headings
end

--- Shows an Outline (table of contents) of the current buffer, in the loclist.
function M.show_toc()
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)
  local headings = get_headings(bufnr)
  if #headings == 0 then
    return
  end
  -- add indentation for nicer list formatting
  for _, heading in pairs(headings) do
    -- Quickfix trims whitespace, so use non-breaking space instead
    heading.text = ('\194\160'):rep(heading.level - 1) .. heading.text
  end
  vim.fn.setloclist(0, headings, ' ')
  vim.fn.setloclist(0, {}, 'a', { title = 'Table of contents' })
  vim.cmd.lopen()
  vim.w.qf_toc = bufname
  -- reload syntax file after setting qf_toc variable
  vim.bo.filetype = 'qf'
end

--- Jump to section
--- @param opts table jump options
---  - count integer direction to jump (>0 forward, <0 backward)
---  - level integer only consider headings up to level
--- todo(clason): support count
function M.jump(opts)
  local bufnr = api.nvim_get_current_buf()
  local headings = get_headings(bufnr)
  if #headings == 0 then
    return
  end

  local winid = api.nvim_get_current_win()
  local curpos = vim.fn.getcurpos(winid)[2] --[[@as integer]]
  local maxlevel = opts.level or 6

  if opts.count > 0 then
    for _, heading in ipairs(headings) do
      if heading.lnum > curpos and heading.level <= maxlevel then
        api.nvim_win_set_cursor(winid, { heading.lnum, 0 })
        return
      end
    end
  elseif opts.count < 0 then
    for i = #headings, 1, -1 do
      if headings[i].lnum < curpos and headings[i].level <= maxlevel then
        api.nvim_win_set_cursor(winid, { headings[i].lnum, 0 })
        return
      end
    end
  end
end

return M
