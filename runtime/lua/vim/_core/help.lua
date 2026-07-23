local M = {}

local ts = vim.treesitter

local tag_exceptions = {
  -- Interpret asterisk (star, '*') literal but name it 'star'
  ['*'] = 'star',
  ['g*'] = 'gstar',
  ['[*'] = '[star',
  [']*'] = ']star',
  [':*'] = ':star',
  ['/*'] = '/star',
  ['/\\*'] = '/\\\\star',
  ['\\\\star'] = '/\\\\star',
  ['"*'] = 'quotestar',
  ['**'] = 'starstar',
  ['cpo-*'] = 'cpo-star',

  -- Literal question mark '?'
  ['?'] = '?',
  ['??'] = '??',
  [':?'] = ':?',
  ['?<CR>'] = '?<CR>',
  ['g?'] = 'g?',
  ['g?g?'] = 'g?g?',
  ['g??'] = 'g??',
  ['-?'] = '-?',
  ['q?'] = 'q?',
  ['v_g?'] = 'v_g?',
  ['/\\?'] = '/\\\\?',

  -- Backslash-escaping hell
  ['/\\%(\\)'] = '/\\\\%(\\\\)',
  ['/\\z(\\)'] = '/\\\\z(\\\\)',
  ['\\='] = '\\\\=',
  ['\\%$'] = '/\\\\%\\$',

  -- Some expressions are literal but without the 'expr-' prefix. Note: not all 'expr-' subjects!
  ['expr-!=?'] = '!=?',
  ['expr-!~?'] = '!\\~?',
  ['expr-<=?'] = '<=?',
  ['expr-<?'] = '<?',
  ['expr-==?'] = '==?',
  ['expr-=~?'] = '=\\~?',
  ['expr->=?'] = '>=?',
  ['expr->?'] = '>?',
  ['expr-is?'] = 'is?',
  ['expr-isnot?'] = 'isnot?',
}

