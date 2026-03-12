local M = {}

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
  ['expr-=~?'] = '=~?',
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
    word = word:gsub('%^([^_])', 'CTRL-%1')
    -- Add underscores around 'CTRL-X' characters
    -- E.g. 'iCTRL-GCTRL-J' --> 'i_CTRL-G_CTRL-J'
    -- Only exception: 'CTRL-{character}'
    word = word:gsub('([^_])CTRL%-', '%1_CTRL-')
    word = word:gsub('(CTRL%-[^{])([^_\\])', '%1_%2')

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
        local desc_width = vim.fn.strdisplaywidth(desc)
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

return M
