--- Converts Nvim :help files to alternate formats (HTML, Typst, or "amalgamated" HTML page).
--- Validates |tag| links and document syntax (parser errors).
--
-- USAGE (For CI/local testing purposes): Simply `make lintdoc`, which basically does the following:
--   1. :helptags ALL
--   2. nvim -V1 -es +"lua require('src.gen.gen_help_html').run_validate()" +q
--   3. nvim -V1 -es +"lua require('src.gen.gen_help_html').test_gen()" +q
--
-- USAGE (GENERATE HTML):
--   1. `:helptags ALL` first; this script depends on vim.fn.taglist().
--   2. nvim -V1 -es --clean +"lua require('src.gen.gen_help_html').gen('html', './runtime/doc', 'target/dir/')" +q
--      - Read the docstring at gen().
--   3. cd target/dir/ && jekyll serve --host 0.0.0.0
--   4. Visit http://localhost:4000/…/help.txt.html
--
-- USAGE (GENERATE PDF VIA TYPST):
--   1. `:helptags ALL`
--   2. mkdir usr_manual pdf_docs
--   3. cp runtime/doc/usr_*.txt usr_manual/
--   4. nvim -V1 -es --clean +"lua require('src.gen.gen_help_html').gen('typ', './usr_manual', 'pdf_docs')" +q
--   5. mv pdf_docs/usr_toc.typ pdf_docs/user_manual.typ && cat pdf_docs/usr_*.typ >> pdf_docs/user_manual.typ
--   6. typst compile pdf_docs/user_manual.typ
--   7. open pdf_docs/user_manual.pdf
--
-- USAGE (GENERATE PDF VIA BROWSER):
--   1. `:helptags ALL`
--   2. nvim -V1 -es --clean +"lua require('src.gen.gen_help_html').gen('print', './runtime/doc', 'pdf_docs')" +q
--      - To print only some files, pass them (in order) as `include`. Example (user manual):
--        {'usr_toc.txt', unpack(vim.tbl_map(vim.fs.basename, vim.fn.glob('runtime/doc/usr_[0-9]*.txt', 0, 1)))}
--   3. chrome --headless --no-pdf-header-footer --disable-pdf-tagging --print-to-pdf=pdf_docs/nvim-help.pdf pdf_docs/print.html
--      (macOS: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
--   4. open pdf_docs/nvim-help.pdf
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
--   * This script is used by the website repo: https://github.com/neovim/neovim.github.io
--   * :helptags checks for duplicate tags, whereas this script checks _links_ (to tags).
--   * gen() and validate() are the primary (programmatic) entrypoints. validate() only exists
--     because gen() is too slow (~1 min) to run in per-commit CI.
--   * ts_node_to_html() is the core function used by gen() to traverse the document tree and produce HTML.
--   * visit_validate() is the core function used by validate().
--   * Files in `new_layout` will be generated with a "flow" layout instead of preformatted/fixed-width layout.
--
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
  ['api-ui-events.txt'] = true,
  ['api.txt'] = true,
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
  ['digraph.txt'] = true,
  ['faq.txt'] = true,
  ['fold.txt'] = true,
  ['ft_hare.txt'] = true,
  ['ft_ps1.txt'] = true,
  ['ft_raku.txt'] = true,
  ['ft_rust.txt'] = true,
  ['gui.txt'] = true,
  ['health.txt'] = true,
  ['help.txt'] = true,
  ['helphelp.txt'] = true,
  ['if_perl.txt'] = true,
  ['index.txt'] = true,
  ['intro.txt'] = true,
  ['job_control.txt'] = true,
  ['l10n-arabic.txt'] = true,
  ['l10n-russian.txt'] = true,
  ['l10n-vietnamese.txt'] = true,
  ['lsp.txt'] = true,
  ['lua-async.txt'] = true,
  ['lua-bit.txt'] = true,
  ['lua-guide.txt'] = true,
  ['lua-plugin.txt'] = true,
  ['lua.txt'] = true,
  ['luaref.txt'] = true,
  ['luvref.txt'] = true,
  ['mlang.txt'] = true,
  ['news-0.10.txt'] = true,
  ['news-0.11.txt'] = true,
  ['news-0.12.txt'] = true,
  ['news-0.9.txt'] = true,
  ['news.txt'] = true,
  ['nvim.txt'] = true,
  ['pack.txt'] = true,
  ['pattern.txt'] = true,
  ['pi_gzip.txt'] = true,
  ['pi_paren.txt'] = true,
  ['pi_spec.txt'] = true,
  ['pi_tutor.txt'] = true,
  ['plugins.txt'] = true,
  ['provider.txt'] = true,
  ['recover.txt'] = true,
  ['remote.txt'] = true,
  ['remote_plugin.txt'] = true,
  ['repeat.txt'] = true,
  ['rileft.txt'] = true,
  ['scroll.txt'] = true,
  ['starting.txt'] = true,
  ['support.txt'] = true,
  ['terminal.txt'] = true,
  ['treesitter.txt'] = true,
  ['tui.txt'] = true,
  ['ui.txt'] = true,
  ['vim_diff.txt'] = true,
  ['zip.txt'] = true,
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
  matchit = 'vim_diff.txt',
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

  -- Can't be accessed by GitHub runners:
  ['https://cacm.acm.org/research/a-look-at-the-design-of-lua/'] = 'faq.txt',
  ['https://linux.die.net/man/2/poll'] = 'luvref.txt',
  ['https://www.kuwasha.net'] = 'uganda.txt',
  ['https://www.kuwasha.net/'] = 'uganda.txt',
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
  local html_entity =
    { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['{'] = '&#123;', ['}'] = '&#125;' }
  return (s and string.gsub(s, '[&<>{}]', html_entity) or nil)
end

--- Escapes a string to make it valid Typst markup.
--- @param s string?
--- @return string
local function typ_esc(s)
  return (s and string.gsub(s, '([%[%]@#\\/<*`_^$])', '\\%1') or '')
end

--- Escapes a string for use in a Typst string literal, e.g. `#label("…")`.
--- @param s string?
--- @return string
local function typ_str_esc(s)
  return (s and string.gsub(s, '([\\"])', '\\%1') or '')
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

--- Checks if a given line is a "noise" line that doesn't look good in non-vimdoc formats.
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
    -- help.txt `*local-additions*` tag definition, not taglink.
    or line:find('[*"]local%-additions[*"]')
  then
    -- table.insert(stats.noise_lines, getbuflinestr(root, opt.buf, 0))
    table.insert(noise_lines or {}, line)
    return true
  end
  return false
end

--- Creates a github issue URL at neovim/tree-sitter-vimdoc with prefilled content.
--- @param fname string
--- @param to_fname string
--- @param sample_text string
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
--- @param fname string
--- @param to_fname string
--- @param sample_text string
--- @param token_name? string
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

--- Gets a "foo" name from a "foo.txt" helpfile name.
local function get_helppage_html(f, with_extension)
  if not f then
    return nil
  end
  -- Special case: help.txt is the "main landing page" of :help files, not index.txt.
  if f == 'index.txt' then
    return with_extension and 'vimindex.html' or 'vimindex/'
  elseif f == 'help.txt' then
    -- Hugo needs an `_index.html` (note the underscore) file to recognize it as section
    return with_extension and '_index.html' or ''
  end

  return (f:gsub('%.txt$', '')) .. (with_extension and '.html' or '/')
end

--- Removes the common indent level, after expanding tabs to 8 spaces.
local function trim_indent(s)
  return (vim.text.indent(0, s, { expandtab = 8 }))
end

--- Gets the display column (tabstop 8) where `node` starts.
--- @param node TSNode
--- @param bufnr integer
local function get_col(node, bufnr)
  local row, col = node:range()
  local w = 0
  for c in vim.fn.getbufline(bufnr, row + 1)[1]:sub(1, col):gmatch('[^\128-\191][\128-\191]*') do
    w = c == '\t' and (w + 8 - w % 8) or (w + 1)
  end
  return w
end

--- Splits the named children of `node` into cells (tab-delimited).
---@param node TSNode
---@param bufnr integer
---@return TSNode[][]
local function get_table_cells(node, bufnr)
  local cells = { {} } ---@type TSNode[][]
  local prev ---@type TSNode?
  for child in node:iter_children() do
    if child:named() then
      local sr, sc = child:range()
      local _, _, pr, pc = (prev or child):range()
      if prev and table.concat(vim.api.nvim_buf_get_text(bufnr, pr, pc, sr, sc, {})):find('\t') then
        cells[#cells + 1] = {}
      end
      table.insert(cells[#cells], child)
      prev = child
    end
  end
  return cells
end

--- Gets the rows (header first) of `block` if it is a table, else nil. Each row is a list of cells,
--- each cell a list of nodes. Separator => empty row. See "Tables" in the tree-sitter-vimdoc README.
---@param block TSNode
---@param bufnr integer
---@return TSNode[][][]?
local function get_table(block, bufnr)
  local hdr = block:named_child(0) and block:named_child(0):named_child(0)
  if not hdr or hdr:type() ~= 'column_heading' then
    return nil
  end
  -- (column_heading (heading …) (delimiter))
  local rows = { get_table_cells(assert(hdr:named_child(0)), bufnr) } ---@type TSNode[][][]
  for i = 1, block:named_child_count() - 1 do
    local line = assert(block:named_child(i))
    local is_sep = vim.treesitter.get_node_text(line, bufnr):match('^[%s%-=~]+$')
    local row = not is_sep and get_table_cells(line, bufnr)
    local last = rows[#rows]
    local in_body = #rows > 1 and #last > 0 -- Last row is not the header or a separator.
    if is_sep and in_body then
      rows[#rows + 1] = {}
    elseif row and #row == 1 and in_body then
      vim.list_extend(last[#last], row[1]) -- Wrapped line continues last cell.
    elseif row then
      rows[#rows + 1] = row
    end
  end
  return #rows[1] > 1 and #rows > 1 and rows or nil
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

--- Gets the whitespace just before `node` from the raw buffer text (nodes don't include it, e.g.
--- it separates words).
---
---@param node TSNode
---@param bufnr integer
---@param conceal? boolean For preformatted `old` lines: Tab is preceded by a space for each char
---   concealed on the line since the previous Tab: Nvim widens the Tab by that much, so text after a
---   Tab stays at its raw column.
---@return string
local function getws(node, bufnr, conceal)
  local line1, c1, line2, _ = node:range()
  ---@type string
  local raw = vim.fn.getbufline(bufnr, line1 + 1, line2 + 1)[1]
  local text_before = raw:sub(1, c1)
  local leading_ws = text_before:match('%s+$') or ''
  if not conceal or not leading_ws:find('\t') then
    return leading_ws
  end

  -- TODO: Remove `conceal` when all docs are in `new_layout`.
  local n = 0
  local sib = node:prev_named_sibling()
  while sib and select(3, sib:range()) == line1 do
    n = n + (vim.list_contains({ 'taglink', 'tag', 'codespan' }, sib:type()) and 2 or 0)
    if getws(sib, bufnr):find('\t') then
      break
    end
    sib = sib:prev_named_sibling()
  end
  return (leading_ws:gsub('\t', ('%s\t'):format((' '):rep(n)), 1))
end

local function get_tagname(node, bufnr)
  local text = vim.treesitter.get_node_text(node, bufnr)
  local tag = (node:type() == 'optionlink' or node:parent():type() == 'optionlink')
      and ("'%s'"):format(text)
    or text
  local helpfile = vim.fs.basename(tagmap[tag]) or nil -- "api.txt"
  local helppage = get_helppage_html(helpfile) -- "api.html"
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

--- Gets the last child of `node`, or nil.
---@param node TSNode
local function last(node)
  local n = node:child_count()
  return n > 0 and node:child(n - 1) or nil
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
    local fname_basename = assert(vim.fs.basename(opt.fname --[[ @as string ]]))
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
local function ts_node_to_html(root, level, lang_tree, headings, opt, stats)
  level = level or 0

  local function node_text(node, ws_)
    node = node or root
    ws_ = (ws_ == nil or ws_ == true) and getws(node, opt.buf, opt.old) or ''
    return string.format('%s%s', ws_, vim.treesitter.get_node_text(node, opt.buf))
  end

  -- Gets leading whitespace of `node`.
  local function ws(node)
    node = node or root
    local ws_ = getws(node, opt.buf, opt.old)
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

  local table_rows = node_name == 'block' and get_table(root, opt.buf)
  if table_rows then
    local trs = {} ---@type string[]
    for i, row in ipairs(table_rows) do
      local tag = i == 1 and 'th' or 'td'
      local next_row = table_rows[i + 1]
      -- Empty row = separator.
      local attr = next_row and #next_row == 0 and ' class="help-table-sep"' or ''
      local cells = {} ---@type string[]
      for _, cell in ipairs(row) do
        local s = ''
        for _, node in ipairs(cell) do
          s = s .. ts_node_to_html(node, level + 1, lang_tree, headings, opt, stats)
        end
        cells[#cells + 1] = ('<%s>%s</%s>'):format(tag, trim(s), tag)
      end
      if #row > 0 then
        trs[#trs + 1] = ('<tr%s>%s</tr>'):format(attr, table.concat(cells))
      end
    end
    return ('<table class="help-table">\n<thead>%s</thead>\n<tbody>\n%s\n</tbody>\n</table>\n'):format(
      trs[1],
      table.concat(trs, '\n', 2)
    )
  end

  local text = ''
  local parts = {} ---@type string[] HTML of each named child.
  local trimmed ---@type string
  if root:named_child_count() == 0 or node_name == 'ERROR' then
    text = node_text()
    trimmed = html_esc(trim(text))
    text = html_esc(text)
  else
    -- Process children and join them with whitespace.
    for node, _ in root:iter_children() do
      if node:named() then
        parts[#parts + 1] = ts_node_to_html(node, level + 1, lang_tree, headings, opt, stats)
      end
    end
    text = table.concat(parts)
    trimmed = trim(text)
  end

  if node_name == 'help_file' then -- root node
    return text
  elseif node_name == 'url' then
    local fixed_url, removed_chars = fix_url(trimmed)
    return ('%s<a href="%s">%s</a>%s'):format(ws(), fixed_url, fixed_url, removed_chars)
  elseif node_name == 'word' or node_name == 'uppercase_name' then
    return text
  elseif node_name == 'note' then
    return ('<b>%s</b>'):format(text)
  elseif node_name == 'h1' or node_name == 'h2' or node_name == 'h3' then
    if is_noise(text, stats.noise_lines) then
      return '' -- Discard common "noise" lines.
    end
    -- Remove tags from ToC text.
    local heading_node = first(root, 'heading')
    local hname = trim(node_text(heading_node):gsub('%*.*%*', ''))
    if not heading_node or hname == '' then
      return '' -- Spurious "===" or "---" in the help doc.
    end

    -- Generate an anchor id from the heading text.
    local tagname = to_heading_tag(hname)
    if node_name == 'h1' or #headings == 0 then
      ---@type nvim.gen_help_html.heading
      local heading = { name = hname, subheadings = {}, tag = tagname }
      headings[#headings + 1] = heading
    else
      table.insert(
        headings[#headings].subheadings,
        { name = hname, subheadings = {}, tag = tagname }
      )
    end
    local el = node_name == 'h1' and 'h2' or 'h3'
    return ('<%s id="%s" class="help-heading">%s</%s>\n'):format(el, tagname, trimmed, el)
  elseif node_name == 'heading' then
    return trimmed
  elseif node_name == 'column_heading' or node_name == 'column_name' then
    if root:has_error() then
      return text
    end
    return ('<div class="help-column_heading">%s</div>'):format(text)
  elseif node_name == 'block' then
    if is_blank(text) then
      return ''
    end

    -- Conjoin list-item blocks: merge adjacent blocks that form a contiguous list.
    local prev_block = root:prev_sibling()
    local next_block = root:next_sibling()
    local prev_last = prev_block and prev_block:type() == 'block' and last(prev_block)
    local next_first = next_block and next_block:type() == 'block' and next_block:child(0)
    local continues_list = root:child(0)
      and root:child(0):type() == 'line_li'
      and prev_last
      and prev_last:type() == 'line_li'
    local list_continues = last(root)
      and last(root):type() == 'line_li'
      and next_first
      and next_first:type() == 'line_li'
    if continues_list and list_continues then
      return text
    elseif continues_list then
      -- Last continuation block: close the wrapper opened by the first block.
      if opt.old then
        return ('%s</div>\n'):format(trim(text, 2))
      end
      return string.format('%s\n</div>\n', text)
    elseif list_continues then
      -- First block of a list that continues: open wrapper but don't close.
      if opt.old then
        return ('<div class="old-help-para">%s'):format(trim(text, 2))
      end
      return string.format('<div class="help-para">\n%s', text)
    end

    if opt.old then
      -- XXX: Treat "old" docs as preformatted: they use indentation for layout.
      --      Trim trailing newlines to avoid too much whitespace between divs.
      return ('<div class="old-help-para">%s</div>\n'):format(trim(text, 2))
    end
    return string.format('<div class="help-para">\n%s\n</div>\n', text)
  elseif node_name == 'line' then
    if
      (parent ~= 'codeblock' and parent ~= 'code')
      and (is_blank(text) or is_noise(text, stats.noise_lines))
    then
      return '' -- Discard common "noise" lines.
    end
    if parent == 'codeblock' or parent == 'code' then
      return text -- Includes its newline.
    end

    -- Tags at EOL (not listitem) after Tab/2+ spaces are right-aligned, own div. |help-tag-heading|
    local t = #parts + 1 -- First trailing tag.
    while t > 1 and assert(root:named_child(t - 2)):type() == 'tag' do
      t = t - 1
    end
    local tags = table.concat(parts, '', t)
    local gap = tags:match('^%s*')
    local before = table.concat(parts, '', 1, t - 1)
    local tagspan = ('<span class="help-tag-right">%s</span>'):format(trim(tags))
    local is_heading = parent == 'block' and trim(tags) ~= '' and (#gap >= 2 or gap:find('\t'))
    if is_heading and opt.old then
      return ('%s%s%s\n'):format(before, gap, tagspan) -- Preformatted: the newline ends the line.
    elseif is_heading then
      return ('<div class="help-tag-heading">%s%s</div>\n'):format(before, tagspan)
    end

    -- XXX: Avoid newlines (too much whitespace) after block elements in old (preformatted) layout.
    local div = opt.old
      and root:child(0)
      and vim.list_contains({ 'column_heading', 'h1', 'h2', 'h3' }, root:child(0):type())
    return string.format('%s%s', div and trim(text) or text, div and '' or '\n')
  elseif parent == 'line_li' and node_name == 'prefix' then
    return ''
  elseif node_name == 'line_li' then
    local prefix = first(root, 'prefix')
    local numli = prefix and trim(node_text(prefix)):match('%d') -- Numbered listitem?
    local sib = root:prev_sibling()
    local prev_li = sib and sib:type() == 'line_li'
    local cssclass = numli and 'help-li-num' or 'help-li'

    -- Conjoin list items separated by blank lines (wrapped in separate blocks), unless the block
    -- starts with something else (then it's a new list).
    if not sib then
      local parent_block = root:parent()
      local prev_block = parent_block and parent_block:prev_sibling()
      local prev_last = prev_block and prev_block:type() == 'block' and last(prev_block)
      if prev_last and prev_last:type() == 'line_li' then
        prev_li = true
        sib = prev_last
      end
    end

    -- Column of the prefix, not `root`: it may start at a codeblock-terminating "<".
    local this_w = get_col(assert(prefix), opt.buf)
    if not prev_li then
      opt.indent = 1
      -- Track the indent width for each indent level so that we can dedent
      -- to the correct level later.
      opt.indent_w = { this_w }
    else
      opt.indent_w = opt.indent_w or { this_w }
      local sib_w = get_col(assert(first(sib, 'prefix')), opt.buf)
      -- Unindented listitem is top-level. Check only its first line: other lines in the captured
      -- listitem may be at column 0 (e.g. codeblock ">" or "<").
      if this_w == 0 then
        opt.indent = 1
        opt.indent_w = { this_w }
      elseif this_w > sib_w then
        -- Previous sibling is logically the _parent_ if it is indented less.
        opt.indent = opt.indent + 1
        opt.indent_w[opt.indent] = this_w
      elseif this_w < sib_w then
        -- Dedent: pop indent levels deeper than the current item, so we return to the correct
        -- ancestor level.
        while opt.indent > 1 and (opt.indent_w[opt.indent] or 0) > this_w do
          opt.indent_w[opt.indent] = nil
          opt.indent = opt.indent - 1
        end
        opt.indent_w[opt.indent] = this_w
      end
    end
    local margin = opt.indent == 1 and '' or ('margin-left: %drem;'):format((1.5 * opt.indent))

    return string.format('<div class="%s" style="%s">%s</div>', cssclass, margin, text)
  elseif node_name == 'taglink' or node_name == 'optionlink' then
    local helppage, tagname, ignored = validate_link(root, opt.buf, opt.fname)
    if ignored or not helppage then
      return html_esc(node_text(root))
    end
    return ('%s<a href="/doc/user/%s#%s">%s</a>'):format(
      ws(),
      helppage,
      url_encode(tagname),
      html_esc(tagname)
    )
  elseif vim.list_contains({ 'codespan', 'keycode' }, node_name) then
    if root:has_error() then
      return text
    end
    return ('%s<code>%s</code>'):format(ws(), trimmed)
  elseif node_name == 'argument' then
    return ('%s<code>%s</code>'):format(ws(), trim(node_text(root)))
  elseif node_name == 'codeblock' then
    return text
  elseif node_name == 'language' then
    language = trim(node_text(root))
    return ''
  elseif node_name == 'code' then -- Highlighted codeblock (child).
    if is_blank(text) then
      return ''
    end
    local code ---@type string
    if language then
      code = ('<pre><code class="language-%s">%s</code></pre>'):format(
        language,
        trim(trim_indent(text), 2)
      )
      language = nil
    else
      code = ('<pre>%s</pre>'):format(trim(trim_indent(text), 2))
    end
    return code
  elseif node_name == 'tag' then -- anchor
    if root:has_error() then
      return text
    end
    local in_heading = vim.list_contains({ 'h1', 'h2', 'h3' }, parent)
    local tagname = node_text(root:child(1), false)
    if vim.tbl_count(stats.first_tags) < 2 then
      -- Force the first 2 tags in the doc to be anchored at the main heading.
      table.insert(stats.first_tags, tagname)
      return ''
    end
    local el = 'span'
    local encoded_tagname = url_encode(tagname)
    local s = ('%s<%s id="%s" class="help-tag"><a href="#%s">%s</a></%s>'):format(
      ws(),
      el,
      encoded_tagname,
      encoded_tagname,
      trimmed,
      el
    )

    if in_heading and prev ~= 'tag' then
      -- Start the <span> container for tags in a heading.
      -- This makes "justify-content:space-between" right-align the tags.
      --    <h2>foo bar<span>tag1 tag2</span></h2>
      return string.format('<span class="help-heading-tags">%s', s)
    elseif in_heading and next_ == nil then
      -- End the <span> container for tags in a heading.
      return string.format('%s</span>', s)
    end
    return s
  elseif node_name == 'delimiter' or node_name == 'modeline' then
    return ''
  elseif node_name == 'ERROR' then
    if ignore_parse_error(opt.fname, trimmed) then
      return text
    end

    -- Store the raw text to give context to the bug report.
    local sample_text = level > 0 and getbuflinestr(root, opt.buf, 3) or '[top level!]'
    table.insert(stats.parse_errors, sample_text)
    return ('<a class="parse-error" target="_blank" title="Report bug... (parse error)" href="%s">%s</a>'):format(
      get_bug_url_vimdoc(opt.fname, opt.to_fname, sample_text),
      trimmed
    )
  else -- Unknown token.
    local sample_text = level > 0 and getbuflinestr(root, opt.buf, 3) or '[top level!]'
    return ('<a class="unknown-token" target="_blank" title="Report bug... (unhandled token "%s")" href="%s">%s</a>'):format(
      node_name,
      get_bug_url_nvim(opt.fname, opt.to_fname, sample_text, node_name),
      trimmed
    ),
      ('unknown-token:"%s"'):format(node_name)
  end
end

-- Generate Typst from node `root` recursively.
---@param root TSNode
---@param level integer
---@param lang_tree TSTree
---@param opt table
---@param stats table
local function ts_node_to_typ(root, level, lang_tree, opt, stats)
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

  local table_rows = node_name == 'block' and get_table(root, opt.buf)
  if table_rows then
    -- Typst fills a flat cell list row by row, so pad every row to the widest row.
    local ncols = 0
    for _, row in ipairs(table_rows) do
      ncols = math.max(ncols, #row)
    end
    local trs = {} ---@type string[]
    for i, row in ipairs(table_rows) do
      local cells = {} ---@type string[]
      for j = 1, ncols do
        local s = ''
        for _, node in ipairs(row[j] or {}) do
          s = s .. ts_node_to_typ(node, level + 1, lang_tree, opt, stats)
        end
        cells[#cells + 1] = ('[%s]'):format(trim(s))
      end
      local tr = table.concat(cells, ', ')
      if i == 1 then
        trs[#trs + 1] = ('table.header(%s),'):format(tr)
      elseif #row == 0 then
        trs[#trs + 1] = 'table.hline(stroke: 2pt),' -- Separator (see `get_table`).
      else
        trs[#trs + 1] = ('%s,'):format(tr)
      end
    end
    return ('#table(columns: %d,\n  %s\n)\n'):format(ncols, table.concat(trs, '\n  '))
  end

  local text = ''
  local trimmed ---@type string
  if root:named_child_count() == 0 or node_name == 'ERROR' then
    text = node_text()
    trimmed = typ_esc(trim(text))

    -- A URL is a "word" directly under a "url"
    -- We don't want any typ escaping there, as typ won't try to parse the
    -- value as a command
    if parent ~= 'url' then
      text = typ_esc(text)
    end
  else
    -- Process children and join them with whitespace.
    for node, _ in root:iter_children() do
      if node:named() then
        local r = ts_node_to_typ(node, level + 1, lang_tree, opt, stats)
        text = string.format('%s%s', text, r)
      end
    end
    trimmed = trim(text)
  end

  if node_name == 'help_file' then -- root node
    return text
  elseif node_name == 'url' then
    local fixed_url, removed_chars = fix_url(trimmed)
    return ('%s#link("%s")%s'):format(ws(), typ_str_esc(fixed_url), removed_chars)
  elseif node_name == 'word' or node_name == 'uppercase_name' then
    return text
  elseif node_name == 'note' then
    return ('*%s*'):format(text)
  elseif node_name == 'h1' or node_name == 'h2' or node_name == 'h3' then
    if is_noise(text, stats.noise_lines) then
      return '' -- Discard common "noise" lines.
    end
    -- Remove tags from ToC text.
    local heading_node = first(root, 'heading')
    local hname = trim(node_text(heading_node):gsub('%*.*%*', ''))
    if not heading_node or hname == '' then
      return '' -- Spurious "===" or "---" in the help doc.
    end

    local heading_level = tonumber(string.sub(node_name, -1))
    if not heading_level then
      print(('Cannot parse heading level from node name %s'):format(node_name))
      return ''
    end
    return ('%s %s'):format(string.rep('=', heading_level), trimmed)
  elseif node_name == 'heading' then
    return trimmed
  elseif node_name == 'column_heading' then
    if root:has_error() then
      return text
    end
    -- In help files column_heading is used for a lot more than column headings.
    -- Sometimes it's some sort of title (see usr_toc.txt), and sometimes it's
    -- some example text that really should be a code block (see usr_02.txt)
    -- Using a raw block allows us to match all use cases fairly well
    return ('```\n%s\n```\n'):format(trimmed)
  elseif node_name == 'block' then
    if is_blank(text) then
      return ''
    end
    return ('%s\n'):format(text)
  elseif node_name == 'line' then
    if
      (parent ~= 'codeblock' and parent ~= 'code')
      and (is_blank(text) or is_noise(text, stats.noise_lines))
    then
      return '' -- Discard common "noise" lines.
    end
    -- XXX: Avoid newlines (too much whitespace) after block elements in old (preformatted) layout.
    local old_after_block = opt.old
      and root:child(0)
      and vim.list_contains({ 'column_heading', 'h1', 'h2', 'h3' }, root:child(0):type())

    if parent == 'codeblock' or parent == 'code' then
      return text
    elseif old_after_block then
      return trim(text)
    else
      -- It would be nice to let the text flow when possible
      -- But many lines do need an explicit line break (e.g. in the ToC)
      return string.format('%s \\ \n', text)
    end
  elseif parent == 'line_li' and node_name == 'prefix' then
    return ''
  elseif node_name == 'line_li' then
    -- Just writing the text - indentation needs improvements
    return text
  elseif node_name == 'taglink' or node_name == 'optionlink' then
    -- Links are just text for now, because dealing with broken links is
    -- difficult. Broken links are expected when generating a PDF of the user
    -- manual, since all links to the reference don't have a destination.
    -- Ideally, links with invalid destinations would be allowed and just be
    -- normal text.
    return (' #underline[%s]'):format(text)
  elseif vim.list_contains({ 'codespan', 'keycode' }, node_name) then
    if root:has_error() then
      return text
    end
    return ('%s`%s`'):format(ws(), trimmed)
  elseif node_name == 'argument' then
    return ('%s`%s`'):format(ws(), trim(node_text(root)))
  elseif node_name == 'codeblock' then
    return text
  elseif node_name == 'language' then
    language = trim(node_text(root))
    return ''
  elseif node_name == 'code' then -- Highlighted codeblock (child).
    if is_blank(text) then
      return ''
    end
    local code ---@type string
    if language then
      code = ('```%s\n%s\n```'):format(language, trim(trim_indent(text), 2))
      language = nil
    else
      code = ('\n```\n%s\n```\n'):format(trim(trim_indent(text), 2))
    end
    return code
  elseif node_name == 'tag' then -- anchor, h4 pseudo-heading
    if root:has_error() then
      return text
    end
    local in_heading = vim.list_contains({ 'h1', 'h2', 'h3' }, parent)
    local tagname = node_text(root:child(1), false)
    -- NOTE: the <%s> syntax doesn't work because it terminates the heading
    local s = ('%s%s #label("%s")'):format(ws(), text, typ_str_esc(tagname))

    if in_heading and prev ~= 'tag' then
      -- Add fractional spacing to right-align the tags in a heading
      -- TODO those right-aligned tags should also be styled differently
      -- (i.e. not like a header)
      return (' #h(1fr) %s'):format(s)
    end
    return s
  elseif node_name == 'delimiter' then
    return '\n'
  elseif node_name == 'modeline' then
    return ''
  else -- Unknown token.
    local sample_text = level > 0 and getbuflinestr(root, opt.buf, 3) or '[top level!]'
    if node_name == 'ERROR' then
      if ignore_parse_error(opt.fname, trimmed) then
        return text
      end
      table.insert(stats.parse_errors, sample_text)
    end
    print(('Unexpected token %s: %s'):format(node_name, sample_text))
    return ''
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
--- @param help_dir string
--- @return table<string, string>
local function _get_helptags(help_dir)
  ---@type table<string, string>
  local m = {}
  -- Load a random help file to convince taglist() to do its job.
  vim.cmd(string.format('split %s/api.txt', help_dir))
  vim.cmd('lcd %:p:h')
  local tags = vim.fn.taglist('.*') --[[ @as {name: string, filename: string}[] ]]
  for _, item in ipairs(tags) do
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
  local lang_tree = assert(vim.treesitter.get_parser(buf, nil))
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

--- Generates HTML from one :help file `fname`.
---
--- @param fname string Source :help file.
--- @param text string|nil Source :help file contents, or nil to read `fname`.
--- @param to_fname string Destination .html file
--- @param old boolean Preformat paragraphs (for old :help files which are full of arbitrary whitespace)
---
--- @return string html
--- @return table stats
--- @return string main HTML body, without the Hugo front matter.
local function gen_one_html(fname, text, to_fname, old, commit)
  local stats = {
    noise_lines = {},
    parse_errors = {},
    first_tags = {}, -- Track the first few tags in doc.
  }
  local lang_tree, buf = parse_buf(fname, text)
  ---@type nvim.gen_help_html.heading[]
  local headings = {} -- Headings (for ToC). 2-dimensional: h1 contains h2/h3.
  local title = to_titlecase(basename_noext(fname))

  local main = ''
  for _, tree in ipairs(lang_tree:trees()) do
    main = main
      .. (
        ts_node_to_html(
          tree:root(),
          0,
          tree,
          headings,
          { buf = buf, old = old, fname = fname, to_fname = to_fname, indent = 1 },
          stats
        )
      )
  end

  local frontmatter = vim.json.encode({
    title = title,
    layout = 'single', -- Hugo-specific, to make _index.html the same as the other pages
    aliases = { -- Hugo-specific, make /api.html redirect to /api/
      vim.fs.joinpath('/doc/user', vim.fs.basename(to_fname)),
    },
    params = {
      firstTag1 = stats.first_tags[1] or '',
      firstTag2 = stats.first_tags[2] or '',
      basename = vim.fs.basename(fname),
      commit = commit,
      parseErrors = #stats.parse_errors,
      bugUrl = get_bug_url_nvim(fname, to_fname, 'TODO', nil),
      noiseLines = html_esc(table.concat(stats.noise_lines, '\n')),
      noiseLinesCount = #stats.noise_lines,
      headings = headings,
    },
  }, { indent = '  ', sort_keys = true })

  local html = ('%s\n%s'):format(frontmatter, main)

  vim.cmd('q!')
  lang_tree:destroy()
  return html, stats, main
end

--- Generates Typst from one :help file `fname`.
---
--- @param fname string Source :help file.
--- @param text string|nil Source :help file contents, or nil to read `fname`.
--- @param to_fname string Destination .typ file
--- @param old boolean Preformat paragraphs (for old :help files which are full of arbitrary whitespace)
--- @param commit string|nil Unused.
---
--- @return string Typst output
--- @return table stats
local function gen_one_typ(fname, text, to_fname, old, commit)
  local stats = {
    noise_lines = {},
    parse_errors = {},
  }
  local lang_tree, buf = parse_buf(fname, text)
  local title = to_titlecase(basename_noext(fname))

  local typ = ('= %s\n'):format(typ_esc(trim(title)))
  for _, tree in ipairs(lang_tree:trees()) do
    typ = typ
      .. (
        ts_node_to_typ(
          tree:root(),
          0,
          tree,
          { buf = buf, old = old, fname = fname, to_fname = to_fname, indent = 1 },
          stats
        )
      )
  end

  -- Add page break at the bottom, so that merging .typ files before conversion
  -- results in page breaks in the right places
  local page_break = '#pagebreak()'
  typ = ('%s\n%s'):format(typ, page_break)

  vim.cmd('q!')
  lang_tree:destroy()
  return typ, stats
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
    local htmlpage = assert(get_helppage_html(helpfile))
    -- "foo.html#tag"
    t[tag] = ('%s#%s'):format(htmlpage, url_encode(tag))
  end
  tofile(fname, vim.json.encode(t, { indent = '  ', sort_keys = true }))
end

local function gen_helptag_html(fname)
  local frontmatter = vim.json.encode({
    title = 'Helptag redirect',
    layout = 'helptag',
    aliases = { vim.fs.basename(fname) },
  }, { indent = '  ', sort_keys = true })
  tofile(fname, frontmatter)
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

--- Generate redirect pages for renamed help files.

--- @param commit string?
--- @param helpfile string Name of the help file being generated
--- @param to_dir string Target directory where the output files will be written.
--- @param to_fname string Name of the already-generated page in the new location
---
--- @return boolean Whether a redirect page has been generated
local function gen_redirect_pages(commit, helpfile, to_dir, to_fname)
  local helpfile_tag = (helpfile:gsub('%.txt$', '')):gsub('_', '-') -- "dev_tools.txt" => "dev-tools"
  local redirect_from = redirects[helpfile]
  if not redirect_from then
    return false
  end

  local redirect_text = vim.text
    .indent(
      0,
      [[
      *%s*      Nvim

      Document moved to: |%s|

      ==============================================================================
      Document moved

      Document moved to: |%s|

      ==============================================================================
        vim:tw=78:ts=8:ft=help:norl:
      ]]
    )
    :format(redirect_from, helpfile_tag, helpfile_tag, helpfile_tag, helpfile_tag, helpfile_tag)
  local redirect_to_fname = get_helppage_html(redirect_from, true)
  local redirect_to = ('%s/%s'):format(to_dir, redirect_to_fname)
  local redirect_html, _ =
    gen_one_html(redirect_from, redirect_text, redirect_to, false, commit or '?')
  assert(
    redirect_html:find(vim.pesc(helpfile_tag)),
    ('not found in redirect html: %s'):format(helpfile_tag)
  )
  tofile(redirect_to, redirect_html)

  print(('generated (redirect) : %-15s => %s'):format(redirect_from, vim.fs.basename(to_fname)))
  return true
end

--- Stylesheet for `output_format=print` (PDF generation via `chrome --headless`).
local print_css = [[
  @page { size: A4; margin: 15mm; }
  body { font: 10.5pt/1.4 system-ui, sans-serif; }
  a { color: inherit; }
  .chapter { break-before: page; }
  .chapter:first-child { break-before: auto; }
  h1, h2, h3, h4 { break-after: avoid; }
  .help-heading { display: flex; flex-flow: row wrap; justify-content: space-between; gap: 0 1em; }
  pre, code, .old-help-para { font-family: ui-monospace, Menlo, Consolas, monospace; }
  pre, .old-help-para { font-size: 9pt; white-space: pre-wrap; tab-size: 8; }
  pre { background: #f4f4f4; padding: 0.4em 0.6em; break-inside: avoid; }
  .help-para, .old-help-para { margin: 0.6em 0; counter-reset: li; }
  .help-li, .help-li-num { display: list-item; margin-left: 1.5em; }
  .help-li-num { list-style: none; }
  .help-li-num::before { counter-increment: li; content: counter(li) ". "; margin-left: -1em; }
  .help-tag, .help-tag-right { color: #0a6b52; }
  .help-tag-right { float: right; }
  .help-tag-heading { display: flow-root; }
  .help-column_heading { font-weight: bold; }
  .help-table { border-collapse: collapse; margin: 0.6em 0; break-inside: avoid; }
  .help-table th, .help-table td { padding: 0.15em 0.8em; text-align: left; vertical-align: top; border-bottom: 1px solid #ccc; }
  .help-table th, .help-table-sep td { border-bottom-color: #888; }
]]

--- Joins page bodies into one standalone HTML page, for printing to PDF.
--- Links to `helpfiles` become in-page links; other links go to neovim.io.
---
--- @param chapters string[] Page bodies.
--- @param helpfiles string[] Source files of `chapters`.
--- @return string
local function gen_print_html(chapters, helpfiles)
  local pages = {} ---@type table<string, true>
  for _, f in ipairs(helpfiles) do
    pages[(get_helppage_html(vim.fs.basename(f)):gsub('/$', ''))] = true
  end
  local body = table.concat(chapters, '\n')
  body = body:gsub('href="/doc/user/([^"#]*)(#?[^"]*)"', function(page, anchor)
    page = page:gsub('/$', '')
    if pages[page] and anchor ~= '' then
      return ('href="%s"'):format(anchor)
    end
    return ('href="https://neovim.io/doc/user/%s%s"'):format(
      page == '' and '' or page .. '/',
      anchor
    )
  end)
  return ('<!doctype html>\n<html><head><meta charset="utf-8"><title>Nvim</title>\n<style>\n%s</style>\n</head><body>\n%s\n</body></html>\n'):format(
    vim.text.indent(0, print_css),
    body
  )
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
--- @param output_format string "html", "typ" (Typst), or "print" (one standalone
--- `to_dir/print.html` for printing to PDF, with the files in `include` order).
--- @param help_dir string Source directory containing the :help files. Must run `make helptags` first.
--- @param to_dir string Target directory where the output files will be written.
--- @param include string[]|nil Process only these filenames. Example: {'api.txt', 'autocmd.txt', 'channel.txt'}
--- @param commit string?
--- @param parser_path string? path to non-default vimdoc.so/dylib/dll
---
--- @return nvim.gen_help_html.gen_result result
function M.gen(output_format, help_dir, to_dir, include, commit, parser_path)
  vim.validate('output_format', output_format, 'string')
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

  -- Sort-order (matters for output_format=print).
  -- Decided by `include`, else: help.txt, user manual, reference, rest alphabetically.
  local order = {} ---@type table<string, integer>
  local function add(f)
    order[f] = order[f] or vim.tbl_count(order)
  end
  for _, f in ipairs(include or {}) do
    add(f)
  end
  if not include and output_format == 'print' then
    add('help.txt')
    for _, toc in ipairs({ 'usr_toc.txt', 'help.txt' }) do
      local path = ('%s/%s'):format(help_dir, toc)
      if vim.fn.filereadable(path) == 1 then
        add(toc)
        for f in table.concat(vim.fn.readfile(path), '\n'):gmatch('|([%w_.-]+%.txt)|') do
          add(f)
        end
      end
    end
  end
  table.sort(helpfiles, function(a, b)
    local fa, fb = vim.fs.basename(a), vim.fs.basename(b)
    local oa, ob = order[fa] or math.huge, order[fb] or math.huge
    return oa < ob or (oa == ob and fa < fb)
  end)
  to_dir = vim.fs.normalize(to_dir)

  print(('output dir: %s\n\n'):format(to_dir))
  vim.fn.mkdir(to_dir, 'p')

  if output_format == 'html' then
    -- NOTE: Better for Hugo to be in static/, but works fine with contents/ as to_dir
    gen_helptags_json(('%s/helptags.json'):format(to_dir))
    gen_helptag_html(('%s/helptag.html'):format(to_dir))
  end

  -- Map output formats to the function that outputs one file in that format
  local generators = {
    html = gen_one_html,
    typ = gen_one_typ,
    print = gen_one_html,
  }
  local gen_one = generators[output_format]
  local chapters = {} ---@type string[] Page bodies, for "print" format.

  for _, f in ipairs(helpfiles) do
    -- "foo.txt"
    local helpfile = vim.fs.basename(f)

    local to_fname = ''
    if output_format == 'html' or output_format == 'print' then
      -- "to/dir/foo.html"
      to_fname = ('%s/%s'):format(to_dir, get_helppage_html(helpfile, true))
    else
      to_fname = ('%s/%s.%s'):format(to_dir, helpfile:gsub('.txt', ''), output_format)
    end

    local converted_help, stats, main =
      gen_one(f, nil, to_fname, not new_layout[helpfile], commit or '?')
    if output_format == 'print' then
      chapters[#chapters + 1] = ('<section class="chapter">\n%s\n</section>'):format(main)
    else
      tofile(to_fname, converted_help)
    end
    print(
      ('generated (%-2s errors): %-15s => %s'):format(
        #stats.parse_errors,
        helpfile,
        vim.fs.basename(to_fname)
      )
    )

    if output_format == 'html' then
      local generated = gen_redirect_pages(commit, helpfile, to_dir, to_fname)
      if generated then
        redirects_count = redirects_count + 1
      end
    end

    err_count = err_count + #stats.parse_errors
  end

  if output_format == 'print' then
    local to_fname = ('%s/print.html'):format(to_dir)
    tofile(to_fname, gen_print_html(chapters, helpfiles))
    print(('\nprint: %s'):format(to_fname))
  end

  print(('\ngenerated %d pages'):format(#helpfiles + redirects_count))
  print(('total errors: %d'):format(err_count))
  -- Why aren't the netrw tags found in neovim/docs/ CI?
  print(('invalid tags: %s'):format(vim.inspect(invalid_links)))

  if output_format == 'html' then
    eq(redirects_count, include and redirects_count or vim.tbl_count(redirects)) -- sanity check
    print(('redirects: %d'):format(redirects_count))
  end

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
  local rv = M.gen('html', help_dir, tmpdir, input)
  eq(#input, #rv.helpfiles)
  eq(0, rv.err_count, 'parse errors in :help docs')
  eq({}, rv.invalid_links, 'invalid tags in :help docs')
end

return M
