--- @brief
---<pre>help
---:[range]TOhtml {file}                                                *:TOhtml*
---Converts the buffer shown in the current window to HTML, opens the generated
---HTML in a new split window, and saves its contents to {file}. If {file} is not
---given, a temporary file (created by |tempname()|) is used.
---</pre>

-- The HTML conversion script is different from Vim's one. If you want to use
-- Vim's TOhtml converter, download it from the vim GitHub repo.
-- Here are the Vim files related to this functionality:
-- - https://github.com/vim/vim/blob/master/runtime/syntax/2html.vim
-- - https://github.com/vim/vim/blob/master/runtime/autoload/tohtml.vim
-- - https://github.com/vim/vim/blob/master/runtime/plugin/tohtml.vim
--
-- Main differences between this and the vim version:
-- - No "ignore some visual thing" settings (just set the right Vim option)
-- - No support for legacy web engines
-- - No support for legacy encoding (supports only UTF-8)
-- - No interactive webpage
-- - No specifying the internal HTML (no XHTML, no use_css=false)
-- - No multiwindow diffs
-- - No ranges
--
-- Remarks:
-- - Not all visuals are supported, so it may differ.

--- @class (private) vim.tohtml.state.global
--- @field background string
--- @field foreground string
--- @field title string|false
--- @field font string
--- @field highlights_name table<integer,string>
--- @field conf vim.tohtml.opt

--- @class (private) vim.tohtml.state:vim.tohtml.state.global
--- @field style vim.tohtml.styletable
--- @field tabstop string|false
--- @field opt vim.wo
--- @field winid integer
--- @field bufnr integer
--- @field width integer
--- @field start integer
--- @field end_ integer

--- @class (private) vim.tohtml.styletable
--- @field [integer] vim.tohtml.line (integer: (1-index, exclusive))

--- @class (private) vim.tohtml.line
--- @field virt_lines {[integer]:[string,integer][]}
--- @field pre_text string[][]
--- @field hide? boolean
--- @field [integer] vim.tohtml.cell? (integer: (1-index, exclusive))

--- @class (private) vim.tohtml.cell
--- @field [1] integer[] start
--- @field [2] integer[] close
--- @field [3] any[][] virt_text
--- @field [4] any[][] overlay_text

--- @type string[]
local notifications = {}

