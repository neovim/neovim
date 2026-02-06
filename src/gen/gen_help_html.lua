--- Converts Nvim :help files to HTML.  Validates |tag| links and document syntax (parser errors).
--
-- USAGE (For CI/local testing purposes): Simply `make lintdoc`, which basically does the following:
--   1. :helptags ALL
--   2. nvim -V1 -es +"lua require('src.gen.gen_help_html').run_validate()" +q
--   3. nvim -V1 -es +"lua require('src.gen.gen_help_html').test_gen()" +q
--
-- USAGE (GENERATE HTML):
--   1. `:helptags ALL` first; this script depends on vim.fn.taglist().
--   2. nvim -V1 -es --clean +"lua require('src.gen.gen_help_html').gen('./runtime/doc', 'target/dir/')" +q
--   2. nvim -V1 -es --clean +"lua require('src.gen.gen_help_html').gen('./one_doc', './pdf_docs')" +q
--      - Read the docstring at gen().
--   3. cd target/dir/ && jekyll serve --host 0.0.0.0
--   4. Visit http://localhost:4000/…/help.txt.html
--
-- USAGE (VALIDATE):
--   1. nvim -V1 -es +"lua require('src.gen.gen_help_html').validate('./runtime/doc')" +q
--      - validate() is 10x faster than gen(), so it is used in CI.
--   2. Check for unreachable URLs:
--      nvim -V1 -es +"lua require('src.gen.gen_help_html').validate('./runtime/doc', true)" +q
--
-- SELF-TEST MODE:
--   1. nvim -V1 -es +"lua require('src.gen.gen_help_html')._test()" +q
--
-- NOTES:
--   * This script is used by the automation repo: https://github.com/neovim/doc
--   * :helptags checks for duplicate tags, whereas this script checks _links_ (to tags).
--   * gen() and validate() are the primary (programmatic) entrypoints. validate() only exists
--     because gen() is too slow (~1 min) to run in per-commit CI.
--   * visit_node() is the core function used by gen() to traverse the document tree and produce HTML.
--   * visit_validate() is the core function used by validate().
--   * Files in `new_layout` will be generated with a "flow" layout instead of preformatted/fixed-width layout.
--
-- TODO:
--   * Conjoin listitem "blocks" (blank-separated). Example: starting.txt

local pending_urls = 0
local tagmap = nil ---@type table<string, string>
local helpfiles = nil ---@type string[]
local invalid_links = {} ---@type table<string, any>
local invalid_urls = {} ---@type table<string, any>
local invalid_spelling = {} ---@type table<string, table<string, string>>
local spell_dict = {
  Neovim = 'Nvim',
  NeoVim = 'Nvim',
  neovim = 'Nvim',
  lua = 'Lua',
  VimL = 'Vimscript',
  vimL = 'Vimscript',
  viml = 'Vimscript',
  ['tree-sitter'] = 'treesitter',
  ['Tree-sitter'] = 'Treesitter',
}
--- specify the list of keywords to ignore (i.e. allow), or true to disable spell check completely.
--- @type table<string, true|string[]>
local spell_ignore_files = {
  ['credits.txt'] = { 'Neovim' },
  ['news.txt'] = { 'tree-sitter' }, -- in news, may refer to the upstream "tree-sitter" library
  ['news-0.10.txt'] = { 'tree-sitter' },
}
--- Punctuation that indicates a word is part of a path, module name, etc.
--- Example: ".lua" is likely part of a filename, thus we don't want to enforce its spelling.
local spell_punc = {
  ['.'] = true,
  ['/'] = true,
}
local language = nil

local M = {}

-- These files are generated with "flow" layout (non fixed-width, wrapped text paragraphs).
-- All other files are "legacy" files which require fixed-width layout.
local new_layout = {
  ['api.txt'] = true,
  ['lsp.txt'] = true,
  ['channel.txt'] = true,
  ['deprecated.txt'] = true,
  ['dev.txt'] = true,
  ['dev_arch.txt'] = true,
  ['dev_style.txt'] = true,
  ['dev_test.txt'] = true,
  ['dev_theme.txt'] = true,
  ['dev_tools.txt'] = true,
  ['dev_vimpatch.txt'] = true,
  ['diagnostic.txt'] = true,
  ['help.txt'] = true,
  ['faq.txt'] = true,
  ['gui.txt'] = true,
  ['intro.txt'] = true,
  ['lua.txt'] = true,
  ['lua-guide.txt'] = true,
  ['lua-plugin.txt'] = true,
  ['luaref.txt'] = true,
  ['news.txt'] = true,
  ['news-0.9.txt'] = true,
  ['news-0.10.txt'] = true,
  ['news-0.11.txt'] = true,
  ['news-0.12.txt'] = true,
  ['nvim.txt'] = true,
  ['pack.txt'] = true,
  ['provider.txt'] = true,
  ['tui.txt'] = true,
  ['ui.txt'] = true,
  ['vim_diff.txt'] = true,
}

-- Map of new-page:old-page, to redirect renamed pages.
local redirects = {
  ['api-ui-events.txt'] = 'ui.txt',
  ['credits.txt'] = 'backers.txt',
  ['dev.txt'] = 'develop.txt',
  ['dev_tools.txt'] = 'debug.txt',
  ['plugins.txt'] = 'editorconfig.txt',
  ['terminal.txt'] = 'nvim_terminal_emulator.txt',
  ['tui.txt'] = 'term.txt',
}

-- TODO: These known invalid |links| require an update to the relevant docs.
local exclude_invalid = {
  ["'string'"] = 'vimeval.txt',
  Query = 'treesitter.txt',
  matchit = 'vim_diff.txt',
  ['set!'] = 'treesitter.txt',
}

-- False-positive "invalid URLs".
local exclude_invalid_urls = {
  ['http://aspell.net/man-html/Affix-Compression.html'] = 'spell.txt',
  ['http://aspell.net/man-html/Phonetic-Code.html'] = 'spell.txt',
  ['http://lua-users.org/wiki/StringLibraryTutorial'] = 'lua.txt',
  ['http://michael.toren.net/code/'] = 'pi_tar.txt',
  ['http://oldblog.antirez.com/post/redis-and-scripting.html'] = 'faq.txt',
  ['http://papp.plan9.de'] = 'syntax.txt',
  ['http://vimcasts.org'] = 'intro.txt',
  ['http://wiki.services.openoffice.org/wiki/Dictionaries'] = 'spell.txt',
  ['http://www.adapower.com'] = 'ft_ada.txt',
  ['http://www.jclark.com/'] = 'quickfix.txt',
  ['https://cacm.acm.org/research/a-look-at-the-design-of-lua/'] = 'faq.txt', -- blocks GHA?
  ['https://linux.die.net/man/2/poll'] = 'luvref.txt', -- blocks GHA?
}

