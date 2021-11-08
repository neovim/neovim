local default_border = {
  {"", "NormalFloat"},
  {"", "NormalFloat"},
  {"", "NormalFloat"},
  {" ", "NormalFloat"},
  {"", "NormalFloat"},
  {"", "NormalFloat"},
  {"", "NormalFloat"},
  {" ", "NormalFloat"},
}

---@private
--- Check the border given by opts or the default border for the additional
--- size it adds to a float.
---@param opts (table, optional) options for the floating window
---            - border (string or table) the border
---@returns (table) size of border in the form of { height = height, width = width }
local function get_border_size(opts)
  local border = opts and opts.border or default_border
  local height = 0
  local width = 0

  if type(border) == 'string' then
    local border_size = {none = {0, 0}, single = {2, 2}, double = {2, 2}, rounded = {2, 2}, solid = {2, 2}, shadow = {1, 1}}
    if border_size[border] == nil then
      error(string.format("invalid floating preview border: %s. :help vim.api.nvim_open_win()", vim.inspect(border)))
    end
    height, width = unpack(border_size[border])
  else
    if 8 % #border ~= 0 then
      error(string.format("invalid floating preview border: %s. :help vim.api.nvim_open_win()", vim.inspect(border)))
    end
    ---@private
    local function border_width(id)
      id = (id - 1) % #border + 1
      if type(border[id]) == "table" then
        -- border specified as a table of <character, highlight group>
        return vim.fn.strdisplaywidth(border[id][1])
      elseif type(border[id]) == "string" then
        -- border specified as a list of border characters
        return vim.fn.strdisplaywidth(border[id])
      end
      error(string.format("invalid floating preview border: %s. :help vim.api.nvim_open_win()", vim.inspect(border)))
    end
    ---@private
    local function border_height(id)
      id = (id - 1) % #border + 1
      if type(border[id]) == "table" then
        -- border specified as a table of <character, highlight group>
        return #border[id][1] > 0 and 1 or 0
      elseif type(border[id]) == "string" then
        -- border specified as a list of border characters
        return #border[id] > 0 and 1 or 0
      end
      error(string.format("invalid floating preview border: %s. :help vim.api.nvim_open_win()", vim.inspect(border)))
    end
    height = height + border_height(2)  -- top
    height = height + border_height(6)  -- bottom
    width  = width  + border_width(4)  -- right
    width  = width  + border_width(8)  -- left
  end

  return { height = height, width = width }
end

---@private
local function split_lines(value)
  return split(value, '\n', true)
end

