-- TODO(justinmk): move most of this to `vim.text`.

local fmt = string.format

--- @class nvim.util.MDNode
--- @field [integer] nvim.util.MDNode
--- @field type string
--- @field text? string

local INDENTATION = 4

local NBSP = string.char(160)

local M = {}

local function contains(t, xs)
  return vim.tbl_contains(xs, t)
end

-- Map of api_level:version, by inspection of:
--    :lua= vim.mpack.decode(vim.fn.readfile('test/functional/fixtures/api_level_9.mpack','B')).version
M.version_level = {
  [14] = '0.12.0',
  [13] = '0.11.0',
  [12] = '0.10.0',
  [11] = '0.9.0',
  [10] = '0.8.0',
  [9] = '0.7.0',
  [8] = '0.6.0',
  [7] = '0.5.0',
  [6] = '0.4.0',
  [5] = '0.3.2',
  [4] = '0.3.0',
  [3] = '0.2.1',
  [2] = '0.2.0',
  [1] = '0.1.0',
}

--- @param txt string
--- @param srow integer
--- @param scol integer
--- @param erow? integer
--- @param ecol? integer
--- @return string
local function slice_text(txt, srow, scol, erow, ecol)
  local lines = vim.split(txt, '\n')

  if srow == erow then
    return lines[srow + 1]:sub(scol + 1, ecol)
  end

  if erow then
    -- Trim the end
    for _ = erow + 2, #lines do
      table.remove(lines, #lines)
    end
  end

  -- Trim the start
  for _ = 1, srow do
    table.remove(lines, 1)
  end

  lines[1] = lines[1]:sub(scol + 1)
  lines[#lines] = lines[#lines]:sub(1, ecol)

  return table.concat(lines, '\n')
end

--- @param text string
--- @return nvim.util.MDNode
local function parse_md_inline(text)
  local parser = vim.treesitter.languagetree.new(text, 'markdown_inline')
  local root = parser:parse(true)[1]:root()

  --- @param node TSNode
  --- @return nvim.util.MDNode?
  local function extract(node)
    local ntype = node:type()

    if ntype:match('^%p$') then
      return
    end

    --- @type table<any,any>
    local ret = { type = ntype }
    ret.text = vim.treesitter.get_node_text(node, text)

    local row, col = 0, 0

    for child, child_field in node:iter_children() do
      local e = extract(child)
      if e and ntype == 'inline' then
        local srow, scol = child:start()
        if (srow == row and scol > col) or srow > row then
          local t = slice_text(ret.text, row, col, srow, scol)
          if t and t ~= '' then
            table.insert(ret, { type = 'text', j = true, text = t })
          end
        end
        row, col = child:end_()
      end

      if child_field then
        ret[child_field] = e
      else
        table.insert(ret, e)
      end
    end

    if ntype == 'inline' and (row > 0 or col > 0) then
      local t = slice_text(ret.text, row, col)
      if t and t ~= '' then
        table.insert(ret, { type = 'text', text = t })
      end
    end

    return ret
  end

  return extract(root) or {}
end

--- @param text string
--- @return nvim.util.MDNode
local function parse_md(text)
  local parser = vim.treesitter.languagetree.new(text, 'markdown', {
    injections = { markdown = '' },
  })

  local root = parser:parse(true)[1]:root()

  local EXCLUDE_TEXT_TYPE = {
    list = true,
    list_item = true,
    section = true,
    document = true,
    fenced_code_block = true,
    fenced_code_block_delimiter = true,
  }

  --- @param node TSNode
  --- @return nvim.util.MDNode?
  local function extract(node)
    local ntype = node:type()

    if ntype:match('^%p$') or contains(ntype, { 'block_continuation' }) then
      return
    end

    --- @type table<any,any>
    local ret = { type = ntype }

    if not EXCLUDE_TEXT_TYPE[ntype] then
      ret.text = vim.treesitter.get_node_text(node, text)
    end

    if ntype == 'inline' then
      ret = parse_md_inline(ret.text)
    end

    for child, child_field in node:iter_children() do
      local e = extract(child)
      if child_field then
        ret[child_field] = e
      else
        table.insert(ret, e)
      end
    end

    return ret
  end

  return extract(root) or {}
end

--- Prefixes each line in `text`.
---
--- Does not wrap, not important for "meta" files? (You probably want md_to_vimdoc instead.)
---
--- @param text string
--- @param prefix_ string
function M.prefix_lines(prefix_, text)
  local r = ''
  for _, l in ipairs(vim.split(text, '\n', { plain = true })) do
    r = r .. vim.trim(prefix_ .. l) .. '\n'
  end
  return r
end

--- @param x string
--- @param start_indent integer
--- @param indent integer
--- @param text_width integer
--- @return string
function M.wrap(x, start_indent, indent, text_width)
  local words = vim.split(vim.trim(x), '%s+')
  local parts = { string.rep(' ', start_indent) } --- @type string[]
  local count = indent

  for i, w in ipairs(words) do
    if count > indent and count + #w > text_width - 1 then
      parts[#parts + 1] = '\n'
      parts[#parts + 1] = string.rep(' ', indent)
      count = indent
    elseif i ~= 1 then
      parts[#parts + 1] = ' '
      count = count + 1
    end
    count = count + #w
    parts[#parts + 1] = w
  end

  return (table.concat(parts):gsub('%s+\n', '\n'):gsub('\n+$', ''))
end

--- @param node nvim.util.MDNode
--- @param start_indent integer
--- @param indent integer
--- @param text_width integer
--- @param level integer
--- @return string[]
local function render_md(node, start_indent, indent, text_width, level, is_list)
  local parts = {} --- @type string[]

  -- For debugging
  local add_tag = false
  -- local add_tag = true

  local ntype = node.type

  if add_tag then
    parts[#parts + 1] = '<' .. ntype .. '>'
  end

  if ntype == 'text' then
    parts[#parts + 1] = node.text
  elseif ntype == 'html_tag' then
    error('html_tag: ' .. node.text)
  elseif ntype == 'inline_link' then
    vim.list_extend(parts, { '*', node[1].text, '*' })
  elseif ntype == 'shortcut_link' then
    if node[1].text:find('^<.*>$') then
      parts[#parts + 1] = node[1].text
    elseif node[1].text:find('^%d+$') then
      vim.list_extend(parts, { '[', node[1].text, ']' })
    else
      vim.list_extend(parts, { '|', node[1].text, '|' })
    end
  elseif ntype == 'backslash_escape' then
    parts[#parts + 1] = node.text
  elseif ntype == 'emphasis' then
    parts[#parts + 1] = node.text:sub(2, -2)
  elseif ntype == 'code_span' then
    vim.list_extend(parts, { '`', node.text:sub(2, -2):gsub(' ', NBSP), '`' })
  elseif ntype == 'inline' then
    if #node == 0 then
      local text = assert(node.text)
      parts[#parts + 1] = M.wrap(text, start_indent, indent, text_width)
    else
      for _, child in ipairs(node) do
        vim.list_extend(parts, render_md(child, start_indent, indent, text_width, level + 1))
      end
    end
  elseif ntype == 'paragraph' then
    local pparts = {}
    for _, child in ipairs(node) do
      vim.list_extend(pparts, render_md(child, start_indent, indent, text_width, level + 1))
    end
    parts[#parts + 1] = M.wrap(table.concat(pparts), start_indent, indent, text_width)
    parts[#parts + 1] = '\n'
  elseif ntype == 'code_fence_content' then
    local lines = vim.split(node.text:gsub('\n%s*$', ''), '\n')

    local cindent = indent + INDENTATION
    if level > 3 then
      -- The tree-sitter markdown parser doesn't parse the code blocks indents
      -- correctly in lists. Fudge it!
      lines[1] = '    ' .. lines[1] -- ¯\_(ツ)_/¯
      cindent = indent - level
      local _, initial_indent = lines[1]:find('^%s*')
      initial_indent = initial_indent + cindent
      if initial_indent < indent then
        cindent = indent - INDENTATION
      end
    end

    for _, l in ipairs(lines) do
      if #l > 0 then
        parts[#parts + 1] = string.rep(' ', cindent)
        parts[#parts + 1] = l
      end
      parts[#parts + 1] = '\n'
    end
  elseif ntype == 'fenced_code_block' then
    parts[#parts + 1] = '>'
    for _, child in ipairs(node) do
      if child.type == 'info_string' then
        parts[#parts + 1] = child.text
        break
      end
    end
    parts[#parts + 1] = '\n'
    for _, child in ipairs(node) do
      if child.type ~= 'info_string' then
        vim.list_extend(parts, render_md(child, start_indent, indent, text_width, level + 1))
      end
    end
    parts[#parts + 1] = '<\n'
  elseif ntype == 'html_block' then
    local text = node.text:gsub('^<pre>help', '')
    text = text:gsub('</pre>%s*$', '')
    parts[#parts + 1] = text
  elseif ntype == 'list_marker_dot' then
    parts[#parts + 1] = node.text
  elseif contains(ntype, { 'list_marker_minus', 'list_marker_star' }) then
    parts[#parts + 1] = '• '
  elseif ntype == 'list_item' then
    parts[#parts + 1] = string.rep(' ', indent)
    local offset = node[1].type == 'list_marker_dot' and 3 or 2
    for i, child in ipairs(node) do
      local sindent = i <= 2 and 0 or (indent + offset)
      vim.list_extend(
        parts,
        render_md(child, sindent, indent + offset, text_width, level + 1, true)
      )
    end
  else
    if node.text then
      error(fmt('cannot render:\n%s', vim.inspect(node)))
    end
    for i, child in ipairs(node) do
      local start_indent0 = i == 1 and start_indent or indent
      vim.list_extend(
        parts,
        render_md(child, start_indent0, indent, text_width, level + 1, is_list)
      )
      if ntype ~= 'list' and i ~= #node then
        if (node[i + 1] or {}).type ~= 'list' then
          parts[#parts + 1] = '\n'
        end
      end
    end
  end

  if add_tag then
    parts[#parts + 1] = '</' .. ntype .. '>'
  end

  return parts
end

--- @param text_width integer
local function align_tags(text_width)
  --- @param line string
  --- @return string
  return function(line)
    local tag_pat = '%s*(%*.+%*)%s*$'
    local tags = {}
    for m in line:gmatch(tag_pat) do
      table.insert(tags, m)
    end

    if #tags > 0 then
      line = line:gsub(tag_pat, '')
      local tags_str = ' ' .. table.concat(tags, ' ')
      --- @type integer
      local conceal_offset = select(2, tags_str:gsub('%*', '')) - 2
      local pad = string.rep(' ', text_width - #line - #tags_str + conceal_offset)
      return line .. pad .. tags_str
    end

    return line
  end
end

--- @param text string
--- @param start_indent integer
--- @param indent integer
--- @param is_list? boolean
--- @return string
function M.md_to_vimdoc(text, start_indent, indent, text_width, is_list)
  -- Add an extra newline so the parser can properly capture ending ```
  local parsed = parse_md(text .. '\n')
  local ret = render_md(parsed, start_indent, indent, text_width, 0, is_list)

  local lines = vim.split(table.concat(ret):gsub(NBSP, ' '), '\n')

  lines = vim.tbl_map(align_tags(text_width), lines)

  local s = table.concat(lines, '\n')

  -- Reduce whitespace in code-blocks
  s = s:gsub('\n+%s*>([a-z]+)\n', ' >%1\n')
  s = s:gsub('\n+%s*>\n?\n', ' >\n')

  return s
end

return M