-- Deprecated, brain-damaged files that I don't care about.
local ignore_errors = {
  ['pi_netrw.txt'] = true,
  ['credits.txt'] = true,
}

local function tofile(fname, text)
  local f = io.open(fname, 'w')
  if not f then
    error(('failed to write: %s'):format(f))
  else
    f:write(text)
    f:close()
  end
end

---@type fun(s: string): string
local function html_esc(s)
  return (s:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'))
end

local function url_encode(s)
  -- Credit: tpope / vim-unimpaired
  -- NOTE: these chars intentionally *not* escaped: ' ( )
  return vim.fn.substitute(
    vim.fn.iconv(s, 'latin1', 'utf-8'),
    [=[[^A-Za-z0-9()'_.~-]]=],
    [=[\="%".printf("%02X",char2nr(submatch(0)))]=],
    'g'
  )
end

local function to_titlecase(s)
  local text = ''
  for w in vim.gsplit(s, '[ \t]+') do
    text = ('%s %s%s'):format(text, vim.fn.toupper(w:sub(1, 1)), w:sub(2))
  end
  return text
end

local function to_heading_tag(text)
  -- Prepend "_" to avoid conflicts with actual :help tags.
  return text and string.format('_%s', vim.fn.tolower((text:gsub('%s+', '-')))) or 'unknown'
end

local function basename_noext(f)
  return vim.fs.basename(f:gsub('%.txt', ''))
end

local function is_blank(s)
  return not not s:find([[^[\t ]*$]])
end

---@type fun(s: string, dir?:0|1|2): string
local function trim(s, dir)
  return vim.fn.trim(s, '\r\t\n ', dir or 0)
end

--- Removes common punctuation from URLs.
---
--- NOTE: this is currently a no-op, since known issues were fixed in the parser:
--- https://github.com/neovim/tree-sitter-vimdoc/pull/157
---
--- @param url string
--- @return string, string (fixed_url, removed_chars) where `removed_chars` is in the order found in the input.
local function fix_url(url)
  local removed_chars = ''
  local fixed_url = url
  -- Remove up to one of each char from end of the URL, in this order.
  -- for _, c in ipairs({ '.', ')', ',' }) do
  --   if fixed_url:sub(-1) == c then
  --     removed_chars = c .. removed_chars
  --     fixed_url = fixed_url:sub(1, -2)
  --   end
  -- end
  return fixed_url, removed_chars
end

--- Checks if a given line is a "noise" line that doesn't look good in HTML form.
local function is_noise(line, noise_lines)
  if
    -- First line is always noise.
    (noise_lines ~= nil and vim.tbl_count(noise_lines) == 0)
    or line:find('Type .*gO.* to see the table of contents')
    -- Title line of traditional :help pages.
    -- Example: "NVIM REFERENCE MANUAL    by ..."
    or line:find([[^%s*N?VIM[ \t]*REFERENCE[ \t]*MANUAL]])
    -- First line of traditional :help pages.
    -- Example: "*api.txt*    Nvim"
    or line:find('%s*%*?[a-zA-Z]+%.txt%*?%s+N?[vV]im%s*$')
    -- modeline
    -- Example: "vim:tw=78:ts=8:sw=4:sts=4:et:ft=help:norl:"
    or line:find('^%s*vim?%:.*ft=help')
    or line:find('^%s*vim?%:.*filetype=help')
    or line:find('[*>]local%-additions[*<]')
  then
    -- table.insert(stats.noise_lines, getbuflinestr(root, opt.buf, 0))
    table.insert(noise_lines or {}, line)
    return true
  end
  return false
end

--- Creates a github issue URL at neovim/tree-sitter-vimdoc with prefilled content.
--- @return string
local function get_bug_url_vimdoc(fname, to_fname, sample_text)
  local this_url = string.format('https://neovim.io/doc/user/%s', vim.fs.basename(to_fname))
  local bug_url = (
    'https://github.com/neovim/tree-sitter-vimdoc/issues/new?labels=bug&title=parse+error%3A+'
    .. vim.fs.basename(fname)
    .. '+&body=Found+%60tree-sitter-vimdoc%60+parse+error+at%3A+'
    .. this_url
    .. '%0D%0DContext%3A%0D%0D%60%60%60%0D'
    .. url_encode(sample_text)
    .. '%0D%60%60%60'
  )
  return bug_url
end

--- Creates a github issue URL at neovim/neovim with prefilled content.
--- @return string
local function get_bug_url_nvim(fname, to_fname, sample_text, token_name)
  local this_url = string.format('https://neovim.io/doc/user/%s', vim.fs.basename(to_fname))
  local bug_url = (
    'https://github.com/neovim/neovim/issues/new?labels=bug&title=user+docs+HTML%3A+'
    .. vim.fs.basename(fname)
    .. '+&body=%60gen_help_html.lua%60+problem+at%3A+'
    .. this_url
    .. '%0D'
    .. (token_name and '+unhandled+token%3A+%60' .. token_name .. '%60' or '')
    .. '%0DContext%3A%0D%0D%60%60%60%0D'
    .. url_encode(sample_text)
    .. '%0D%60%60%60'
  )
  return bug_url
end

--- Gets a "foo.html" name from a "foo.txt" helpfile name.
local function get_helppage(f)
  if not f then
    return nil
  end
  -- Special case: help.txt is the "main landing page" of :help files, not index.txt.
  if f == 'index.txt' then
    return 'vimindex.html'
  elseif f == 'help.txt' then
    return 'index.html'
  end

  return (f:gsub('%.txt$', '')) .. '.html'
end

--- Counts leading spaces (tab=8) to decide the indent size of multiline text.
---
--- Blank lines (empty or whitespace-only) are ignored.
local function get_indent(s)
  local _, indent = vim.text.indent(0, s, { expandtab = 8 })
  return indent
end

--- Removes the common indent level, after expanding tabs to 8 spaces.
local function trim_indent(s)
  return (vim.text.indent(0, s, { expandtab = 8 }))
end

--- Gets raw buffer text in the node's range (+/- an offset), as a newline-delimited string.
---@param node TSNode
---@param bufnr integer
---@param offset integer
local function getbuflinestr(node, bufnr, offset)
  local line1, _, line2, _ = node:range()
  line1 = line1 - offset
  line2 = line2 + offset
  local lines = vim.fn.getbufline(bufnr, line1 + 1, line2 + 1)
  return table.concat(lines, '\n')
end

--- Gets the whitespace just before `node` from the raw buffer text.
--- Needed for preformatted `old` lines.
---@param node TSNode
---@param bufnr integer
---@return string
local function getws(node, bufnr)
  local line1, c1, line2, _ = node:range()
  ---@type string
  local raw = vim.fn.getbufline(bufnr, line1 + 1, line2 + 1)[1]
  local text_before = raw:sub(1, c1)
  local leading_ws = text_before:match('%s+$') or ''
  return leading_ws
end

local function get_tagname(node, bufnr)
  local text = vim.treesitter.get_node_text(node, bufnr)
  local tag = (node:type() == 'optionlink' or node:parent():type() == 'optionlink')
      and ("'%s'"):format(text)
    or text
  local helpfile = vim.fs.basename(tagmap[tag]) or nil -- "api.txt"
  local helppage = get_helppage(helpfile) -- "api.html"
  return helppage, tag
end

--- Returns true if the given invalid tagname is a false positive.
local function ignore_invalid(s)
  return not not (
    exclude_invalid[s]
    -- Strings like |~/====| appear in various places and the parser thinks they are links, but they
    -- are just table borders.
    or s:find('===')
    or s:find('%-%-%-')
  )
end

local function ignore_parse_error(fname, s)
  if ignore_errors[vim.fs.basename(fname)] then
    return true
  end
  -- Ignore parse errors for unclosed tag.
  -- This is common in vimdocs and is treated as plaintext by :help.
  return s:find("^[`'|*]")
end

---@param node TSNode
local function has_ancestor(node, ancestor_name)
  local p = node ---@type TSNode?
  while p do
    p = p:parent()
    if not p or p:type() == 'help_file' then
      break
    elseif p:type() == ancestor_name then
      return true
    end
  end
  return false
end

--- Gets the first matching child node matching `name`.
---@param node TSNode
local function first(node, name)
  for c, _ in node:iter_children() do
    if c:named() and c:type() == name then
      return c
    end
  end
  return nil
end

--- Gets the kind and node text of the previous and next siblings of node `n`.
--- @param n any node
local function get_prev_next(n)
  -- Previous sibling kind (string).
  local prev = n:prev_sibling()
      and (n:prev_sibling().named and n:prev_sibling():named())
      and n:prev_sibling():type()
    or nil
  -- Next sibling kind (string).
  local next_ = n:next_sibling()
      and (n:next_sibling().named and n:next_sibling():named())
      and n:next_sibling():type()
    or nil
  return prev, next_
end

local function validate_link(node, bufnr, fname)
  local helppage, tagname = get_tagname(node:child(1), bufnr)
  local ignored = false
  if not tagmap[tagname] then
    ignored = has_ancestor(node, 'column_heading') or node:has_error() or ignore_invalid(tagname)
    if not ignored then
      invalid_links[tagname] = vim.fs.basename(fname)
    end
  end
  return helppage, tagname, ignored
end

local function validate_url(text, fname, check_unreachable)
  fname = vim.fs.basename(fname)
  local ignored = ignore_errors[fname] or exclude_invalid_urls[text]
  if ignored then
    return true
  end
  if check_unreachable then
    vim.net.request(text, { retry = 2 }, function(err, _)
      if err then
        invalid_urls[text] = fname
      end
      pending_urls = pending_urls - 1
    end)
    pending_urls = pending_urls + 1
  else
    if text:find('http%:') then
      invalid_urls[text] = fname
    end
  end
  return false
end

--- Traverses the tree at `root` and checks that |tag| links point to valid helptags.
---@param root TSNode
---@param level integer
---@param lang_tree TSTree
---@param opt table
---@param stats table
local function visit_validate(root, level, lang_tree, opt, stats)
  level = level or 0

  local function node_text(node)
    return vim.treesitter.get_node_text(node or root, opt.buf)
  end

  local text = trim(node_text())
  local node_name = (root.named and root:named()) and root:type() or nil
  -- Parent kind (string).
  local parent = root:parent() and root:parent():type() or nil
  local toplevel = level < 1
  -- local prev, next_ = get_prev_next(root)
  local prev_text = root:prev_sibling() and node_text(root:prev_sibling()) or nil
  local next_text = root:next_sibling() and node_text(root:next_sibling()) or nil

  if root:child_count() > 0 then
    for node, _ in root:iter_children() do
      if node:named() then
        visit_validate(node, level + 1, lang_tree, opt, stats)
      end
    end
  end

  if node_name == 'ERROR' then
    if ignore_parse_error(opt.fname, text) then
      return
    end
    -- Store the raw text to give context to the error report.
    local sample_text = not toplevel and getbuflinestr(root, opt.buf, 0) or '[top level!]'
    -- Flatten the sample text to a single, truncated line.
    sample_text = vim.trim(sample_text):gsub('[\t\n]', ' '):sub(1, 80)
    table.insert(stats.parse_errors, sample_text)
  elseif
    (node_name == 'word' or node_name == 'uppercase_name')
    and (not vim.tbl_contains({ 'codespan', 'taglink', 'tag' }, parent))
  then
    local text_nopunct = vim.fn.trim(text, '.,', 0) -- Ignore some punctuation.
    local fname_basename = assert(vim.fs.basename(opt.fname))
    if spell_dict[text_nopunct] then
      local should_ignore = (
        spell_ignore_files[fname_basename] == true
        or vim.tbl_contains(
          (spell_ignore_files[fname_basename] or {}) --[[ @as string[] ]],
          text_nopunct
        )
        or (spell_punc[next_text] or spell_punc[prev_text])
      )
      if not should_ignore then
        invalid_spelling[text_nopunct] = invalid_spelling[text_nopunct] or {}
        invalid_spelling[text_nopunct][fname_basename] = node_text(root:parent())
      end
    end
  elseif node_name == 'url' then
    local fixed_url, _ = fix_url(trim(text))
    validate_url(fixed_url, opt.fname, opt.request_urls)
  elseif node_name == 'taglink' or node_name == 'optionlink' then
    local _, _, _ = validate_link(root, opt.buf, opt.fname)
  end
end

-- Fix tab alignment issues caused by concealed characters like |, `, * in tags
-- and code blocks.
---@param text string
---@param next_node_text string
local function fix_tab_after_conceal(text, next_node_text)
  -- Vim tabs take into account the two concealed characters even though they
  -- are invisible, so we need to add back in the two spaces if this is
  -- followed by a tab to make the tab alignment to match Vim's behavior.
  if string.sub(next_node_text, 1, 1) == '\t' then
    text = text .. '  '
  end
  return text
end

---@class (exact) nvim.gen_help_html.heading
---@field name string
---@field subheadings nvim.gen_help_html.heading[]
---@field tag string

-- Generates HTML from node `root` recursively.
---@param root TSNode
---@param level integer
---@param lang_tree TSTree
---@param headings nvim.gen_help_html.heading[]
---@param opt table
---@param stats table
local function visit_node(root, level, lang_tree, headings, opt, stats)
  level = level or 0

  local function node_text(node, ws_)
    node = node or root
    ws_ = (ws_ == nil or ws_ == true) and getws(node, opt.buf) or ''
    return string.format('%s%s', ws_, vim.treesitter.get_node_text(node, opt.buf))
  end

  -- Gets leading whitespace of `node`.
  local function ws(node)
    node = node or root
    local ws_ = getws(node, opt.buf)
    -- XXX: first node of a (line) includes whitespace, even after
    -- https://github.com/neovim/tree-sitter-vimdoc/pull/31 ?
    if ws_ == '' then
      ws_ = vim.treesitter.get_node_text(node, opt.buf):match('^%s+') or ''
    end
    return ws_
  end

  local node_name = (root.named and root:named()) and root:type() or nil
  local prev, next_ = get_prev_next(root)
  -- Parent kind (string).
  local parent = root:parent() and root:parent():type() or nil

  local text = ''
  local trimmed ---@type string
  if root:named_child_count() == 0 or node_name == 'ERROR' then
    text = node_text()
    trimmed = html_esc(trim(text))
    text = html_esc(text)
  else
    -- Process children and join them with whitespace.
    for node, _ in root:iter_children() do
      if node:named() then
        local r = visit_node(node, level + 1, lang_tree, headings, opt, stats)
        text = string.format('%s%s', text, r)
      end
    end
    trimmed = trim(text)
  end

  if node_name == 'help_file' then -- root node
    return text
  -- elseif node_name == 'url' then
  --   local fixed_url, removed_chars = fix_url(trimmed)
  --   return ('%s<a href="%s">%s</a>%s'):format(ws(), fixed_url, fixed_url, removed_chars)
  elseif node_name == 'word' or node_name == 'uppercase_name' then
    return text
  elseif node_name == 'note' then
    return ('\\textbf{%s}'):format(text)
  elseif node_name == 'h1' or node_name == 'h2' or node_name == 'h3' then
    if is_noise(text, stats.noise_lines) then
      return '' -- Discard common "noise" lines.
    end
    -- -- Remove tags from ToC text.
    -- local heading_node = first(root, 'heading')
    -- local hname = trim(node_text(heading_node):gsub('%*.*%*', ''))
    -- if not heading_node or hname == '' then
    --   return '' -- Spurious "===" or "---" in the help doc.
    -- end
    --
    -- -- Generate an anchor id from the heading text.
    -- local tagname = to_heading_tag(hname)
    -- if node_name == 'h1' or #headings == 0 then
    --   ---@type nvim.gen_help_html.heading
    --   local heading = { name = hname, subheadings = {}, tag = tagname }
    --   headings[#headings + 1] = heading
    -- else
    --   table.insert(
    --     headings[#headings].subheadings,
    --     { name = hname, subheadings = {}, tag = tagname }
    --   )
    -- end
    if node_name == 'h1' then
      return ('\\section{%s}'):format(trimmed)
    elseif node_name == 'h1' then
      return ('\\subsection{%s}'):format(trimmed)
    else -- Has to be h3
      return ('\\subsubsection{%s}'):format(trimmed)
    end
  elseif node_name == 'heading' then
    return trimmed
  -- elseif node_name == 'column_heading' or node_name == 'column_name' then
  --   if root:has_error() then
  --     return text
  --   end
  --   return ('<div class="help-column_heading">%s</div>'):format(text)
  elseif node_name == 'block' then
    if is_blank(text) then
      return ''
    end
    return text .. '\n\n'
    -- if opt.old then
    --   -- XXX: Treat "old" docs as preformatted: they use indentation for layout.
    --   --      Trim trailing newlines to avoid too much whitespace between divs.
    --   return ('<div class="old-help-para">%s</div>\n'):format(trim(text, 2))
    -- end
    -- return string.format('<div class="help-para">\n%s\n</div>\n', text)
  elseif node_name == 'line' then
    return text .. ' '
  --   if
  --     (parent ~= 'codeblock' or parent ~= 'code')
  --     and (is_blank(text) or is_noise(text, stats.noise_lines))
  --   then
  --     return '' -- Discard common "noise" lines.
  --   end
  --   -- XXX: Avoid newlines (too much whitespace) after block elements in old (preformatted) layout.
  --   local div = opt.old
  --     and root:child(0)
  --     and vim.list_contains({ 'column_heading', 'h1', 'h2', 'h3' }, root:child(0):type())
  --   return string.format('%s%s', div and trim(text) or text, div and '' or '\n')
  elseif parent == 'line_li' and node_name == 'prefix' then
    return ''
  -- elseif node_name == 'line_li' then
  --   local prefix = first(root, 'prefix')
  --   local numli = prefix and trim(node_text(prefix)):match('%d') -- Numbered listitem?
  --   local sib = root:prev_sibling()
  --   local prev_li = sib and sib:type() == 'line_li'
  --   local cssclass = numli and 'help-li-num' or 'help-li'
  --
  --   if not prev_li then
  --     opt.indent = 1
  --   else
  --     local sib_ws = ws(sib)
  --     local this_ws = ws()
  --     if get_indent(node_text()) == 0 then
  --       opt.indent = 1
  --     elseif this_ws > sib_ws then
  --       -- Previous sibling is logically the _parent_ if it is indented less.
  --       opt.indent = opt.indent + 1
  --     elseif this_ws < sib_ws then
  --       -- TODO(justinmk): This is buggy. Need to track exact whitespace length for each level.
  --       opt.indent = math.max(1, opt.indent - 1)
  --     end
  --   end
  --   local margin = opt.indent == 1 and '' or ('margin-left: %drem;'):format((1.5 * opt.indent))
  --
  --   return string.format('<div class="%s" style="%s">%s</div>', cssclass, margin, text)
  -- elseif node_name == 'taglink' or node_name == 'optionlink' then
  --   local helppage, tagname, ignored = validate_link(root, opt.buf, opt.fname)
  --   if ignored or not helppage then
  --     return html_esc(node_text(root))
  --   end
  --   local s = ('%s<a href="%s#%s">%s</a>'):format(
  --     ws(),
  --     helppage,
  --     url_encode(tagname),
  --     html_esc(tagname)
  --   )
  --   if opt.old and node_name == 'taglink' then
  --     s = fix_tab_after_conceal(s, node_text(root:next_sibling()))
  --   end
  --   return s
  elseif vim.list_contains({ 'codespan', 'keycode' }, node_name) then
    if root:has_error() then
      return text
    end
    local s = ('%s\\texttt{%s}'):format(ws(), trimmed)
    -- TODO
    -- if opt.old and node_name == 'codespan' then
    --   s = fix_tab_after_conceal(s, node_text(root:next_sibling()))
    -- end
    return s
  -- elseif node_name == 'argument' then
  --   return ('%s<code>%s</code>'):format(ws(), trim(node_text(root)))
  elseif node_name == 'codeblock' then
    return text
  -- elseif node_name == 'language' then
  --   language = node_text(root)
  --   return ''
  -- elseif node_name == 'code' then -- Highlighted codeblock (child).
  --   if is_blank(text) then
  --     return ''
  --   end
  --   local code ---@type string
  --   if language then
  --     code = ('<pre><code class="language-%s">%s</code></pre>'):format(
  --       language,
  --       trim(trim_indent(text), 2)
  --     )
  --     language = nil
  --   else
  --     code = ('<pre>%s</pre>'):format(trim(trim_indent(text), 2))
  --   end
  --   return code
  -- elseif node_name == 'tag' then -- anchor, h4 pseudo-heading
  --   if root:has_error() then
  --     return text
  --   end
  --   local in_heading = vim.list_contains({ 'h1', 'h2', 'h3' }, parent)
  --   local h4 = not in_heading and not next_ and get_indent(node_text()) > 8 -- h4 pseudo-heading
  --   local cssclass = h4 and 'help-tag-right' or 'help-tag'
  --   local tagname = node_text(root:child(1), false)
  --   if vim.tbl_count(stats.first_tags) < 2 then
  --     -- Force the first 2 tags in the doc to be anchored at the main heading.
  --     table.insert(stats.first_tags, tagname)
  --     return ''
  --   end
  --   local el = 'span'
  --   local encoded_tagname = url_encode(tagname)
  --   local s = ('%s<%s id="%s" class="%s"><a href="#%s">%s</a></%s>'):format(
  --     ws(),
  --     el,
  --     encoded_tagname,
  --     cssclass,
  --     encoded_tagname,
  --     trimmed,
  --     el
  --   )
  --   if opt.old then
  --     s = fix_tab_after_conceal(s, node_text(root:next_sibling()))
  --   end
  --
  --   if in_heading and prev ~= 'tag' then
  --     -- Start the <span> container for tags in a heading.
  --     -- This makes "justify-content:space-between" right-align the tags.
  --     --    <h2>foo bar<span>tag1 tag2</span></h2>
  --     return string.format('<span class="help-heading-tags">%s', s)
  --   elseif in_heading and next_ == nil then
  --     -- End the <span> container for tags in a heading.
  --     return string.format('%s</span>', s)
  --   end
  --   return s .. (h4 and '<br>' or '') -- HACK: <br> avoids h4 pseudo-heading mushing with text.
  -- elseif node_name == 'delimiter' or node_name == 'modeline' then
  --   return ''
  -- elseif node_name == 'ERROR' then
  --   if ignore_parse_error(opt.fname, trimmed) then
  --     return text
  --   end
  --
  --   -- Store the raw text to give context to the bug report.
  --   local sample_text = level > 0 and getbuflinestr(root, opt.buf, 3) or '[top level!]'
  --   table.insert(stats.parse_errors, sample_text)
  --   return ('<a class="parse-error" target="_blank" title="Report bug... (parse error)" href="%s">%s</a>'):format(
  --     get_bug_url_vimdoc(opt.fname, opt.to_fname, sample_text),
  --     trimmed
  --   )
  -- else -- Unknown token.
  --   local sample_text = level > 0 and getbuflinestr(root, opt.buf, 3) or '[top level!]'
  --   return ('<a class="unknown-token" target="_blank" title="Report bug... (unhandled token "%s")" href="%s">%s</a>'):format(
  --     node_name,
  --     get_bug_url_nvim(opt.fname, opt.to_fname, sample_text, node_name),
  --     trimmed
  --   ),
  --     ('unknown-token:"%s"'):format(node_name)

  else
    return 'U-' .. node_name:gsub("_", "-") -- LaTeX doesn't like underscores
  end
end

--- @param dir string e.g. '$VIMRUNTIME/doc'
--- @param include string[]|nil
--- @return string[]
local function get_helpfiles(dir, include)
  local rv = {}
  for f, type in vim.fs.dir(dir) do
    if
      vim.endswith(f, '.txt')
      and type == 'file'
      and (not include or vim.list_contains(include, f))
    then
      local fullpath = vim.fn.fnamemodify(('%s/%s'):format(dir, f), ':p')
      table.insert(rv, fullpath)
    end
  end
  return rv
end

--- Populates the helptags map.
local function _get_helptags(help_dir)
  local m = {}
  -- Load a random help file to convince taglist() to do its job.
  vim.cmd(string.format('split %s/api.txt', help_dir))
  vim.cmd('lcd %:p:h')
  for _, item in ipairs(vim.fn.taglist('.*')) do
    if vim.endswith(item.filename, '.txt') then
      m[item.name] = item.filename
    end
  end
  vim.cmd('q!')

  return m
end

--- Populates the helptags map.
local function get_helptags(help_dir)
  local m = _get_helptags(help_dir)

  --- XXX: Append tags from netrw, until we remove it...
  local netrwtags = _get_helptags(vim.fs.normalize('$VIMRUNTIME/pack/dist/opt/netrw/doc/'))
  m = vim.tbl_extend('keep', m, netrwtags)

  return m
end

--- Use the vimdoc parser defined in the build, not whatever happens to be installed on the system.
local function ensure_runtimepath()
  if not vim.o.runtimepath:find('build/lib/nvim/') then
    vim.cmd [[set runtimepath^=./build/lib/nvim/]]
  end
end

--- Opens `fname` (or `text`, if given) in a buffer and gets a treesitter parser for the buffer contents.
---
--- @param fname string :help file to parse
--- @param text string? :help file contents
--- @return vim.treesitter.LanguageTree, integer (lang_tree, bufnr)
local function parse_buf(fname, text)
  local buf ---@type integer

  if text then
    vim.cmd('split new') -- Text contents.
    vim.api.nvim_put(vim.split(text, '\n'), '', false, false)
    vim.cmd('setfiletype help')
    buf = vim.api.nvim_get_current_buf()
  elseif type(fname) == 'string' then
    vim.cmd('split ' .. vim.fn.fnameescape(fname)) -- Filename.
    buf = vim.api.nvim_get_current_buf()
  else
    -- Left for debugging
    ---@diagnostic disable-next-line: no-unknown
    buf = fname
    vim.cmd('sbuffer ' .. tostring(fname)) -- Buffer number.
  end
  local lang_tree = assert(vim.treesitter.get_parser(buf, nil, { error = false }))
  lang_tree:parse()
  return lang_tree, buf
end

--- Validates one :help file `fname`:
---  - checks that |tag| links point to valid helptags.
---  - recursively counts parse errors ("ERROR" nodes)
---
--- @param fname string help file to validate
--- @param request_urls boolean? whether to make requests to the URLs
--- @return { invalid_links: number, parse_errors: string[] }
local function validate_one(fname, request_urls)
  local stats = {
    parse_errors = {},
  }
  local lang_tree, buf = parse_buf(fname, nil)
  for _, tree in ipairs(lang_tree:trees()) do
    visit_validate(tree:root(), 0, tree, {
      buf = buf,
      fname = fname,
      request_urls = request_urls,
    }, stats)
  end
  lang_tree:destroy()
  vim.cmd.close()
  return stats
end

--- Generates LaTeX from one :help file `fname` and writes the result to `to_fname`.
---
--- @param fname string Source :help file.
--- @param text string|nil Source :help file contents, or nil to read `fname`.
--- @param to_fname string Destination .html file
--- @param old boolean Preformat paragraphs (for old :help files which are full of arbitrary whitespace)
---
--- @return string html
--- @return table stats
local function gen_one(fname, text, to_fname, old, commit)
  local stats = {
    noise_lines = {},
    parse_errors = {},
    first_tags = {}, -- Track the first few tags in doc.
  }
  local lang_tree, buf = parse_buf(fname, text)
  ---@type nvim.gen_help_html.heading[]
  local headings = {} -- Headings (for ToC). 2-dimensional: h1 contains h2/h3.
  local title = to_titlecase(basename_noext(fname))

  local latex = ([[\documentclass{book}

\title{Neovim user documentation}
\author{Neovim contributors}
\date{\today}

\begin{document}

\maketitle

]]):format(title)


  local main = ''
  for _, tree in ipairs(lang_tree:trees()) do
    main = main
      .. (
        visit_node(
          tree:root(),
          0,
          tree,
          headings,
          { buf = buf, old = old, fname = fname, to_fname = to_fname, indent = 1 },
          stats
        )
      )
  end

  local footer = '\\end{document}'
  latex = ('%s%s\n\n%s'):format(latex, main, footer)

  vim.cmd('q!')
  lang_tree:destroy()
  return latex, stats
end

--- Generates an HTML page that does a client-side redirect to the tag given by the "?tag=…"
--- querystring parameter. The page gets tags from the "helptags.json" file.
local function gen_helptag_html(fname)
  local html = [[
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <title>Redirecting…</title>
      <script type="module">
        async function do_redirect() {
          const errorDiv = document.getElementById('error-message');
          try {
            const params = new URLSearchParams(window.location.search)
            const tag = params.get('tag')
            if (!tag) {
              throw new Error('No tag parameter')
            }

            // helptags.json lives next to helptag.html
            const res = await fetch('./helptags.json')
            if (!res.ok) {
              throw new Error('helptags.json not found')
            }

            const tagmap = await res.json()
            if (!tagmap[tag]) {
              throw new Error('helptag not found: "' + tag + '"')
            }

            window.location.href = tagmap[tag]
          } catch (err) {
            console.error(err)
            if (errorDiv) {
              errorDiv.textContent = err.message
            }
            // Optionally, redirect to index after showing error
            // setTimeout(() => window.location.href = './index.html', 3000)
          }
        }

        do_redirect()
      </script>
    </head>
    <body>
      <p>Redirecting…</p>
      <div id="error-message" style="margin-top:1em; font-family: ui-monospace,SFMono-Regular,SF Mono,Menlo,Consolas,Liberation Mono,monospace;"></div>
    </body>
    </html>
  ]]
  tofile(fname, html)
end

--- Generates a JSON map of tags to URL-encoded `filename#anchor` locations.
---
---@param fname string
local function gen_helptags_json(fname)
  assert(tagmap, '`tagmap` not generated yet')
  local t = {} ---@type table<string, string>
  for tag, f in pairs(tagmap) do
    -- "foo.txt"
    local helpfile = vim.fs.basename(f)
    -- "foo.html"
    local htmlpage = assert(get_helppage(helpfile))
    -- "foo.html#tag"
    t[tag] = ('%s#%s'):format(htmlpage, url_encode(tag))
  end
  tofile(fname, vim.json.encode(t, { indent = '  ', sort_keys = true }))
end

local function gen_css(fname)
  local css = [[
    :root {
      --code-color: #004b4b;
      --tag-color: #095943;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --code-color: #00c243;
        --tag-color: #00b7b7;
      }
    }
    @media (min-width: 40em) {
      .toc {
        position: fixed;
        left: 67%;
      }
      .golden-grid {
          display: grid;
          grid-template-columns: 65% auto;
          grid-gap: 1em;
      }
    }
    @media (max-width: 40em) {
      .golden-grid {
        /* Disable grid for narrow viewport (mobile phone). */
        display: block;
      }
    }
    .toc {
      /* max-width: 12rem; */
      height: 85%;  /* Scroll if there are too many items. https://github.com/neovim/neovim.github.io/issues/297 */
      overflow: auto;  /* Scroll if there are too many items. https://github.com/neovim/neovim.github.io/issues/297 */
    }
    .toc > div {
      text-overflow: ellipsis;
      overflow: hidden;
      white-space: nowrap;
    }
    html {
      scroll-behavior: auto;
    }
    body {
      font-size: 18px;
      line-height: 1.5;
    }
    h1, h2, h3, h4, h5 {
      font-family: sans-serif;
      border-bottom: 1px solid var(--tag-color); /*rgba(0, 0, 0, .9);*/
    }
    h3, h4, h5 {
      border-bottom-style: dashed;
    }
    .help-column_heading {
      color: var(--code-color);
    }
    .help-body {
      padding-bottom: 2em;
    }
    .help-line {
      /* font-family: ui-monospace,SFMono-Regular,SF Mono,Menlo,Consolas,Liberation Mono,monospace; */
    }
    .help-li {
      display: list-item;
      white-space: normal;
      margin-left: 1.5rem; /* padding-left: 1rem; */
      /* margin-top: .1em; */
      /* margin-bottom: .1em; */
    }
    .help-li-num {
      display: list-item;
      list-style: none;
      /* Sibling UNordered help-li items will increment the builtin counter :( */
      /* list-style-type: decimal; */
      white-space: normal;
      margin-left: 1.5rem; /* padding-left: 1rem; */
      margin-top: .1em;
      margin-bottom: .1em;
    }
    .help-li-num::before {
      margin-left: -1em;
      counter-increment: my-li-counter;
      content: counter(my-li-counter) ". ";
    }
    .help-para {
      padding-top: 10px;
      padding-bottom: 10px;
      counter-reset: my-li-counter; /* Manually manage listitem numbering. */
    }

    .old-help-para {
      padding-top: 10px;
      padding-bottom: 10px;
      /* Tabs are used for alignment in old docs, so we must match Vim's 8-char expectation. */
      tab-size: 8;
      white-space: pre-wrap;
      font-size: 16px;
      font-family: ui-monospace,SFMono-Regular,SF Mono,Menlo,Consolas,Liberation Mono,monospace;
      word-wrap: break-word;
      counter-reset: my-li-counter; /* Manually manage listitem numbering. */
    }
    .old-help-para pre, .old-help-para pre:hover {
      /* Text following <pre> is already visually separated by the linebreak. */
      margin-bottom: 0;
      /* Long lines that exceed the textwidth should not be wrapped (no "pre-wrap").
         Since text may overflow horizontally, we make the contents to be scrollable
         (only if necessary) to prevent overlapping with the navigation bar at the right. */
      white-space: pre;
      overflow-x: auto;
    }

    /* TODO: should this rule be deleted? help tags are rendered as <code> or <span>, not <a> */
    a.help-tag, a.help-tag:focus, a.help-tag:hover {
      color: inherit;
      text-decoration: none;
    }
    .help-tag {
      color: var(--tag-color);
    }
    /* Tag pseudo-header common in :help docs. */
    .help-tag-right {
      color: var(--tag-color);
      margin-left: auto;
      margin-right: 0;
      float: right;
      display: block;
    }
    .help-tag a,
    .help-tag-right a {
      color: inherit;
    }
    .help-tag a:not(:hover),
    .help-tag-right a:not(:hover) {
      text-decoration: none;
    }
    h1 .help-tag, h2 .help-tag, h3 .help-tag {
      font-size: smaller;
    }
    .help-heading {
      white-space: normal;
      display: flex;
      flex-flow: row wrap;
      justify-content: space-between;
      gap: 0 15px;
    }
    /* The (right-aligned) "tags" part of a section heading. */
    .help-heading-tags {
      margin-right: 10px;
    }
    .help-toc-h1 {
    }
    .help-toc-h2 {
      margin-left: 1em;
    }
    .parse-error {
      background-color: red;
    }
    .unknown-token {
      color: black;
      background-color: yellow;
    }
    code {
      color: var(--code-color);
      font-size: 16px;
    }
    pre {
      /* Tabs are used in codeblocks only for indentation, not alignment, so we can aggressively shrink them. */
      tab-size: 2;
      white-space: pre-wrap;
      line-height: 1.3;  /* Important for ascii art. */
      overflow: visible;
      /* font-family: ui-monospace,SFMono-Regular,SF Mono,Menlo,Consolas,Liberation Mono,monospace; */
      font-size: 16px;
      margin-top: 10px;
    }
    pre:last-child {
      margin-bottom: 0;
    }
    pre:hover {
      overflow: visible;
    }
    .generator-stats {
      color: gray;
      font-size: smaller;
    }
  ]]
  tofile(fname, css)
end

-- Testing

local function ok(cond, expected, actual, message)
  assert(
    (not expected and not actual) or (expected and actual),
    'if "expected" is given, "actual" is also required'
  )
  if expected then
    assert(
      cond,
      ('%sexpected %s, got: %s'):format(
        message and (message .. '\n') or '',
        vim.inspect(expected),
        vim.inspect(actual)
      )
    )
  else
    assert(cond)
  end

  return true
end
local function eq(expected, actual, message)
  return ok(vim.deep_equal(expected, actual), expected, actual, message)
end

function M._test()
  tagmap = get_helptags('$VIMRUNTIME/doc')
  helpfiles = get_helpfiles(vim.fs.normalize('$VIMRUNTIME/doc'))

  ok(vim.tbl_count(tagmap) > 3000, '>3000', vim.tbl_count(tagmap))
  ok(
    vim.endswith(tagmap['vim.diagnostic.set()'], 'diagnostic.txt'),
    tagmap['vim.diagnostic.set()'],
    'diagnostic.txt'
  )
  ok(vim.endswith(tagmap['%:s'], 'cmdline.txt'), tagmap['%:s'], 'cmdline.txt')
  ok(is_noise([[vim:tw=78:isk=!-~,^*,^\|,^\":ts=8:noet:ft=help:norl:]]))
  ok(is_noise([[          NVIM  REFERENCE  MANUAL     by  Thiago  de  Arruda      ]]))
  ok(not is_noise([[vim:tw=78]]))

  eq(0, get_indent('a'))
  eq(1, get_indent(' a'))
  eq(2, get_indent('  a\n  b\n  c\n'))
  eq(5, get_indent('     a\n      \n        b\n      c\n      d\n      e\n'))
  eq(
    'a\n        \n   b\n c\n d\n e\n',
    trim_indent('     a\n             \n        b\n      c\n      d\n      e\n')
  )

  local fixed_url, removed_chars = fix_url('https://example.com).')
  eq('https://example.com', fixed_url)
  eq(').', removed_chars)
  fixed_url, removed_chars = fix_url('https://example.com.)')
  eq('https://example.com.', fixed_url)
  eq(')', removed_chars)
  fixed_url, removed_chars = fix_url('https://example.com.')
  eq('https://example.com', fixed_url)
  eq('.', removed_chars)
  fixed_url, removed_chars = fix_url('https://example.com)')
  eq('https://example.com', fixed_url)
  eq(')', removed_chars)
  fixed_url, removed_chars = fix_url('https://example.com')
  eq('https://example.com', fixed_url)
  eq('', removed_chars)

  print('all tests passed.\n')
end

--- @class nvim.gen_help_html.gen_result
--- @field helpfiles string[] list of generated HTML files, from the source docs {include}
--- @field err_count integer number of parse errors in :help docs
--- @field invalid_links table<string, any>

--- Generates HTML from :help docs located in `help_dir` and writes the result in `to_dir`.
---
--- Example:
---
---   gen('$VIMRUNTIME/doc', '/path/to/neovim.github.io/_site/doc/', {'api.txt', 'autocmd.txt', 'channel.txt'}, nil)
---
--- @param help_dir string Source directory containing the :help files. Must run `make helptags` first.
--- @param to_dir string Target directory where the .html files will be written.
--- @param include string[]|nil Process only these filenames. Example: {'api.txt', 'autocmd.txt', 'channel.txt'}
--- @param commit string?
--- @param parser_path string? path to non-default vimdoc.so/dylib/dll
---
--- @return nvim.gen_help_html.gen_result result
function M.gen(help_dir, to_dir, include, commit, parser_path)
  vim.validate('help_dir', help_dir, function(d)
    return vim.fn.isdirectory(vim.fs.normalize(d)) == 1
  end, 'valid directory')
  vim.validate('to_dir', to_dir, 'string')
  vim.validate('include', include, 'table', true)
  vim.validate('commit', commit, 'string', true)
  vim.validate('parser_path', parser_path, function(f)
    return vim.fn.filereadable(vim.fs.normalize(f)) == 1
  end, true, 'valid vimdoc.{so,dll,dylib} filepath')

  local err_count = 0
  local redirects_count = 0
  ensure_runtimepath()

  parser_path = parser_path and vim.fs.normalize(parser_path) or nil
  if parser_path then
    -- XXX: Delete the installed .so files first, else this won't work :(
    --    /usr/local/lib/nvim/parser/vimdoc.so
    --    ./build/lib/nvim/parser/vimdoc.so
    vim.treesitter.language.add('vimdoc', { path = parser_path })
  end

  tagmap = get_helptags(vim.fs.normalize(help_dir))
  helpfiles = get_helpfiles(help_dir, include)
  to_dir = vim.fs.normalize(to_dir)

  print(('output dir: %s\n\n'):format(to_dir))
  vim.fn.mkdir(to_dir, 'p')
  gen_css(('%s/help.css'):format(to_dir))
  gen_helptags_json(('%s/helptags.json'):format(to_dir))
  gen_helptag_html(('%s/helptag.html'):format(to_dir))

  for _, f in ipairs(helpfiles) do
    -- "foo.txt"
    local helpfile = vim.fs.basename(f)
    -- "to/dir/foo.html"
    -- local to_fname = ('%s/%s'):format(to_dir, get_helppage(helpfile))
    local to_fname = ('%s/foo.tex'):format(to_dir, get_helppage(helpfile))
    local html, stats = gen_one(f, nil, to_fname, not new_layout[helpfile], commit or '?')
    tofile(to_fname, html)
    print(
      ('generated (%-2s errors): %-15s => %s'):format(
        #stats.parse_errors,
        helpfile,
        vim.fs.basename(to_fname)
      )
    )

    err_count = err_count + #stats.parse_errors
  end

  print(('\ngenerated %d html pages'):format(#helpfiles + redirects_count))
  print(('total errors: %d'):format(err_count))
  -- Why aren't the netrw tags found in neovim/docs/ CI?
  print(('invalid tags: %s'):format(vim.inspect(invalid_links)))
  -- eq(redirects_count, include and redirects_count or vim.tbl_count(redirects)) -- sanity check
  print(('redirects: %d'):format(redirects_count))
  print('\n')

  --- @type nvim.gen_help_html.gen_result
  return {
    helpfiles = helpfiles,
    err_count = err_count,
    invalid_links = invalid_links,
  }
end

--- @class nvim.gen_help_html.validate_result
--- @field helpfiles integer number of generated helpfiles
--- @field err_count integer number of parse errors
--- @field parse_errors table<string, string[]>
--- @field invalid_links table<string, any> invalid tags in :help docs
--- @field invalid_urls table<string, any> invalid URLs in :help docs
--- @field invalid_spelling table<string, table<string, string>> invalid spelling in :help docs

--- Validates all :help files found in `help_dir`:
---  - checks that |tag| links point to valid helptags.
---  - recursively counts parse errors ("ERROR" nodes)
---
--- This is 10x faster than gen(), for use in CI.
---
--- @return nvim.gen_help_html.validate_result result
function M.validate(help_dir, include, parser_path, request_urls)
  vim.validate('help_dir', help_dir, function(d)
    return vim.fn.isdirectory(vim.fs.normalize(d)) == 1
  end, 'valid directory')
  vim.validate('include', include, 'table', true)
  vim.validate('parser_path', parser_path, function(f)
    return vim.fn.filereadable(vim.fs.normalize(f)) == 1
  end, true, 'valid vimdoc.{so,dll,dylib} filepath')
  local err_count = 0 ---@type integer
  local files_to_errors = {} ---@type table<string, string[]>
  ensure_runtimepath()

  parser_path = parser_path and vim.fs.normalize(parser_path) or nil
  if parser_path then
    -- XXX: Delete the installed .so files first, else this won't work :(
    --    /usr/local/lib/nvim/parser/vimdoc.so
    --    ./build/lib/nvim/parser/vimdoc.so
    vim.treesitter.language.add('vimdoc', { path = parser_path })
  end

  tagmap = get_helptags(vim.fs.normalize(help_dir))
  helpfiles = get_helpfiles(help_dir, include)

  for _, f in ipairs(helpfiles) do
    local helpfile = vim.fs.basename(f)
    local rv = validate_one(f, request_urls)
    print(('validated (%-4s errors): %s'):format(#rv.parse_errors, helpfile))
    if #rv.parse_errors > 0 then
      files_to_errors[helpfile] = rv.parse_errors
      vim.print(('%s'):format(vim.iter(rv.parse_errors):fold('', function(s, v)
        return s .. '\n    ' .. v
      end)))
    end
    err_count = err_count + #rv.parse_errors
  end

  -- Requests are async, wait for them to finish.
  -- TODO(yochem): `:cancel()` tasks after #36146
  vim.wait(20000, function()
    return pending_urls <= 0
  end)
  ok(pending_urls <= 0, 'pending url checks', pending_urls)

  ---@type nvim.gen_help_html.validate_result
  return {
    helpfiles = #helpfiles,
    err_count = err_count,
    parse_errors = files_to_errors,
    invalid_links = invalid_links,
    invalid_urls = invalid_urls,
    invalid_spelling = invalid_spelling,
  }
end

--- Validates vimdoc files in $VIMRUNTIME, and prints error messages on failure.
---
--- If this fails, try these steps (in order):
--- 1. Fix/cleanup the :help docs.
--- 2. Fix the parser: https://github.com/neovim/tree-sitter-vimdoc
--- 3. File a parser bug, and adjust the tolerance of this test in the meantime.
---
--- @param help_dir? string e.g. '$VIMRUNTIME/doc' or './runtime/doc'
--- @param request_urls? boolean make network requests to check if the URLs are reachable.
function M.run_validate(help_dir, request_urls)
  help_dir = vim.fs.normalize(help_dir or '$VIMRUNTIME/doc')
  print('doc path = ' .. vim.uv.fs_realpath(help_dir))

  local rv = M.validate(help_dir, nil, nil, request_urls)

  -- Check that we actually found helpfiles.
  ok(rv.helpfiles > 100, '>100 :help files', rv.helpfiles)

  eq({}, rv.parse_errors, 'no parse errors')
  eq(0, rv.err_count, 'no parse errors')
  eq({}, rv.invalid_links, 'invalid tags in :help docs')
  eq({}, rv.invalid_urls, 'invalid URLs in :help docs')
  eq(
    {},
    rv.invalid_spelling,
    'invalid spelling in :help docs (see spell_dict in src/gen/gen_help_html.lua)'
  )
end

--- Test-generates HTML from docs.
---
--- 1. Test that gen_help_html.lua actually works.
--- 2. Test that parse errors did not increase wildly. Because we explicitly test only a few
---    :help files, we can be precise about the tolerances here.
--- @param help_dir? string e.g. '$VIMRUNTIME/doc' or './runtime/doc'
function M.test_gen(help_dir)
  local tmpdir = vim.fs.dirname(vim.fn.tempname())
  help_dir = vim.fs.normalize(help_dir or '$VIMRUNTIME/doc')
  print('doc path = ' .. vim.uv.fs_realpath(help_dir))

  -- Because gen() is slow (~30s), this test is limited to a few files.
  local input = { 'api.txt', 'index.txt', 'nvim.txt' }
  local rv = M.gen(help_dir, tmpdir, input)
  eq(#input, #rv.helpfiles)
  eq(0, rv.err_count, 'parse errors in :help docs')
  eq({}, rv.invalid_links, 'invalid tags in :help docs')
end

return M
