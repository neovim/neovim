-- Extra functionality for displaying Vim help.

local M = {}

--- Apply current colorscheme to lists of default highlight groups
---
--- Note: {patterns} is assumed to be sorted by occurrence in the file.
--- @param patterns {start:string,stop:string,match:string}[]
function M.highlight_groups(patterns)
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

--- Show a table of contents for the help buffer in a loclist
function M.show_toc()
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = assert(vim.treesitter.get_parser(bufnr, 'vimdoc', { error = false }))
  local query = vim.treesitter.query.parse(
    parser:lang(),
    [[
    (h1 (heading) @h1)
    (h2 (heading) @h2)
    (h3 (heading) @h3)
    (column_heading (heading) @h4)
  ]]
  )
  local root = parser:parse()[1]:root()
  local headings = {}
  for id, node, _, _ in query:iter_captures(root, bufnr) do
    local text = vim.treesitter.get_node_text(node, bufnr)
    local capture = query.captures[id]
    local row, col = node:start()
    -- only column_headings at col 1 are headings, otherwise it's code examples
    local is_code = (capture == 'h4' and col > 0)
    -- ignore tabular material
    local is_table = (capture == 'h4' and (text:find('\t') or text:find('  ')))
    -- ignore tag-only headings
    local is_tag = node:child_count() == 1 and node:child(0):type() == 'tag'
    if not (is_code or is_table or is_tag) then
      table.insert(headings, {
        bufnr = bufnr,
        lnum = row + 1,
        text = (capture == 'h3' or capture == 'h4') and '  ' .. text or text,
      })
    end
  end
  vim.fn.setloclist(0, headings, ' ')
  vim.fn.setloclist(0, {}, 'a', { title = 'Help TOC' })
  vim.cmd.lopen()
end

return M
