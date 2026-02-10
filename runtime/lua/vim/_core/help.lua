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
    word = word:gsub([[^`([^`]+)`.*]], '%1')
  end

  return word
end

return M