--- Replaces text in a range with new text.
---
--- CAUTION: Changes in-place!
---
---@param lines (table) Original list of strings
---@param A (table) Start position; a 2-tuple of {line, col} numbers
---@param B (table) End position; a 2-tuple of {line, col} numbers
---@param new_lines A list of strings to replace the original
---@returns (table) The modified {lines} object
function M.set_lines(lines, A, B, new_lines)
  -- 0-indexing to 1-indexing
  local i_0 = A[1] + 1
  -- If it extends past the end, truncate it to the end. This is because the
  -- way the LSP describes the range including the last newline is by
  -- specifying a line number after what we would call the last line.
  local i_n = math.min(B[1] + 1, #lines)
  if not (i_0 >= 1 and i_0 <= #lines + 1 and i_n >= 1 and i_n <= #lines) then
    error("Invalid range: "..vim.inspect{A = A; B = B; #lines, new_lines})
  end
  local prefix = ""
  local suffix = lines[i_n]:sub(B[2]+1)
  if A[2] > 0 then
    prefix = lines[i_0]:sub(1, A[2])
  end
  local n = i_n - i_0 + 1
  if n ~= #new_lines then
    for _ = 1, n - #new_lines do table.remove(lines, i_0) end
    for _ = 1, #new_lines - n do table.insert(lines, i_0, '') end
  end
  for i = 1, #new_lines do
    lines[i - 1 + i_0] = new_lines[i]
  end
  if #suffix > 0 then
    local i = i_0 + #new_lines - 1
    lines[i] = lines[i]..suffix
  end
  if #prefix > 0 then
    lines[i_0] = prefix..lines[i_0]
  end
  return lines
end

--- Creates autocommands to close a preview window when events happen.
---
---@param events (table) list of events
---@param winnr (number) window id of preview window
---@see |autocmd-events|
function M.close_preview_autocmd(events, winnr)
  if #events > 0 then
    api.nvim_command("autocmd "..table.concat(events, ',').." <buffer> ++once lua pcall(vim.api.nvim_win_close, "..winnr..", true)")
  end
end

---@internal
--- Computes size of float needed to show contents (with optional wrapping)
---
---@param contents table of lines to show in window
---@param opts dictionary with optional fields
---            - height  of floating window
---            - width   of floating window
---            - wrap_at character to wrap at for computing height
---            - max_width  maximal width of floating window
---            - max_height maximal height of floating window
---@returns width,height size of float
function M._make_floating_popup_size(contents, opts)
  validate {
    contents = { contents, 't' };
    opts = { opts, 't', true };
  }
  opts = opts or {}

  local width = opts.width
  local height = opts.height
  local wrap_at = opts.wrap_at
  local max_width = opts.max_width
  local max_height = opts.max_height
  local line_widths = {}

  if not width then
    width = 0
    for i, line in ipairs(contents) do
      -- TODO(ashkan) use nvim_strdisplaywidth if/when that is introduced.
      line_widths[i] = vim.fn.strdisplaywidth(line)
      width = math.max(line_widths[i], width)
    end
  end

  local border_width = get_border_size(opts).width
  local screen_width = api.nvim_win_get_width(0)
  width = math.min(width, screen_width)

  -- make sure borders are always inside the screen
  if width + border_width > screen_width then
    width = width - (width + border_width - screen_width)
  end

  if wrap_at and wrap_at > width then
    wrap_at = width
  end

  if max_width then
    width = math.min(width, max_width)
    wrap_at = math.min(wrap_at or max_width, max_width)
  end

  if not height then
    height = #contents
    if wrap_at and width >= wrap_at then
      height = 0
      if vim.tbl_isempty(line_widths) then
        for _, line in ipairs(contents) do
          local line_width = vim.fn.strdisplaywidth(line)
          height = height + math.ceil(line_width/wrap_at)
        end
      else
        for i = 1, #contents do
          height = height + math.max(1, math.ceil(line_widths[i]/wrap_at))
        end
      end
    end
  end
  if max_height then
    height = math.min(height, max_height)
  end

  return width, height
end

--- Shows contents in a floating window.
---
---@param contents table of lines to show in window
---@param syntax string of syntax to set for opened buffer
---@param opts dictionary with optional fields
---             - height    of floating window
---             - width     of floating window
---             - wrap boolean enable wrapping of long lines (defaults to true)
---             - wrap_at   character to wrap at for computing height when wrap is enabled
---             - max_width  maximal width of floating window
---             - max_height maximal height of floating window
---             - pad_top    number of lines to pad contents at top
---             - pad_bottom number of lines to pad contents at bottom
---             - focus_id if a popup with this id is opened, then focus it
---             - close_events list of events that closes the floating window
---             - focusable (boolean, default true): Make float focusable
---@returns bufnr,winnr buffer and window number of the newly created floating
---preview window
function M.open_floating_preview(contents, syntax, opts)
  validate {
    contents = { contents, 't' };
    syntax = { syntax, 's', true };
    opts = { opts, 't', true };
  }
  opts = opts or {}
  opts.wrap = opts.wrap ~= false -- wrapping by default
  opts.stylize_markdown = opts.stylize_markdown ~= false
  opts.close_events = opts.close_events or {"CursorMoved", "CursorMovedI", "BufHidden", "InsertCharPre"}

  local bufnr = api.nvim_get_current_buf()

  -- check if this popup is focusable and we need to focus
  if opts.focus_id and opts.focusable ~= false then
    -- Go back to previous window if we are in a focusable one
    local current_winnr = api.nvim_get_current_win()
    if npcall(api.nvim_win_get_var, current_winnr, opts.focus_id) then
      api.nvim_command("wincmd p")
      return bufnr, current_winnr
    end
    do
      local win = find_window_by_var(opts.focus_id, bufnr)
      if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
        -- focus and return the existing buf, win
        api.nvim_set_current_win(win)
        api.nvim_command("stopinsert")
        return api.nvim_win_get_buf(win), win
      end
    end
  end

  -- check if another floating preview already exists for this buffer
  -- and close it if needed
  local existing_float = npcall(api.nvim_buf_get_var, bufnr, "lsp_floating_preview")
  if existing_float and api.nvim_win_is_valid(existing_float) then
    api.nvim_win_close(existing_float, true)
  end

  local floating_bufnr = api.nvim_create_buf(false, true)
  local do_stylize = syntax == "markdown" and opts.stylize_markdown


  -- Clean up input: trim empty lines from the end, pad
  contents = M._trim(contents, opts)

  if do_stylize then
    -- applies the syntax and sets the lines to the buffer
    contents = M.stylize_markdown(floating_bufnr, contents, opts)
  else
    if syntax then
      api.nvim_buf_set_option(floating_bufnr, 'syntax', syntax)
    end
    api.nvim_buf_set_lines(floating_bufnr, 0, -1, true, contents)
  end

  -- Compute size of float needed to show (wrapped) lines
  if opts.wrap then
    opts.wrap_at = opts.wrap_at or api.nvim_win_get_width(0)
  else
    opts.wrap_at = nil
  end
  local width, height = M._make_floating_popup_size(contents, opts)

  local float_option = M.make_floating_popup_options(width, height, opts)
  local floating_winnr = api.nvim_open_win(floating_bufnr, false, float_option)
  if do_stylize then
    api.nvim_win_set_option(floating_winnr, 'conceallevel', 2)
    api.nvim_win_set_option(floating_winnr, 'concealcursor', 'n')
  end
  -- disable folding
  api.nvim_win_set_option(floating_winnr, 'foldenable', false)
  -- soft wrapping
  api.nvim_win_set_option(floating_winnr, 'wrap', opts.wrap)

  api.nvim_buf_set_option(floating_bufnr, 'modifiable', false)
  api.nvim_buf_set_option(floating_bufnr, 'bufhidden', 'wipe')
  api.nvim_buf_set_keymap(floating_bufnr, "n", "q", "<cmd>bdelete<cr>", {silent = true, noremap = true})
  M.close_preview_autocmd(opts.close_events, floating_winnr)

  -- save focus_id
  if opts.focus_id then
    api.nvim_win_set_var(floating_winnr, opts.focus_id, bufnr)
  end
  api.nvim_buf_set_var(bufnr, "lsp_floating_preview", floating_winnr)

  return floating_bufnr, floating_winnr
end

---@private
local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if npcall(api.nvim_win_get_var, win, name) == value then
      return win
    end
  end
end

--- Removes empty lines from the beginning and end.
---@param lines (table) list of lines to trim
---@returns (table) trimmed list of lines
function M.trim_empty_lines(lines)
  local start = 1
  for i = 1, #lines do
    if lines[i] ~= nil and #lines[i] > 0 then
      start = i
      break
    end
  end
  local finish = 1
  for i = #lines, 1, -1 do
    if lines[i] ~= nil and #lines[i] > 0 then
      finish = i
      break
    end
  end
  return vim.list_extend({}, lines, start, finish)
end

--- Trims empty lines from input and pad top and bottom with empty lines
---
---@param contents table of lines to trim and pad
---@param opts dictionary with optional fields
---             - pad_top    number of lines to pad contents at top (default 0)
---             - pad_bottom number of lines to pad contents at bottom (default 0)
---@return contents table of trimmed and padded lines
function M._trim(contents, opts)
  validate {
    contents = { contents, 't' };
    opts = { opts, 't', true };
  }
  opts = opts or {}
  contents = M.trim_empty_lines(contents)
  if opts.pad_top then
    for _ = 1, opts.pad_top do
      table.insert(contents, 1, "")
    end
  end
  if opts.pad_bottom then
    for _ = 1, opts.pad_bottom do
      table.insert(contents, "")
    end
  end
  return contents
end

--- Generates a table mapping markdown code block lang to vim syntax,
--- based on g:markdown_fenced_languages
---@return a table of lang -> syntax mappings
---@private
local function get_markdown_fences()
  local fences = {}
  for _, fence in pairs(vim.g.markdown_fenced_languages or {}) do
    local lang, syntax = fence:match("^(.*)=(.*)$")
    if lang then
      fences[lang] = syntax
    end
  end
  return fences
end

--- Converts markdown into syntax highlighted regions by stripping the code
--- blocks and converting them into highlighted code.
--- This will by default insert a blank line separator after those code block
--- regions to improve readability.
---
--- This method configures the given buffer and returns the lines to set.
---
--- If you want to open a popup with fancy markdown, use `open_floating_preview` instead
---
---@param contents table of lines to show in window
---@param opts dictionary with optional fields
---  - height    of floating window
---  - width     of floating window
---  - wrap_at   character to wrap at for computing height
---  - max_width  maximal width of floating window
---  - max_height maximal height of floating window
---  - pad_top    number of lines to pad contents at top
---  - pad_bottom number of lines to pad contents at bottom
---  - separator insert separator after code block
---@returns width,height size of float
function M.stylize_markdown(bufnr, contents, opts)
  validate {
    contents = { contents, 't' };
    opts = { opts, 't', true };
  }
  opts = opts or {}

  -- table of fence types to {ft, begin, end}
  -- when ft is nil, we get the ft from the regex match
  local matchers = {
    block = {nil, "```+([a-zA-Z0-9_]*)", "```+"},
    pre = {"", "<pre>", "</pre>"},
    code = {"", "<code>", "</code>"},
    text = {"plaintex", "<text>", "</text>"},
  }

  local match_begin = function(line)
    for type, pattern in pairs(matchers) do
      local ret = line:match(string.format("^%%s*%s%%s*$", pattern[2]))
      if ret then
        return {
          type = type,
          ft = pattern[1] or ret
        }
      end
    end
  end

  local match_end = function(line, match)
    local pattern = matchers[match.type]
    return line:match(string.format("^%%s*%s%%s*$", pattern[3]))
  end

  -- Clean up
  contents = M._trim(contents, opts)

  -- Insert blank line separator after code block?
  local add_sep = opts.separator == nil and true or opts.separator
  local stripped = {}
  local highlights = {}
  -- keep track of lnums that contain markdown
  local markdown_lines = {}
  do
    local i = 1
    while i <= #contents do
      local line = contents[i]
      local match = match_begin(line)
      if match then
        local start = #stripped
        i = i + 1
        while i <= #contents do
          line = contents[i]
          if match_end(line, match) then
            i = i + 1
            break
          end
          table.insert(stripped, line)
          i = i + 1
        end
        table.insert(highlights, {
          ft = match.ft;
          start = start + 1;
          finish = #stripped;
        })
        -- add a separator, but not on the last line
        if add_sep and i < #contents then
          table.insert(stripped, "---")
          markdown_lines[#stripped] = true
        end
      else
        -- strip any emty lines or separators prior to this separator in actual markdown
        if line:match("^---+$") then
          while markdown_lines[#stripped] and (stripped[#stripped]:match("^%s*$") or stripped[#stripped]:match("^---+$")) do
            markdown_lines[#stripped] = false
            table.remove(stripped, #stripped)
          end
        end
        -- add the line if its not an empty line following a separator
        if not (line:match("^%s*$") and markdown_lines[#stripped] and stripped[#stripped]:match("^---+$")) then
          table.insert(stripped, line)
          markdown_lines[#stripped] = true
        end
        i = i + 1
      end
    end
  end

  -- Compute size of float needed to show (wrapped) lines
  opts.wrap_at = opts.wrap_at or (vim.wo["wrap"] and api.nvim_win_get_width(0))
  local width = M._make_floating_popup_size(stripped, opts)

  local sep_line = string.rep("─", math.min(width, opts.wrap_at or width))

  for l in pairs(markdown_lines) do
    if stripped[l]:match("^---+$") then
      stripped[l] = sep_line
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, stripped)

  local idx = 1
  ---@private
  -- keep track of syntaxes we already inlcuded.
  -- no need to include the same syntax more than once
  local langs = {}
  local fences = get_markdown_fences()
  local function apply_syntax_to_region(ft, start, finish)
    if ft == "" then
      vim.cmd(string.format("syntax region markdownCode start=+\\%%%dl+ end=+\\%%%dl+ keepend extend", start, finish + 1))
      return
    end
    ft = fences[ft] or ft
    local name = ft..idx
    idx = idx + 1
    local lang = "@"..ft:upper()
    if not langs[lang] then
      -- HACK: reset current_syntax, since some syntax files like markdown won't load if it is already set
      pcall(vim.api.nvim_buf_del_var, bufnr, "current_syntax")
      -- TODO(ashkan): better validation before this.
      if not pcall(vim.cmd, string.format("syntax include %s syntax/%s.vim", lang, ft)) then
        return
      end
      langs[lang] = true
    end
    vim.cmd(string.format("syntax region %s start=+\\%%%dl+ end=+\\%%%dl+ contains=%s keepend", name, start, finish + 1, lang))
  end

  -- needs to run in the buffer for the regions to work
  api.nvim_buf_call(bufnr, function()
    -- we need to apply lsp_markdown regions speperately, since otherwise
    -- markdown regions can "bleed" through the other syntax regions
    -- and mess up the formatting
    local last = 1
    for _, h in ipairs(highlights) do
      if last < h.start then
        apply_syntax_to_region("lsp_markdown", last, h.start - 1)
      end
      apply_syntax_to_region(h.ft, h.start, h.finish)
      last = h.finish + 1
    end
    if last <= #stripped then
      apply_syntax_to_region("lsp_markdown", last, #stripped)
    end
  end)

  return stripped
end

--- Converts any of `MarkedString` | `MarkedString[]` | `MarkupContent` into
--- a list of lines containing valid markdown. Useful to populate the hover
--- window for `textDocument/hover`, for parsing the result of
--- `textDocument/signatureHelp`, and potentially others.
---
---@param input (`MarkedString` | `MarkedString[]` | `MarkupContent`)
---@param contents (table, optional, default `{}`) List of strings to extend with converted lines
---@returns {contents}, extended with lines of converted markdown.
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_hover
function M.convert_input_to_markdown_lines(input, contents)
  contents = contents or {}
  -- MarkedString variation 1
  if type(input) == 'string' then
    list_extend(contents, split_lines(input))
  else
    assert(type(input) == 'table', "Expected a table for Hover.contents")
    -- MarkupContent
    if input.kind then
      -- The kind can be either plaintext or markdown.
      -- If it's plaintext, then wrap it in a <text></text> block

      -- Some servers send input.value as empty, so let's ignore this :(
      local value = input.value or ''

      if input.kind == "plaintext" then
        -- wrap this in a <text></text> block so that stylize_markdown
        -- can properly process it as plaintext
        value = string.format("<text>\n%s\n</text>", value)
      end

      -- assert(type(value) == 'string')
      list_extend(contents, split_lines(value))
    -- MarkupString variation 2
    elseif input.language then
      -- Some servers send input.value as empty, so let's ignore this :(
      -- assert(type(input.value) == 'string')
      table.insert(contents, "```"..input.language)
      list_extend(contents, split_lines(input.value or ''))
      table.insert(contents, "```")
    -- By deduction, this must be MarkedString[]
    else
      -- Use our existing logic to handle MarkedString
      for _, marked_string in ipairs(input) do
        M.convert_input_to_markdown_lines(marked_string, contents)
      end
    end
  end
  if (contents[1] == '' or contents[1] == nil) and #contents == 1 then
    return {}
  end
  return contents
end

--- Converts `textDocument/SignatureHelp` response to markdown lines.
---
---@param signature_help Response of `textDocument/SignatureHelp`
---@param ft optional filetype that will be use as the `lang` for the label markdown code block
---@param triggers optional list of trigger characters from the lsp server. used to better determine parameter offsets
---@returns list of lines of converted markdown.
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_signatureHelp
function M.convert_signature_help_to_markdown_lines(signature_help, ft, triggers)
  if not signature_help.signatures then
    return
  end
  --The active signature. If omitted or the value lies outside the range of
  --`signatures` the value defaults to zero or is ignored if `signatures.length
  --=== 0`. Whenever possible implementors should make an active decision about
  --the active signature and shouldn't rely on a default value.
  local contents = {}
  local active_hl
  local active_signature = signature_help.activeSignature or 0
  -- If the activeSignature is not inside the valid range, then clip it.
  if active_signature >= #signature_help.signatures then
    active_signature = 0
  end
  local signature = signature_help.signatures[active_signature + 1]
  if not signature then
    return
  end
  local label = signature.label
  if ft then
    -- wrap inside a code block so stylize_markdown can render it properly
    label = ("```%s\n%s\n```"):format(ft, label)
  end
  vim.list_extend(contents, vim.split(label, '\n', true))
  if signature.documentation then
    M.convert_input_to_markdown_lines(signature.documentation, contents)
  end
  if signature.parameters and #signature.parameters > 0 then
    local active_parameter = (signature.activeParameter or signature_help.activeParameter or 0)
    if active_parameter < 0
      then active_parameter = 0
    end

    -- If the activeParameter is > #parameters, then set it to the last
    -- NOTE: this is not fully according to the spec, but a client-side interpretation
    if active_parameter >= #signature.parameters then
      active_parameter = #signature.parameters - 1
    end

    local parameter = signature.parameters[active_parameter + 1]
    if parameter then
      --[=[
      --Represents a parameter of a callable-signature. A parameter can
      --have a label and a doc-comment.
      interface ParameterInformation {
        --The label of this parameter information.
        --
        --Either a string or an inclusive start and exclusive end offsets within its containing
        --signature label. (see SignatureInformation.label). The offsets are based on a UTF-16
        --string representation as `Position` and `Range` does.
        --
        --*Note*: a label of type string should be a substring of its containing signature label.
        --Its intended use case is to highlight the parameter label part in the `SignatureInformation.label`.
        label: string | [number, number];
        --The human-readable doc-comment of this parameter. Will be shown
        --in the UI but can be omitted.
        documentation?: string | MarkupContent;
      }
      --]=]
      if parameter.label then
        if type(parameter.label) == "table" then
          active_hl = parameter.label
        else
          local offset = 1
          -- try to set the initial offset to the first found trigger character
          for _, t in ipairs(triggers or {}) do
            local trigger_offset = signature.label:find(t, 1, true)
            if trigger_offset and (offset == 1 or trigger_offset < offset) then
              offset = trigger_offset
            end
          end
          for p, param in pairs(signature.parameters) do
            offset = signature.label:find(param.label, offset, true)
            if not offset then break end
            if p == active_parameter + 1 then
              active_hl = {offset - 1, offset + #parameter.label - 1}
              break
            end
            offset = offset + #param.label + 1
          end
        end
      end
      if parameter.documentation then
        M.convert_input_to_markdown_lines(parameter.documentation, contents)
      end
    end
  end
  return contents, active_hl
end

--- Creates a table with sensible default options for a floating window. The
--- table can be passed to |nvim_open_win()|.
---
---@param width (number) window width (in character cells)
---@param height (number) window height (in character cells)
---@param opts (table, optional)
---        - offset_x (number) offset to add to `col`
---        - offset_y (number) offset to add to `row`
---        - border (string or table) override `border`
---        - focusable (string or table) override `focusable`
---        - zindex (string or table) override `zindex`, defaults to 50
---@returns (table) Options
function M.make_floating_popup_options(width, height, opts)
  validate {
    opts = { opts, 't', true };
  }
  opts = opts or {}
  validate {
    ["opts.offset_x"] = { opts.offset_x, 'n', true };
    ["opts.offset_y"] = { opts.offset_y, 'n', true };
  }

  local anchor = ''
  local row, col

  local lines_above = vim.fn.winline() - 1
  local lines_below = vim.fn.winheight(0) - lines_above

  if lines_above < lines_below then
    anchor = anchor..'N'
    height = math.min(lines_below, height)
    row = 1
  else
    anchor = anchor..'S'
    height = math.min(lines_above, height)
    row = 0
  end

  if vim.fn.wincol() + width + (opts.offset_x or 0) <= api.nvim_get_option('columns') then
    anchor = anchor..'W'
    col = 0
  else
    anchor = anchor..'E'
    col = 1
  end

  return {
    anchor = anchor,
    col = col + (opts.offset_x or 0),
    height = height,
    focusable = opts.focusable,
    relative = 'cursor',
    row = row + (opts.offset_y or 0),
    style = 'minimal',
    width = width,
    border = opts.border or default_border,
    zindex = opts.zindex or 50,
  }
end