---Transform a help tag query into a search pattern for find_tags().
---
---This function converts user input from `:help {subject}` into a regex pattern that balances
---literal matching with wildcard support. Vim help tags can contain characters that have special
---meaning in regex (like *, ?, |), but we also want to support wildcard searches.
---
---Examples:
---  '*' --> 'star' (literal match for the * command help tag)
---  'buffer*' --> 'buffer.*' (wildcard: find all buffer-related tags)
---  'CTRL-W' --> stays as 'CTRL-W' (already in tag format)
---  '^A' --> 'CTRL-A' (caret notation converted to tag format)
---
---@param word string The help subject as entered by the user
---@return string pattern The escaped regex pattern to search for in tag files
function M.escape_subject(word)
  local replacement = tag_exceptions[word]
  if replacement then
    return replacement
  end

  -- Add prefix '/\\' to patterns starting with a backslash
  -- Examples: \S, \%^, \%(, \zs, \z1, \@<, \@=, \@<=, \_$, \_^
  if word:match([[^\.$]]) or word:match('^\\[%%_z@]') then
    word = [[/\]] .. word
    word = word:gsub('[$.~]', [[\%0]])
    word = word:gsub('|', 'bar')
  else
    -- Fix for bracket expressions and curly braces:
    -- '\' --> '\\' (needs to come first)
    -- '[' --> '\[' (escape the opening bracket)
    -- ':[' --> ':\[' (escape the opening bracket)
    -- '\{' --> '\\{' (for '\{' pattern matching)
    -- '(' --> '' (parentheses around option tags should be ignored)
    word = word:gsub([[\+]], [[\\]])
    word = word:gsub([[^%[]], [[\[]])
    word = word:gsub([[^:%[]], [[:\[]])
    word = word:gsub([[^\{]], [[\\{]])
    word = word:gsub([[^%(']], [[']])

    word = word:gsub('|', 'bar')
    word = word:gsub([["]], 'quote')
    word = word:gsub('[$.~]', [[\%0]])
    word = word:gsub('%*', '.*')
    word = word:gsub('?', '.')

    -- Handle control characters.
    -- First convert raw control chars to the caret notation
    -- E.g. 0x01 --> '^A' etc.
    ---@type string
    word = word:gsub('([\1-\31])', function(ctrl_char)
      -- '^\' needs an extra backslash
      local repr = string.char(ctrl_char:byte() + 64):gsub([[\]], [[\\]])
      return '^' .. repr
    end)

    -- Change caret notation to 'CTRL-', except '^_'
    -- E.g. 'i^G^J' --> 'iCTRL-GCTRL-J'
    -- Only treat '^' as control notation when followed by a caret-notation
    -- char (a letter or one of "?@[\]^{"); otherwise leave it literal so
    -- patterns like ':set^=' are not wrongly split. '{' is included so
    -- '^{char}' matches the 'CTRL-{char}' placeholder tag.
    word = word:gsub('%^([%a?@\\[\\%]{^])', 'CTRL-%1')
    -- Add underscores around 'CTRL-X' characters
    -- E.g. 'iCTRL-GCTRL-J' --> 'i_CTRL-G_CTRL-J'
    -- Only exception: 'CTRL-{character}'
    word = word:gsub('([^-_])CTRL%-', '%1_CTRL-')
    word = word:gsub('(CTRL%-[^{])([^%u_\\-])', '%1_%2')

    -- Skip function arguments
    -- E.g. 'abs({expr})' --> 'abs'
    -- E.g. 'abs([arg])' --> 'abs'
    word = word:gsub('%({.*', '')
    word = word:gsub('%(%[.*', '')

    -- Skip punctuation after second apostrophe/curly brace
    -- E.g. ''option',' --> ''option''
    -- E.g. '{address},' --> '{address}'
    -- E.g. '`command`,' --> 'command' (backticks are removed too, but '``' stays '``')
    word = word:gsub([[^'([^']*)'.*]], [['%1']])
    word = word:gsub([[^{([^}]*)}.*]], '{%1}')
    word = word:gsub([[.*`([^`]+)`.*]], '%1')
  end

  return word
end

--- Characters that are considered punctuation for trimming help tags.
--- Dots (.) are NOT included here — they're trimmed separately as a last resort.
local trimmable_punct = {
  ['('] = true,
  [')'] = true,
  ['<'] = true,
  ['>'] = true,
  ['['] = true,
  [']'] = true,
  ['{'] = true,
  ['}'] = true,
  ['`'] = true,
  ['|'] = true,
  ['"'] = true,
  [','] = true,
  ["'"] = true,
  [' '] = true,
  ['\t'] = true,
}

--- Trim one layer of punctuation from a help tag string.
--- Uses cursor offset to intelligently trim: if cursor is on trimmable punctuation,
--- removes everything before cursor and skips past punctuation after cursor.
---
---@param tag string The tag to trim
---@param offset integer Cursor position within the tag (-1 if not applicable)
---@return string? trimmed Trimmed string, or nil if unchanged
local function trim_tag(tag, offset)
  if not tag or tag == '' then
    return nil
  end

  -- Special cases: single character tags
  if tag == '|' then
    return 'bar'
  end
  if tag == '"' then
    return 'quote'
  end

  local len = #tag
  -- start/end are 1-indexed inclusive positions into tag
  local s = 1
  local e = len

  if offset >= 0 and offset < len and trimmable_punct[tag:sub(offset + 1, offset + 1)] then
    -- Heuristic: cursor is on trimmable punctuation, skip past it to the right
    s = offset + 1
    while s <= e and trimmable_punct[tag:sub(s, s)] do
      s = s + 1
    end
  elseif offset >= 0 and offset < len then
    -- Cursor is on non-trimmable char: find start of identifier at cursor
    local cursor_pos = offset + 1 -- 1-indexed
    while cursor_pos > s and not trimmable_punct[tag:sub(cursor_pos - 1, cursor_pos - 1)] do
      cursor_pos = cursor_pos - 1
    end
    s = cursor_pos
  else
    -- No cursor info: trim leading punctuation
    while s <= e and trimmable_punct[tag:sub(s, s)] do
      s = s + 1
    end
  end

  -- Trim trailing punctuation
  while e >= s and trimmable_punct[tag:sub(e, e)] do
    e = e - 1
  end

  -- Truncate at "(" with args, e.g. "foo('bar')" => "foo".
  -- But keep "()" since it's part of valid tags like "vim.fn.expand()".
  for i = s, e do
    if tag:sub(i, i) == '(' and not (i + 1 <= e and tag:sub(i + 1, i + 1) == ')') then
      e = i - 1
      break
    end
  end

  -- If nothing changed, return nil
  if s == 1 and e == len then
    return nil
  end

  -- If everything was trimmed, return nil
  if s > e then
    return nil
  end

  return tag:sub(s, e)
end

--- Trim namespace prefix (dots) from a help tag.
--- Only call this if regular trimming didn't find a match.
--- Returns the tag with the leftmost dot-separated segment removed.
---
---@param tag string The tag to trim
---@return string? trimmed Trimmed string, or nil if no dots found
local function trim_tag_dots(tag)
  if not tag or tag == '' then
    return nil
  end
  local after_dot = tag:match('^[^.]+%.(.+)$')
  return after_dot
end

--- For ":help!" (bang, no args): DWIM resolve a help tag from the cursor context.
--- Gets `<cWORD>` at cursor, tries it first, then trims punctuation and dots until a valid help
--- tag is found. Falls back to `<cword>` (keyword at cursor) before dot-trimming.
---
---@return string? resolved The resolved help tag, or nil if no match found
function M.resolve_tag()
  local tag = vim.fn.expand('<cWORD>')
  if not tag or tag == '' then
    return nil
  end

  -- Compute cursor offset within <cWORD>.
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col('.') -- 1-indexed
  local s = col
  -- Scan backward from col('.') to find the whitespace boundary.
  while s > 1 and not line:sub(s - 1, s - 1):match('%s') do
    s = s - 1
  end
  local offset = col - s -- 0-indexed offset within <cWORD>

  -- Try the original tag first.
  if #vim.fn.getcompletion(tag, 'help') > 0 then
    return tag
  end

  -- Extract |tag| reference if the cursor is inside one (help's link syntax).
  local pipe_tag = tag:match('|(.+)|')
  if pipe_tag and #vim.fn.getcompletion(pipe_tag, 'help') > 0 then
    return pipe_tag
  end

  -- Iteratively trim punctuation and try again, up to 10 times.
  local candidate = tag
  for _ = 1, 10 do
    local trimmed = trim_tag(candidate, offset)
    if not trimmed then
      break
    end
    candidate = trimmed
    -- After first trim, offset is no longer valid.
    offset = -1

    if #vim.fn.getcompletion(candidate, 'help') > 0 then
      return candidate
    end
  end

  -- Try the word (alphanumeric/underscore run) at the cursor before dot-trimming, since
  -- dot-trimming strips from the left and may move away from the cursor position.
  -- E.g. for '@lsp.type.function' with cursor on "lsp", the word is "lsp".
  -- Note: we don't use <cword> because it depends on 'iskeyword'.
  local word_s, word_e = col, col
  -- If cursor is not on a word char, find the nearest word char to the right.
  if not line:sub(col, col):match('[%w_]') then
    while word_s <= #line and not line:sub(word_s, word_s):match('[%w_]') do
      word_s = word_s + 1
    end
    word_e = word_s
  end
  while word_s > 1 and line:sub(word_s - 1, word_s - 1):match('[%w_]') do
    word_s = word_s - 1
  end
  while word_e <= #line and line:sub(word_e, word_e):match('[%w_]') do
    word_e = word_e + 1
  end
  word_e = word_e - 1
  local cword = line:sub(word_s, word_e)
  if #cword > 1 and cword ~= tag and #vim.fn.getcompletion(cword, 'help') > 0 then
    return cword
  end

  -- Try trimming namespace dots (left-to-right).
  for _ = 1, 10 do
    local trimmed = trim_tag_dots(candidate)
    if not trimmed then
      break
    end
    candidate = trimmed

    if #vim.fn.getcompletion(candidate, 'help') > 0 then
      return candidate
    end
  end

  -- No match found: return raw <cWORD> so the caller can show it in an error message.
  return tag
end

---Populates the |local-additions| section of a help buffer with references to locally-installed
---help files. These are help files outside of $VIMRUNTIME (typically from plugins) whose first
---line contains a tag (e.g. *plugin-name.txt*) and a short description.
---
---For each help file found in 'runtimepath', the first line is extracted and added to the buffer
---as a reference (converting '*tag*' to '|tag|'). If a translated version of a help file exists
---in the same language as the current buffer (e.g. 'plugin.nlx' alongside 'plugin.txt'), the
---translated version is preferred over the '.txt' file.
function M.local_additions()
  local buf = vim.api.nvim_get_current_buf()
  local bufname = vim.fs.basename(vim.api.nvim_buf_get_name(buf))

  -- "help.txt" or "help.??x" where ?? is a language code, see |help-translated|.
  local lang = bufname:match('^help%.(%a%a)x$')
  if bufname ~= 'help.txt' and not lang then
    return
  end

  -- Find local help files
  ---@type table<string, string>
  local plugins = {}
  local pattern = lang and ('doc/*.{txt,%sx}'):format(lang) or 'doc/*.txt'
  for _, docpath in ipairs(vim.api.nvim_get_runtime_file(pattern, true)) do
    if not vim.fs.relpath(vim.env.VIMRUNTIME, docpath) then
      -- '/path/to/doc/plugin.txt' --> 'plugin'
      local plugname = vim.fs.basename(docpath):sub(1, -5)
      -- prefer language-specific files over .txt
      if not plugins[plugname] or vim.endswith(plugins[plugname], '.txt') then
        plugins[plugname] = docpath
      end
    end
  end

  -- Format plugin list lines
  -- Default to 78 if 'textwidth' is not set (e.g. in sandbox)
  local textwidth = math.max(vim.bo[buf].textwidth, 78)
  local lines = {}
  for _, path in vim.spairs(plugins) do
    local fp = io.open(path, 'r')
    if fp then
      local tagline = fp:read('*l') or ''
      fp:close()
      ---@type string, string
      local plugname, desc = tagline:match('^%*([^*]+)%*%s*(.*)$')
      if plugname and desc then
        -- left-align taglink and right-align description by inserting spaces in between
        local plug_width = vim.fn.strdisplaywidth(plugname)
        local _, concealed_chars = desc:gsub('|', '')
        local desc_width = vim.fn.strdisplaywidth(desc) - concealed_chars
        -- max(l, 1) forces at least one space for if the description is too long
        local spaces = string.rep(' ', math.max(textwidth - desc_width - plug_width - 2, 1))
        local fmt = string.format('|%s|%s%s', plugname, spaces, desc)
        table.insert(lines, fmt)
      end
    end
  end

  -- Add plugin list to local-additions section
  for linenr, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find('*local-additions*', 1, true) then
      vim._with({ buf = buf, bo = { modifiable = true, readonly = false } }, function()
        vim.api.nvim_buf_set_lines(buf, linenr, linenr, true, lines)
      end)
      break
    end
  end
end


local query = ts.query.parse('vimdoc', '(tag (word) @tagname)')

--- @alias Tag { [1]: string, [2]: string, [3]: string} tuple of tag, file, and search command

---Find and report duplicate tags.
---@param tags Tag[]
---@return boolean
local function find_duplicates(tags)
  local prevtag, prevfn, has_duplicates = '', '', false

  for _, tagline in ipairs(tags) do
    local curtag, curfn, _ = unpack(tagline)
    if curtag == prevtag then
      has_duplicates = true
      local filenames = prevfn ~= curfn and (curfn .. ' and ' .. prevfn) or curfn
      local msg = ('E154: Duplicate tag "%s" in %s'):format(curtag, filenames)
      vim.api.nvim_echo({ { msg } }, false, { err = true })
    end
    prevtag = curtag
    prevfn = curfn
  end

  return has_duplicates
end

---Extract tags from {file} and add to list of tags. Modifies {tags}.
---@param tags Tag[]
---@param file string
local function extract_tags(tags, file)
  local filename = vim.fs.basename(file)
  local source = vim.fn.readblob(file)
  local parser = ts.get_string_parser(source, 'vimdoc')

  local tree = assert(parser:parse())
  local root = tree[1]:root()
  for _, match in query:iter_matches(root, source) do
    for id, node in pairs(match) do
      if query.captures[id] == 'tagname' then
        -- Only accept a *tag* when there is white space (or nothing) before it
        -- and it is followed by a white character or end-of-line.
        local _, _, start_byte, _, _, end_byte = node[1]:parent():range(true)
        local before = source:sub(start_byte, start_byte)
        local after = source:sub(end_byte + 1, end_byte + 1)
        if before:match('^[ \t\n\r]?$') and after:match('^[ \t\n\r]?$') then
          local tagname = ts.get_node_text(node[1], source)
          local escaped = tagname:gsub('[\\/]', '\\%0')
          local searchcmd = '/*' .. escaped .. '*'
          table.insert(tags, { tagname, filename, searchcmd })
        end
      end
    end
  end
end

--- Extract tags from helpfiles and combine in a single 'tags' file.
--- @param helpfiles string[] list of helpfiles
--- @param outpath string path to write the 'tags' file to.
--- @param include_helptags_tag boolean true if the 'help-tags' tag should be included
local function gen_tagsfile(helpfiles, outpath, include_helptags_tag)
  ---@type Tag[]
  local tags = {}

  -- (1) extract tags from all files
  for _, file in ipairs(helpfiles) do
    extract_tags(tags, file)
  end

  if include_helptags_tag then
    table.insert(tags, { 'help-tags', 'tags', '1' })
  end

  if vim.tbl_isempty(tags) then
    return
  end

  -- (2) sort alphabetically on tag name
  table.sort(tags, function(a, b)
    return a[1] < b[1]
  end)

  -- (3) check duplicates
  local has_duplicates = find_duplicates(tags)

  -- (4) write tags to file
  local f = assert(io.open(outpath, 'w'))
  for _, tag in ipairs(tags) do
    f:write(table.concat(tag, '\t') .. '\n')
  end
  f:close()

  -- tags file has to be written before we can error
  if has_duplicates then
    error('duplicate tags')
  end

  -- vim.print('Helptags written to ' .. outpath)
end

--- Create a "tags" file for all help files in the given directory.
---
--- The directory {dir} is generally a "doc" directory that contains "*.txt"
--- helpfiles.
---
--- @param dir string? Path to directory with help files. If `nil` (or |vim.NIL|),
--- generate tags for every `doc` directory in the runtimepath.
--- @param include_index_tag? boolean (default: false) Whether to include the "help-tags" tag.
function M.gen_tags(dir, include_index_tag)
  if dir == vim.NIL then
    dir = nil
  end
  vim.validate('dir', dir, 'string', true)
  vim.validate('include_index_tag', include_index_tag, 'boolean', true)

  local dirs = dir and { vim.fs.normalize(dir) } or vim.api.nvim_get_runtime_file('doc', true)
  local vimruntime = vim.fs.normalize(vim.fs.joinpath(vim.env.VIMRUNTIME, 'doc'))

  for _, directory in ipairs(dirs) do
    local files = vim.fs.find(function(name, _)
      return vim.endswith(name, '.txt')
    end, { path = directory, type = 'file', limit = math.huge })

    local outpath = vim.fs.joinpath(directory, 'tags')
    gen_tagsfile(files, outpath, include_index_tag or directory == vimruntime)

    -- handle translated help files per language
    local translated = vim.fs.find(function(name, _)
      -- "*.[a-z][a-z]x", see :help help-translated
      return name:match('%.%l%lx', -4)
    end, { path = directory, type = 'file', limit = math.huge })

    -- categorize translated files per two-letter language code
    ---@type table<string, string[]>
    local per_lang = {}
    for _, file in ipairs(translated) do
      -- extract language code "nl" from filename "plugin.nlx"
      local lang = file:sub(-3, -2)
      per_lang[lang] = per_lang[lang] or {}
      table.insert(per_lang[lang], file)
    end

    for lang, langfiles in pairs(per_lang) do
      local tagsfile = vim.fs.joinpath(directory, 'tags-' .. lang)
      gen_tagsfile(langfiles, tagsfile, include_index_tag or directory == vimruntime)
    end
  end
end

return M
