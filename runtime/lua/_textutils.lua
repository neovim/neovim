-- Utility functions for rich text ftplugins (vim help, markdown)

local M = {}

--- Apply current colorscheme to lists of default highlight groups
---
--- Note: {patterns} is assumed to be sorted by occurrence in the file.
--- @param patterns {start:string,stop:string,match:string}[]
function M.colorize_hl_groups(patterns)
  local ns = vim.api.nvim_create_namespace('nvim.vimhelp')
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

  local save_cursor = vim.fn.getcurpos()

  for _, pat in pairs(patterns) do
    local start_lnum = vim.fn.search(pat.start, 'c')
    local end_lnum = vim.fn.search(pat.stop)
    if start_lnum == 0 or end_lnum == 0 then
      break
    end

    for lnum = start_lnum, end_lnum do
      local word = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]:match(pat.match)
      if vim.fn.hlexists(word) ~= 0 then
        vim.api.nvim_buf_set_extmark(0, ns, lnum - 1, 0, { end_col = #word, hl_group = word })
      end
    end
  end

  vim.fn.setpos('.', save_cursor)
end

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

local function hash_tick(bufnr)
  return tostring(vim.b[bufnr].changedtick)
end

---@class vim._textutils.heading
---@field bufnr integer
---@field lnum integer
---@field text string
---@field level integer

--- Extract headings from buffer
--- @param bufnr integer buffer to extract headings from
--- @return vim._textutils.heading[]
local get_headings = vim.func._memoize(hash_tick, function(bufnr)
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  if not lang then
    return {}
  end
  local parser = assert(vim.treesitter.get_parser(bufnr, lang, { error = false }))
  local query = vim.treesitter.query.parse(lang, heading_queries[lang])
  local root = parser:parse()[1]:root()
  local headings = {}
  for id, node, _, _ in query:iter_captures(root, bufnr) do
    local text = vim.treesitter.get_node_text(node, bufnr)
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
end)

--- Show a table of contents for the help buffer in a loclist
function M.show_toc()
  local bufnr = vim.api.nvim_get_current_buf()
  local headings = get_headings(bufnr)
  if #headings == 0 then
    return
  end
  -- add indentation for nicer list formatting
  for _, heading in pairs(headings) do
    if heading.level > 2 then
      heading.text = '  ' .. heading.text
    end
    if heading.level > 4 then
      heading.text = '  ' .. heading.text
    end
  end
  vim.fn.setloclist(0, headings, ' ')
  vim.fn.setloclist(0, {}, 'a', { title = 'Help TOC' })
  vim.cmd.lopen()
end

--- Jump to section
--- @param opts table jump options
---  - count integer direction to jump (>0 forward, <0 backward)
---  - level integer only consider headings up to level
--- todo(clason): support count
function M.jump(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local headings = get_headings(bufnr)
  if #headings == 0 then
    return
  end

  local winid = vim.api.nvim_get_current_win()
  local curpos = vim.fn.getcurpos(winid)[2] --[[@as integer]]
  local maxlevel = opts.level or 6

  if opts.count > 0 then
    for _, heading in ipairs(headings) do
      if heading.lnum > curpos and heading.level <= maxlevel then
        vim.api.nvim_win_set_cursor(winid, { heading.lnum, 0 })
        return
      end
    end
  elseif opts.count < 0 then
    for i = #headings, 1, -1 do
      if headings[i].lnum < curpos and headings[i].level <= maxlevel then
        vim.api.nvim_win_set_cursor(winid, { headings[i].lnum, 0 })
        return
      end
    end
  end
end

return M