---@param msg string
local function notify(msg)
  if #notifications == 0 then
    vim.schedule(function()
      if #notifications > 1 then
        vim.notify(('TOhtml: %s (+ %d more warnings)'):format(notifications[1], #notifications - 1))
      elseif #notifications == 1 then
        vim.notify('TOhtml: ' .. notifications[1])
      end
      notifications = {}
    end)
  end
  table.insert(notifications, msg)
end

local HIDE_ID = -1
-- stylua: ignore start
local cterm_8_to_hex={
  [0] = "#808080", "#ff6060", "#00ff00", "#ffff00",
  "#8080ff", "#ff40ff", "#00ffff", "#ffffff",
}
local cterm_16_to_hex={
  [0] = "#000000", "#c00000", "#008000", "#804000",
  "#0000c0", "#c000c0", "#008080", "#c0c0c0",
  "#808080", "#ff6060", "#00ff00", "#ffff00",
  "#8080ff", "#ff40ff", "#00ffff", "#ffffff",
}
local cterm_88_to_hex={
  [0] = "#000000", "#c00000", "#008000", "#804000",
  "#0000c0", "#c000c0", "#008080", "#c0c0c0",
  "#808080", "#ff6060", "#00ff00", "#ffff00",
  "#8080ff", "#ff40ff", "#00ffff", "#ffffff",
  "#000000", "#00008b", "#0000cd", "#0000ff",
  "#008b00", "#008b8b", "#008bcd", "#008bff",
  "#00cd00", "#00cd8b", "#00cdcd", "#00cdff",
  "#00ff00", "#00ff8b", "#00ffcd", "#00ffff",
  "#8b0000", "#8b008b", "#8b00cd", "#8b00ff",
  "#8b8b00", "#8b8b8b", "#8b8bcd", "#8b8bff",
  "#8bcd00", "#8bcd8b", "#8bcdcd", "#8bcdff",
  "#8bff00", "#8bff8b", "#8bffcd", "#8bffff",
  "#cd0000", "#cd008b", "#cd00cd", "#cd00ff",
  "#cd8b00", "#cd8b8b", "#cd8bcd", "#cd8bff",
  "#cdcd00", "#cdcd8b", "#cdcdcd", "#cdcdff",
  "#cdff00", "#cdff8b", "#cdffcd", "#cdffff",
  "#ff0000", "#ff008b", "#ff00cd", "#ff00ff",
  "#ff8b00", "#ff8b8b", "#ff8bcd", "#ff8bff",
  "#ffcd00", "#ffcd8b", "#ffcdcd", "#ffcdff",
  "#ffff00", "#ffff8b", "#ffffcd", "#ffffff",
  "#2e2e2e", "#5c5c5c", "#737373", "#8b8b8b",
  "#a2a2a2", "#b9b9b9", "#d0d0d0", "#e7e7e7",
}
local cterm_256_to_hex={
  [0] = "#000000", "#c00000", "#008000", "#804000",
  "#0000c0", "#c000c0", "#008080", "#c0c0c0",
  "#808080", "#ff6060", "#00ff00", "#ffff00",
  "#8080ff", "#ff40ff", "#00ffff", "#ffffff",
  "#000000", "#00005f", "#000087", "#0000af",
  "#0000d7", "#0000ff", "#005f00", "#005f5f",
  "#005f87", "#005faf", "#005fd7", "#005fff",
  "#008700", "#00875f", "#008787", "#0087af",
  "#0087d7", "#0087ff", "#00af00", "#00af5f",
  "#00af87", "#00afaf", "#00afd7", "#00afff",
  "#00d700", "#00d75f", "#00d787", "#00d7af",
  "#00d7d7", "#00d7ff", "#00ff00", "#00ff5f",
  "#00ff87", "#00ffaf", "#00ffd7", "#00ffff",
  "#5f0000", "#5f005f", "#5f0087", "#5f00af",
  "#5f00d7", "#5f00ff", "#5f5f00", "#5f5f5f",
  "#5f5f87", "#5f5faf", "#5f5fd7", "#5f5fff",
  "#5f8700", "#5f875f", "#5f8787", "#5f87af",
  "#5f87d7", "#5f87ff", "#5faf00", "#5faf5f",
  "#5faf87", "#5fafaf", "#5fafd7", "#5fafff",
  "#5fd700", "#5fd75f", "#5fd787", "#5fd7af",
  "#5fd7d7", "#5fd7ff", "#5fff00", "#5fff5f",
  "#5fff87", "#5fffaf", "#5fffd7", "#5fffff",
  "#870000", "#87005f", "#870087", "#8700af",
  "#8700d7", "#8700ff", "#875f00", "#875f5f",
  "#875f87", "#875faf", "#875fd7", "#875fff",
  "#878700", "#87875f", "#878787", "#8787af",
  "#8787d7", "#8787ff", "#87af00", "#87af5f",
  "#87af87", "#87afaf", "#87afd7", "#87afff",
  "#87d700", "#87d75f", "#87d787", "#87d7af",
  "#87d7d7", "#87d7ff", "#87ff00", "#87ff5f",
  "#87ff87", "#87ffaf", "#87ffd7", "#87ffff",
  "#af0000", "#af005f", "#af0087", "#af00af",
  "#af00d7", "#af00ff", "#af5f00", "#af5f5f",
  "#af5f87", "#af5faf", "#af5fd7", "#af5fff",
  "#af8700", "#af875f", "#af8787", "#af87af",
  "#af87d7", "#af87ff", "#afaf00", "#afaf5f",
  "#afaf87", "#afafaf", "#afafd7", "#afafff",
  "#afd700", "#afd75f", "#afd787", "#afd7af",
  "#afd7d7", "#afd7ff", "#afff00", "#afff5f",
  "#afff87", "#afffaf", "#afffd7", "#afffff",
  "#d70000", "#d7005f", "#d70087", "#d700af",
  "#d700d7", "#d700ff", "#d75f00", "#d75f5f",
  "#d75f87", "#d75faf", "#d75fd7", "#d75fff",
  "#d78700", "#d7875f", "#d78787", "#d787af",
  "#d787d7", "#d787ff", "#d7af00", "#d7af5f",
  "#d7af87", "#d7afaf", "#d7afd7", "#d7afff",
  "#d7d700", "#d7d75f", "#d7d787", "#d7d7af",
  "#d7d7d7", "#d7d7ff", "#d7ff00", "#d7ff5f",
  "#d7ff87", "#d7ffaf", "#d7ffd7", "#d7ffff",
  "#ff0000", "#ff005f", "#ff0087", "#ff00af",
  "#ff00d7", "#ff00ff", "#ff5f00", "#ff5f5f",
  "#ff5f87", "#ff5faf", "#ff5fd7", "#ff5fff",
  "#ff8700", "#ff875f", "#ff8787", "#ff87af",
  "#ff87d7", "#ff87ff", "#ffaf00", "#ffaf5f",
  "#ffaf87", "#ffafaf", "#ffafd7", "#ffafff",
  "#ffd700", "#ffd75f", "#ffd787", "#ffd7af",
  "#ffd7d7", "#ffd7ff", "#ffff00", "#ffff5f",
  "#ffff87", "#ffffaf", "#ffffd7", "#ffffff",
  "#080808", "#121212", "#1c1c1c", "#262626",
  "#303030", "#3a3a3a", "#444444", "#4e4e4e",
  "#585858", "#626262", "#6c6c6c", "#767676",
  "#808080", "#8a8a8a", "#949494", "#9e9e9e",
  "#a8a8a8", "#b2b2b2", "#bcbcbc", "#c6c6c6",
  "#d0d0d0", "#dadada", "#e4e4e4", "#eeeeee",
}
-- stylua: ignore end

--- @type table<integer,string>
local cterm_color_cache = {}
--- @type string?
local background_color_cache = nil
--- @type string?
local foreground_color_cache = nil

local len = vim.api.nvim_strwidth

--- @see https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands
--- @param color "background"|"foreground"|integer
--- @return string?
local function try_query_terminal_color(color)
  local parameter = 4
  if color == 'foreground' then
    parameter = 10
  elseif color == 'background' then
    parameter = 11
  end
  --- @type string?
  local hex = nil
  local au = vim.api.nvim_create_autocmd('TermResponse', {
    once = true,
    callback = function(args)
      hex = '#'
        .. table.concat({ args.data:match('\027%]%d+;%d*;?rgb:(%w%w)%w%w/(%w%w)%w%w/(%w%w)%w%w') })
    end,
  })
  if type(color) == 'number' then
    io.stdout:write(('\027]%s;%s;?\027\\'):format(parameter, color))
  else
    io.stdout:write(('\027]%s;?\027\\'):format(parameter))
  end
  vim.wait(100, function()
    return hex and true or false
  end)
  pcall(vim.api.nvim_del_autocmd, au)
  return hex
end

--- @param colorstr string
--- @return string
local function cterm_to_hex(colorstr)
  if colorstr:sub(1, 1) == '#' then
    return colorstr
  end
  assert(colorstr ~= '')
  local color = tonumber(colorstr)
  assert(color and 0 <= color and color <= 255)
  if cterm_color_cache[color] then
    return cterm_color_cache[color]
  end
  local hex = try_query_terminal_color(color)
  if hex then
    cterm_color_cache[color] = hex
  else
    notify("Couldn't get terminal colors, using fallback")
    local t_Co = tonumber(vim.api.nvim_eval('&t_Co'))
    if t_Co <= 8 then
      cterm_color_cache = cterm_8_to_hex
    elseif t_Co == 88 then
      cterm_color_cache = cterm_88_to_hex
    elseif t_Co == 256 then
      cterm_color_cache = cterm_256_to_hex
    else
      cterm_color_cache = cterm_16_to_hex
    end
  end
  return cterm_color_cache[color]
end

--- @return string
local function get_background_color()
  local bg = vim.fn.synIDattr(vim.fn.hlID('Normal'), 'bg#')
  if bg ~= '' then
    return cterm_to_hex(bg)
  end
  if background_color_cache then
    return background_color_cache
  end
  local hex = try_query_terminal_color('background')
  if not hex or not hex:match('#%x%x%x%x%x%x') then
    notify("Couldn't get terminal background colors, using fallback")
    hex = vim.o.background == 'light' and '#ffffff' or '#000000'
  end
  background_color_cache = hex
  return hex
end

--- @return string
local function get_foreground_color()
  local fg = vim.fn.synIDattr(vim.fn.hlID('Normal'), 'fg#')
  if fg ~= '' then
    return cterm_to_hex(fg)
  end
  if foreground_color_cache then
    return foreground_color_cache
  end
  local hex = try_query_terminal_color('foreground')
  if not hex or not hex:match('#%x%x%x%x%x%x') then
    notify("Couldn't get terminal foreground colors, using fallback")
    hex = vim.o.background == 'light' and '#000000' or '#ffffff'
  end
  foreground_color_cache = hex
  return hex
end

--- @param style_line vim.tohtml.line
--- @param col integer (1-index)
--- @param field integer
--- @param val any
local function _style_line_insert(style_line, col, field, val)
  if style_line[col] == nil then
    style_line[col] = { {}, {}, {}, {} }
  end
  table.insert(style_line[col][field], val)
end

--- @param style_line vim.tohtml.line
--- @param col integer (1-index)
--- @param val any[]
local function style_line_insert_overlay_char(style_line, col, val)
  _style_line_insert(style_line, col, 4, val)
end

--- @param style_line vim.tohtml.line
--- @param col integer (1-index)
--- @param val any[]
local function style_line_insert_virt_text(style_line, col, val)
  _style_line_insert(style_line, col, 3, val)
end

--- @param state vim.tohtml.state
--- @param hl string|integer|string[]|integer[]?
--- @return nil|integer
local function register_hl(state, hl)
  if type(hl) == 'table' then
    hl = hl[#hl]
  end
  if type(hl) == 'nil' then
    return
  elseif type(hl) == 'string' then
    hl = vim.fn.hlID(hl)
    assert(hl ~= 0)
  end
  hl = vim.fn.synIDtrans(hl)
  if not state.highlights_name[hl] then
    local name = vim.fn.synIDattr(hl, 'name')
    assert(name ~= '')
    state.highlights_name[hl] = name
  end
  return hl
end

--- @param state vim.tohtml.state
--- @param start_row integer (1-index)
--- @param start_col integer (1-index)
--- @param end_row integer (1-index)
--- @param end_col integer (1-index)
--- @param conceal_text string
--- @param hl_group string|integer?
local function styletable_insert_conceal(
  state,
  start_row,
  start_col,
  end_row,
  end_col,
  conceal_text,
  hl_group
)
  assert(state.opt.conceallevel > 0)
  local styletable = state.style
  if start_col == end_col and start_row == end_row then
    return
  end
  if state.opt.conceallevel == 1 and conceal_text == '' then
    conceal_text = vim.opt_local.listchars:get().conceal or ' '
  end
  local hlid = register_hl(state, hl_group)
  if vim.wo[state.winid].conceallevel ~= 3 then
    _style_line_insert(styletable[start_row], start_col, 3, { conceal_text, hlid })
  end
  _style_line_insert(styletable[start_row], start_col, 1, HIDE_ID)
  _style_line_insert(styletable[end_row], end_col, 2, HIDE_ID)
end

--- @param state vim.tohtml.state
--- @param start_row integer (1-index)
--- @param start_col integer (1-index)
--- @param end_row integer (1-index)
--- @param end_col integer (1-index)
--- @param hl_group string|integer|nil
local function styletable_insert_range(state, start_row, start_col, end_row, end_col, hl_group)
  if start_col == end_col and start_row == end_row or not hl_group then
    return
  end
  local styletable = state.style
  _style_line_insert(styletable[start_row], start_col, 1, hl_group)
  _style_line_insert(styletable[end_row], end_col, 2, hl_group)
end

--- @param bufnr integer
--- @return vim.tohtml.styletable
local function generate_styletable(bufnr)
  --- @type vim.tohtml.styletable
  local styletable = {}
  for row = 1, vim.api.nvim_buf_line_count(bufnr) + 1 do
    styletable[row] = { virt_lines = {}, pre_text = {} }
  end
  return styletable
end

--- @param state vim.tohtml.state
local function styletable_syntax(state)
  for row = state.start, state.end_ do
    local prev_id = 0
    local prev_col = nil
    for col = 1, #vim.fn.getline(row) + 1 do
      local hlid = vim.fn.synID(row, col, 1)
      hlid = hlid == 0 and 0 or assert(register_hl(state, hlid))
      if hlid ~= prev_id then
        if prev_id ~= 0 then
          styletable_insert_range(state, row, assert(prev_col), row, col, prev_id)
        end
        prev_col = col
        prev_id = hlid
      end
    end
  end
end

--- @param state vim.tohtml.state
local function styletable_diff(state)
  local styletable = state.style
  for row = state.start, state.end_ do
    local style_line = styletable[row]
    local filler = vim.fn.diff_filler(row)
    if filler ~= 0 then
      local fill = (vim.opt_local.fillchars:get().diff or '-')
      table.insert(
        style_line.virt_lines,
        { { fill:rep(state.width), register_hl(state, 'DiffDelete') } }
      )
    end
    if row == state.end_ + 1 then
      break
    end
    local prev_id = 0
    local prev_col = nil
    for col = 1, #vim.fn.getline(row) do
      local hlid = vim.fn.diff_hlID(row, col)
      hlid = hlid == 0 and 0 or assert(register_hl(state, hlid))
      if hlid ~= prev_id then
        if prev_id ~= 0 then
          styletable_insert_range(state, row, assert(prev_col), row, col, prev_id)
        end
        prev_col = col
        prev_id = hlid
      end
    end
    if prev_id ~= 0 then
      styletable_insert_range(state, row, assert(prev_col), row, #vim.fn.getline(row) + 1, prev_id)
    end
  end
end

--- @param state vim.tohtml.state
local function styletable_treesitter(state)
  local bufnr = state.bufnr
  local buf_highlighter = vim.treesitter.highlighter.active[bufnr]
  if not buf_highlighter then
    return
  end
  buf_highlighter.tree:parse(true)
  buf_highlighter.tree:for_each_tree(function(tstree, tree)
    --- @cast tree vim.treesitter.LanguageTree
    if not tstree then
      return
    end
    local root = tstree:root()
    local q = buf_highlighter:get_query(tree:lang())
    --- @type vim.treesitter.Query?
    local query = q:query()
    if not query then
      return
    end
    for capture, node, metadata in
      query:iter_captures(root, buf_highlighter.bufnr, state.start - 1, state.end_)
    do
      local srow, scol, erow, ecol = node:range()
      --- @diagnostic disable-next-line: invisible
      local c = q._query.captures[capture]
      if c ~= nil then
        local hlid = register_hl(state, '@' .. c .. '.' .. tree:lang())
        if metadata.conceal and state.opt.conceallevel ~= 0 then
          styletable_insert_conceal(state, srow + 1, scol + 1, erow + 1, ecol + 1, metadata.conceal)
        end
        styletable_insert_range(state, srow + 1, scol + 1, erow + 1, ecol + 1, hlid)
      end
    end
  end)
end

--- @param state vim.tohtml.state
--- @param extmark [integer, integer, integer, vim.api.keyset.set_extmark|any]
--- @param namespaces table<integer,string>
local function _styletable_extmarks_highlight(state, extmark, namespaces)
  if not extmark[4].hl_group then
    return
  end
  ---TODO(altermo) LSP semantic tokens (and some other extmarks) are only
  ---generated in visible lines, and not in the whole buffer.
  if (namespaces[extmark[4].ns_id] or ''):find('vim_lsp_semantic_tokens') then
    notify('lsp semantic tokens are not supported, HTML may be incorrect')
    return
  end
  local srow, scol, erow, ecol =
    extmark[2], extmark[3], extmark[4].end_row or extmark[2], extmark[4].end_col or extmark[3]
  if scol == ecol and srow == erow then
    return
  end
  local hlid = register_hl(state, extmark[4].hl_group)
  styletable_insert_range(state, srow + 1, scol + 1, erow + 1, ecol + 1, hlid)
end

--- @param state vim.tohtml.state
--- @param extmark [integer, integer, integer, vim.api.keyset.set_extmark|any]
--- @param namespaces table<integer,string>
local function _styletable_extmarks_virt_text(state, extmark, namespaces)
  if not extmark[4].virt_text then
    return
  end
  ---TODO(altermo) LSP semantic tokens (and some other extmarks) are only
  ---generated in visible lines, and not in the whole buffer.
  if (namespaces[extmark[4].ns_id] or ''):find('vim_lsp_inlayhint') then
    notify('lsp inlay hints are not supported, HTML may be incorrect')
    return
  end
  local styletable = state.style
  --- @type integer,integer
  local row, col = extmark[2], extmark[3]
  if
    row < vim.api.nvim_buf_line_count(state.bufnr)
    and (
      extmark[4].virt_text_pos == 'inline'
      or extmark[4].virt_text_pos == 'eol'
      or extmark[4].virt_text_pos == 'overlay'
    )
  then
    if extmark[4].virt_text_pos == 'eol' then
      style_line_insert_virt_text(styletable[row + 1], #vim.fn.getline(row + 1) + 1, { ' ' })
    end
    local virt_text_len = 0
    for _, i in
      ipairs(extmark[4].virt_text --[[@as (string[][])]])
    do
      local hlid = register_hl(state, i[2])
      if extmark[4].virt_text_pos == 'eol' then
        style_line_insert_virt_text(
          styletable[row + 1],
          #vim.fn.getline(row + 1) + 1,
          { i[1], hlid }
        )
      else
        style_line_insert_virt_text(styletable[row + 1], col + 1, { i[1], hlid })
      end
      virt_text_len = virt_text_len + len(i[1])
    end
    if extmark[4].virt_text_pos == 'overlay' then
      styletable_insert_range(state, row + 1, col + 1, row + 1, col + virt_text_len + 1, HIDE_ID)
    end
  end
  local not_supported = {
    virt_text_pos = 'right_align',
    hl_mode = 'blend',
    hl_group = 'combine',
  }
  for opt, val in pairs(not_supported) do
    if extmark[4][opt] == val then
      notify(('extmark.%s="%s" is not supported, HTML may be incorrect'):format(opt, val))
    end
  end
end

--- @param state vim.tohtml.state
--- @param extmark [integer, integer, integer, vim.api.keyset.set_extmark|any]
local function _styletable_extmarks_virt_lines(state, extmark)
  ---TODO(altermo) if the fold start is equal to virt_line start then the fold hides the virt_line
  if not extmark[4].virt_lines then
    return
  end
  --- @type integer
  local row = extmark[2] + (extmark[4].virt_lines_above and 1 or 2)
  for _, line in
    ipairs(extmark[4].virt_lines --[[@as (string[][][])]])
  do
    local virt_line = {}
    for _, i in ipairs(line) do
      local hlid = register_hl(state, i[2])
      table.insert(virt_line, { i[1], hlid })
    end
    table.insert(state.style[row].virt_lines, virt_line)
  end
end

--- @param state vim.tohtml.state
--- @param extmark [integer, integer, integer, vim.api.keyset.set_extmark|any]
local function _styletable_extmarks_conceal(state, extmark)
  if not extmark[4].conceal or state.opt.conceallevel == 0 then
    return
  end
  local srow, scol, erow, ecol =
    extmark[2], extmark[3], extmark[4].end_row or extmark[2], extmark[4].end_col or extmark[3]
  styletable_insert_conceal(
    state,
    srow + 1,
    scol + 1,
    erow + 1,
    ecol + 1,
    extmark[4].conceal,
    extmark[4].hl_group or 'Conceal'
  )
end

--- @param state vim.tohtml.state
local function styletable_extmarks(state)
  --TODO(altermo) extmarks may have col/row which is outside of the buffer, which could cause an error
  local bufnr = state.bufnr
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })
  local namespaces = {} --- @type table<integer, string>
  for ns, ns_id in pairs(vim.api.nvim_get_namespaces()) do
    namespaces[ns_id] = ns
  end
  for _, v in ipairs(extmarks) do
    _styletable_extmarks_highlight(state, v, namespaces)
  end
  for _, v in ipairs(extmarks) do
    _styletable_extmarks_conceal(state, v)
  end
  for _, v in ipairs(extmarks) do
    _styletable_extmarks_virt_text(state, v, namespaces)
  end
  for _, v in ipairs(extmarks) do
    _styletable_extmarks_virt_lines(state, v)
  end
end

--- @param state vim.tohtml.state
local function styletable_folds(state)
  local styletable = state.style
  local has_folded = false
  for row = state.start, state.end_ do
    if vim.fn.foldclosed(row) > 0 then
      has_folded = true
      styletable[row].hide = true
    end
    if vim.fn.foldclosed(row) == row then
      local hlid = register_hl(state, 'Folded')
      ---TODO(altermo): Is there a way to get highlighted foldtext?
      local foldtext = vim.fn.foldtextresult(row)
      foldtext = foldtext .. (vim.opt.fillchars:get().fold or '·'):rep(state.width - #foldtext)
      table.insert(styletable[row].virt_lines, { { foldtext, hlid } })
    end
  end
  if has_folded and type(({ pcall(vim.api.nvim_eval, vim.o.foldtext) })[2]) == 'table' then
    notify('foldtext returning a table with highlights is not supported, HTML may be incorrect')
  end
end

--- @param state vim.tohtml.state
local function styletable_conceal(state)
  local bufnr = state.bufnr
  vim._with({ buf = bufnr }, function()
    for row = state.start, state.end_ do
      --- @type table<integer,[integer,integer,string]>
      local conceals = {}
      local line_len_exclusive = #vim.fn.getline(row) + 1
      for col = 1, line_len_exclusive do
        --- @type integer,string,integer
        local is_concealed, conceal, hlid = unpack(vim.fn.synconcealed(row, col) --[[@as table]])
        if is_concealed == 0 then
          assert(true)
        elseif not conceals[hlid] then
          conceals[hlid] = { col, math.min(col + 1, line_len_exclusive), conceal }
        else
          conceals[hlid][2] = math.min(col + 1, line_len_exclusive)
        end
      end
      for _, v in pairs(conceals) do
        styletable_insert_conceal(state, row, v[1], row, v[2], v[3], 'Conceal')
      end
    end
  end)
end

--- @param state vim.tohtml.state
local function styletable_match(state)
  for _, match in
    ipairs(vim.fn.getmatches(state.winid) --[[@as (table[])]])
  do
    local hlid = register_hl(state, match.group)
    local function range(srow, scol, erow, ecol)
      if match.group == 'Conceal' and state.opt.conceallevel ~= 0 then
        styletable_insert_conceal(state, srow, scol, erow, ecol, match.conceal or '', hlid)
      else
        styletable_insert_range(state, srow, scol, erow, ecol, hlid)
      end
    end
    if match.pos1 then
      for key, v in
        pairs(match --[[@as (table<string,integer[]>)]])
      do
        if not key:match('^pos(%d+)$') then
          assert(true)
        elseif #v == 1 then
          range(v[1], 1, v[1], #vim.fn.getline(v[1]) + 1)
        else
          range(v[1], v[2], v[1], v[3] + v[2])
        end
      end
    else
      for _, v in
        ipairs(vim.fn.matchbufline(state.bufnr, match.pattern, 1, '$') --[[@as (table[])]])
      do
        range(v.lnum, v.byteidx + 1, v.lnum, v.byteidx + 1 + #v.text)
      end
    end
  end
end

--- Requires state.conf.number_lines to be set to true
--- @param state vim.tohtml.state
local function styletable_statuscolumn(state)
  if not state.conf.number_lines then
    return
  end
  local statuscolumn = state.opt.statuscolumn

  if statuscolumn == '' then
    if state.opt.relativenumber then
      if state.opt.number then
        statuscolumn = '%C%s%{%v:lnum!=line(".")?"%=".v:relnum." ":v:lnum%}'
      else
        statuscolumn = '%C%s%{%"%=".v:relnum." "%}'
      end
    else
      statuscolumn = '%C%s%{%"%=".v:lnum." "%}'
    end
  end
  local minwidth = 0

  local signcolumn = state.opt.signcolumn
  if state.opt.number or state.opt.relativenumber then
    minwidth = minwidth + state.opt.numberwidth
    if signcolumn == 'number' then
      signcolumn = 'no'
    end
  end
  if signcolumn == 'number' then
    signcolumn = 'auto'
  end
  if signcolumn ~= 'no' then
    local max = tonumber(signcolumn:match('^%w-:(%d)')) or 1
    if signcolumn:match('^auto') then
      --- @type table<integer,integer>
      local signcount = {}
      for _, extmark in
        ipairs(vim.api.nvim_buf_get_extmarks(state.bufnr, -1, 0, -1, { details = true }))
      do
        if extmark[4].sign_text then
          signcount[extmark[2]] = (signcount[extmark[2]] or 0) + 1
        end
      end
      local maxsigns = 0
      for _, v in pairs(signcount) do
        if v > maxsigns then
          maxsigns = v
        end
      end
      minwidth = minwidth + math.min(maxsigns, max) * 2
    else
      minwidth = minwidth + max * 2
    end
  end

  local foldcolumn = state.opt.foldcolumn
  if foldcolumn ~= '0' then
    if foldcolumn:match('^auto') then
      local max = tonumber(foldcolumn:match('^%w-:(%d)')) or 1
      local maxfold = 0
      vim._with({ buf = state.bufnr }, function()
        for row = state.start, state.end_ do
          local foldlevel = vim.fn.foldlevel(row)
          if foldlevel > maxfold then
            maxfold = foldlevel
          end
        end
      end)
      minwidth = minwidth + math.min(maxfold, max)
    else
      minwidth = minwidth + tonumber(foldcolumn)
    end
  end

  --- @type table<integer,any>
  local statuses = {}
  for row = state.start, state.end_ do
    local status = vim.api.nvim_eval_statusline(
      statuscolumn,
      { winid = state.winid, use_statuscol_lnum = row, highlights = true }
    )
    local width = len(status.str)
    if width > minwidth then
      minwidth = width
    end
    table.insert(statuses, status)
    --- @type string
  end
  for row, status in pairs(statuses) do
    --- @type string
    local str = status.str
    --- @type table[]
    local hls = status.highlights
    for k, v in ipairs(hls) do
      local text = str:sub(v.start + 1, hls[k + 1] and hls[k + 1].start or nil)
      if k == #hls then
        text = text .. (' '):rep(minwidth - len(str))
      end
      if text ~= '' then
        local hlid = register_hl(state, v.group)
        local virt_text = { text, hlid }
        table.insert(state.style[row].pre_text, virt_text)
      end
    end
  end
end

--- @param state vim.tohtml.state
local function styletable_listchars(state)
  if not state.opt.list then
    return
  end
  --- @return string
  local function utf8_sub(str, i, j)
    return vim.fn.strcharpart(str, i - 1, j and j - i + 1 or nil)
  end
  --- @type table<string,string>
  local listchars = vim.opt_local.listchars:get()
  local ids = setmetatable({}, {
    __index = function(t, k)
      rawset(t, k, register_hl(state, k))
      return rawget(t, k)
    end,
  })

  if listchars.eol then
    for row = state.start, state.end_ do
      local style_line = state.style[row]
      style_line_insert_overlay_char(
        style_line,
        #vim.fn.getline(row) + 1,
        { listchars.eol, ids.NonText }
      )
    end
  end

  if listchars.tab and state.tabstop then
    for _, match in
      ipairs(vim.fn.matchbufline(state.bufnr, '\t', 1, '$') --[[@as (table[])]])
    do
      --- @type integer
      local tablen = #state.tabstop
        - ((vim.fn.virtcol({ match.lnum, match.byteidx }, false, state.winid)) % #state.tabstop)
      --- @type string?
      local text
      if len(listchars.tab) == 3 then
        if tablen == 1 then
          text = utf8_sub(listchars.tab, 3, 3)
        else
          text = utf8_sub(listchars.tab, 1, 1)
            .. utf8_sub(listchars.tab, 2, 2):rep(tablen - 2)
            .. utf8_sub(listchars.tab, 3, 3)
        end
      else
        text = utf8_sub(listchars.tab, 1, 1) .. utf8_sub(listchars.tab, 2, 2):rep(tablen - 1)
      end
      style_line_insert_overlay_char(
        state.style[match.lnum],
        match.byteidx + 1,
        { text, ids.Whitespace }
      )
    end
  end

  if listchars.space then
    for _, match in
      ipairs(vim.fn.matchbufline(state.bufnr, ' ', 1, '$') --[[@as (table[])]])
    do
      style_line_insert_overlay_char(
        state.style[match.lnum],
        match.byteidx + 1,
        { listchars.space, ids.Whitespace }
      )
    end
  end

  if listchars.multispace then
    for _, match in
      ipairs(vim.fn.matchbufline(state.bufnr, [[  \+]], 1, '$') --[[@as (table[])]])
    do
      local text = utf8_sub(listchars.multispace:rep(len(match.text)), 1, len(match.text))
      for i = 1, len(text) do
        style_line_insert_overlay_char(
          state.style[match.lnum],
          match.byteidx + i,
          { utf8_sub(text, i, i), ids.Whitespace }
        )
      end
    end
  end

  if listchars.lead or listchars.leadmultispace then
    for _, match in
      ipairs(vim.fn.matchbufline(state.bufnr, [[^ \+]], 1, '$') --[[@as (table[])]])
    do
      local text = ''
      if len(match.text) == 1 or not listchars.leadmultispace then
        if listchars.lead then
          text = listchars.lead:rep(len(match.text))
        end
      elseif listchars.leadmultispace then
        text = utf8_sub(listchars.leadmultispace:rep(len(match.text)), 1, len(match.text))
      end
      for i = 1, len(text) do
        style_line_insert_overlay_char(
          state.style[match.lnum],
          match.byteidx + i,
          { utf8_sub(text, i, i), ids.Whitespace }
        )
      end
    end
  end

  if listchars.trail then
    for _, match in
      ipairs(vim.fn.matchbufline(state.bufnr, [[ \+$]], 1, '$') --[[@as (table[])]])
    do
      local text = listchars.trail:rep(len(match.text))
      for i = 1, len(text) do
        style_line_insert_overlay_char(
          state.style[match.lnum],
          match.byteidx + i,
          { utf8_sub(text, i, i), ids.Whitespace }
        )
      end
    end
  end

  if listchars.nbsp then
    for _, match in
      ipairs(
        vim.fn.matchbufline(state.bufnr, '\226\128\175\\|\194\160', 1, '$') --[[@as (table[])]]
      )
    do
      style_line_insert_overlay_char(
        state.style[match.lnum],
        match.byteidx + 1,
        { listchars.nbsp, ids.Whitespace }
      )
      for i = 2, #match.text do
        style_line_insert_overlay_char(
          state.style[match.lnum],
          match.byteidx + i,
          { '', ids.Whitespace }
        )
      end
    end
  end
end

--- @param name string
--- @return string
local function highlight_name_to_class_name(name)
  return (name:gsub('%.', '-'):gsub('@', '-'))
end

--- @param name string
--- @return string
local function name_to_tag(name)
  return '<span class="' .. highlight_name_to_class_name(name) .. '">'
end

--- @param _ string
--- @return string
local function name_to_closetag(_)
  return '</span>'
end

--- @param str string
--- @param tabstop string|false?
--- @return string
local function html_escape(str, tabstop)
  str = str:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;')
  if tabstop then
    --- @type string
    str = str:gsub('\t', tabstop)
  end
  return str
end

--- @param out string[]
--- @param state vim.tohtml.state.global
local function extend_style(out, state)
  table.insert(out, '<style>')
  table.insert(out, ('* {font-family: %s}'):format(state.font))
  table.insert(
    out,
    ('body {background-color: %s; color: %s}'):format(state.background, state.foreground)
  )
  for hlid, name in pairs(state.highlights_name) do
    --TODO(altermo) use local namespace (instead of global 0)
    local fg = vim.fn.synIDattr(hlid, 'fg#')
    local bg = vim.fn.synIDattr(hlid, 'bg#')
    local sp = vim.fn.synIDattr(hlid, 'sp#')
    local decor_line = {}
    if vim.fn.synIDattr(hlid, 'underline') ~= '' then
      table.insert(decor_line, 'underline')
    end
    if vim.fn.synIDattr(hlid, 'strikethrough') ~= '' then
      table.insert(decor_line, 'line-through')
    end
    if vim.fn.synIDattr(hlid, 'undercurl') ~= '' then
      table.insert(decor_line, 'underline')
    end
    local c = {
      color = fg ~= '' and cterm_to_hex(fg) or nil,
      ['background-color'] = bg ~= '' and cterm_to_hex(bg) or nil,
      ['font-style'] = vim.fn.synIDattr(hlid, 'italic') ~= '' and 'italic' or nil,
      ['font-weight'] = vim.fn.synIDattr(hlid, 'bold') ~= '' and 'bold' or nil,
      ['text-decoration-line'] = not vim.tbl_isempty(decor_line) and table.concat(decor_line, ' ')
        or nil,
      -- TODO(ribru17): fallback to displayed text color if sp not set
      ['text-decoration-color'] = sp ~= '' and cterm_to_hex(sp) or nil,
      --TODO(altermo) if strikethrough and undercurl then the strikethrough becomes wavy
      ['text-decoration-style'] = vim.fn.synIDattr(hlid, 'undercurl') ~= '' and 'wavy' or nil,
    }
    local attrs = {}
    for attr, val in pairs(c) do
      table.insert(attrs, attr .. ': ' .. val)
    end
    table.insert(
      out,
      '.' .. highlight_name_to_class_name(name) .. ' {' .. table.concat(attrs, '; ') .. '}'
    )
  end
  table.insert(out, '</style>')
end

--- @param out string[]
--- @param state vim.tohtml.state.global
local function extend_head(out, state)
  table.insert(out, '<head>')
  table.insert(out, '<meta charset="UTF-8">')
  if state.title ~= false then
    table.insert(out, ('<title>%s</title>'):format(state.title))
  end
  local colorscheme = vim.api.nvim_exec2('colorscheme', { output = true }).output
  table.insert(
    out,
    ('<meta name="colorscheme" content="%s"></meta>'):format(html_escape(colorscheme))
  )
  extend_style(out, state)
  table.insert(out, '</head>')
end

--- @param out string[]
--- @param state vim.tohtml.state
--- @param row integer
local function _extend_virt_lines(out, state, row)
  local style_line = state.style[row]
  for _, virt_line in ipairs(style_line.virt_lines) do
    local virt_s = ''
    for _, v in ipairs(virt_line) do
      if v[2] then
        virt_s = virt_s .. (name_to_tag(state.highlights_name[v[2]]))
      end
      virt_s = virt_s .. v[1]
      if v[2] then
        --- @type string
        virt_s = virt_s .. (name_to_closetag(state.highlights_name[v[2]]))
      end
    end
    table.insert(out, virt_s)
  end
end

--- @param state vim.tohtml.state
--- @param row integer
--- @return string
local function _pre_text_to_html(state, row)
  local style_line = state.style[row]
  local s = ''
  for _, pre_text in ipairs(style_line.pre_text) do
    if pre_text[2] then
      s = s .. (name_to_tag(state.highlights_name[pre_text[2]]))
    end
    s = s .. (html_escape(pre_text[1], state.tabstop))
    if pre_text[2] then
      --- @type string
      s = s .. (name_to_closetag(state.highlights_name[pre_text[2]]))
    end
  end
  return s
end

--- @param state vim.tohtml.state
--- @param char table
--- @return string
local function _char_to_html(state, char)
  local s = ''
  if char[2] then
    s = s .. name_to_tag(state.highlights_name[char[2]])
  end
  s = s .. html_escape(char[1], state.tabstop)
  if char[2] then
    s = s .. name_to_closetag(state.highlights_name[char[2]])
  end
  return s
end

--- @param state vim.tohtml.state
--- @param cell vim.tohtml.cell
--- @return string
local function _virt_text_to_html(state, cell)
  local s = ''
  for _, v in ipairs(cell[3]) do
    if v[2] then
      s = s .. (name_to_tag(state.highlights_name[v[2]]))
    end
    --- @type string
    s = s .. html_escape(v[1], state.tabstop)
    if v[2] then
      s = s .. name_to_closetag(state.highlights_name[v[2]])
    end
  end
  return s
end

--- @param out string[]
--- @param state vim.tohtml.state
local function extend_pre(out, state)
  local styletable = state.style
  table.insert(out, '<pre>')
  local out_start = #out
  local hide_count = 0
  --- @type integer[]
  local stack = {}

  local before = ''
  local after = ''
  local function loop(row)
    local inside = row <= state.end_ and row >= state.start
    local style_line = styletable[row]
    if style_line.hide and (styletable[row - 1] or {}).hide then
      return
    end
    if inside then
      _extend_virt_lines(out, state, row)
    end
    --Possible improvement (altermo):
    --Instead of looping over all the buffer characters per line,
    --why not loop over all the style_line cells,
    --and then calculating the amount of text.
    if style_line.hide then
      return
    end
    local line = vim.api.nvim_buf_get_lines(state.bufnr, row - 1, row, false)[1] or ''
    local s = ''
    if inside then
      s = s .. _pre_text_to_html(state, row)
    end
    local true_line_len = #line + 1
    for k in pairs(style_line) do
      if type(k) == 'number' and k > true_line_len then
        true_line_len = k
      end
    end
    for col = 1, true_line_len do
      local cell = style_line[col]
      --- @type table?
      local char
      if cell then
        for i = #cell[2], 1, -1 do
          local hlid = cell[2][i]
          if hlid < 0 then
            if hlid == HIDE_ID then
              hide_count = hide_count - 1
            end
          else
            --- @type integer?
            local index
            for idx = #stack, 1, -1 do
              s = s .. (name_to_closetag(state.highlights_name[stack[idx]]))
              if stack[idx] == hlid then
                index = idx
                break
              end
            end
            assert(index, 'a coles tag which has no corresponding open tag')
            for idx = index + 1, #stack do
              s = s .. (name_to_tag(state.highlights_name[stack[idx]]))
            end
            table.remove(stack, index)
          end
        end

        for _, hlid in ipairs(cell[1]) do
          if hlid < 0 then
            if hlid == HIDE_ID then
              hide_count = hide_count + 1
            end
          else
            table.insert(stack, hlid)
            s = s .. (name_to_tag(state.highlights_name[hlid]))
          end
        end

        if cell[3] and inside then
          s = s .. _virt_text_to_html(state, cell)
        end

        char = cell[4][#cell[4]]
      end

      if col == true_line_len and not char then
        break
      end

      if hide_count == 0 and inside then
        s = s
          .. _char_to_html(
            state,
            char
              or { vim.api.nvim_buf_get_text(state.bufnr, row - 1, col - 1, row - 1, col, {})[1] }
          )
      end
    end
    if row > state.end_ + 1 then
      after = after .. s
    elseif row < state.start then
      before = s .. before
    else
      table.insert(out, s)
    end
  end

  for row = 1, vim.api.nvim_buf_line_count(state.bufnr) + 1 do
    loop(row)
  end
  out[out_start] = out[out_start] .. before
  out[#out] = out[#out] .. after
  assert(#stack == 0, 'an open HTML tag was never closed')
  table.insert(out, '</pre>')
end

--- @param out string[]
--- @param fn fun()
local function extend_body(out, fn)
  table.insert(out, '<body style="display: flex">')
  fn()
  table.insert(out, '</body>')
end

--- @param out string[]
--- @param fn fun()
local function extend_html(out, fn)
  table.insert(out, '<!DOCTYPE html>')
  table.insert(out, '<html>')
  fn()
  table.insert(out, '</html>')
end

--- @param winid integer
--- @param global_state vim.tohtml.state.global
--- @return vim.tohtml.state
local function global_state_to_state(winid, global_state)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local opt = global_state.conf
  local width = opt.width or vim.bo[bufnr].textwidth
  if not width or width < 1 then
    width = vim.api.nvim_win_get_width(winid)
  end
  local range = opt.range or { 1, vim.api.nvim_buf_line_count(bufnr) }
  local state = setmetatable({
    winid = winid == 0 and vim.api.nvim_get_current_win() or winid,
    opt = vim.wo[winid],
    style = generate_styletable(bufnr),
    bufnr = bufnr,
    tabstop = (' '):rep(vim.bo[bufnr].tabstop),
    width = width,
    start = range[1],
    end_ = range[2],
  }, { __index = global_state })
  return state --[[@as vim.tohtml.state]]
end

--- @param opt vim.tohtml.opt
--- @param title? string
--- @return vim.tohtml.state.global
local function opt_to_global_state(opt, title)
  local fonts = {}
  if opt.font then
    fonts = type(opt.font) == 'string' and { opt.font } or opt.font --[[@as (string[])]]
  elseif vim.o.guifont:match('^[^:]+') then
    table.insert(fonts, vim.o.guifont:match('^[^:]+'))
  end
  table.insert(fonts, 'monospace')
  --- @type vim.tohtml.state.global
  local state = {
    background = get_background_color(),
    foreground = get_foreground_color(),
    title = opt.title or title or false,
    font = table.concat(fonts, ','),
    highlights_name = {},
    conf = opt,
  }
  return state
end

--- @type fun(state: vim.tohtml.state)[]
local styletable_funcs = {
  styletable_syntax,
  styletable_diff,
  styletable_treesitter,
  styletable_match,
  styletable_extmarks,
  styletable_conceal,
  styletable_listchars,
  styletable_folds,
  styletable_statuscolumn,
}

--- @param state vim.tohtml.state
local function state_generate_style(state)
  vim._with({ win = state.winid }, function()
    for _, fn in ipairs(styletable_funcs) do
      --- @type string?
      local cond
      if type(fn) == 'table' then
        cond = fn[2] --[[@as string]]
        --- @type function
        fn = fn[1]
      end
      if not cond or cond(state) then
        fn(state)
      end
    end
  end)
end

--- @param winid integer
--- @param opt? vim.tohtml.opt
--- @return string[]
local function win_to_html(winid, opt)
  opt = opt or {}
  local title = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winid))

  local global_state = opt_to_global_state(opt, title)
  local state = global_state_to_state(winid, global_state)
  state_generate_style(state)

  local html = {}
  extend_html(html, function()
    extend_head(html, global_state)
    extend_body(html, function()
      extend_pre(html, state)
    end)
  end)
  return html
end

local M = {}

--- @class vim.tohtml.opt
--- @inlinedoc
---
--- Title tag to set in the generated HTML code.
--- (default: buffer name)
--- @field title? string|false
---
--- Show line numbers.
--- (default: `false`)
--- @field number_lines? boolean
---
--- Fonts to use.
--- (default: `guifont`)
--- @field font? string[]|string
---
--- Width used for items which are either right aligned or repeat a character
--- infinitely.
--- (default: 'textwidth' if non-zero or window width otherwise)
--- @field width? integer
---
--- Range of rows to use.
--- (default: entire buffer)
--- @field range? integer[]

--- Converts the buffer shown in the window {winid} to HTML and returns the output as a list of string.
--- @param winid? integer Window to convert (defaults to current window)
--- @param opt? vim.tohtml.opt Optional parameters.
--- @return string[]
function M.tohtml(winid, opt)
  return win_to_html(winid or 0, opt)
end

return M
