-- Converts Vim :help files to HTML.  Validates |tag| links and document syntax (parser errors).
--
-- NOTE: :helptags checks for duplicate tags, whereas this script checks _links_ (to tags).
--
-- USAGE (GENERATE HTML):
--   1. Run `make helptags` first; this script depends on vim.fn.taglist().
--   2. nvim -V1 -es --clean +"lua require('scripts.gen_help_html').gen('./build/runtime/doc/', 'target/dir/')"
--      - Read the docstring at gen().
--   3. cd target/dir/ && jekyll serve --host 0.0.0.0
--   4. Visit http://localhost:4000/…/help.txt.html
--
-- USAGE (VALIDATE):
--   1. nvim -V1 -es +"lua require('scripts.gen_help_html').validate()"
--      - validate() is 10x faster than gen(), so it is used in CI.
--
-- SELF-TEST MODE:
--   1. nvim -V1 -es +"lua require('scripts.gen_help_html')._test()"
--
-- NOTES:
--   * gen() and validate() are the primary entrypoints. validate() only exists because gen() is too
--     slow (~1 min) to run in per-commit CI.
--   * visit_node() is the core function used by gen() to traverse the document tree and produce HTML.
--   * visit_validate() is the core function used by validate().
--   * Files in `new_layout` will be generated with a "flow" layout instead of preformatted/fixed-width layout.

local tagmap = nil
local helpfiles = nil
local invalid_links = {}
local invalid_urls = {}
local invalid_spelling = {}
local spell_dict = {
  Neovim = 'Nvim',
  NeoVim = 'Nvim',
  neovim = 'Nvim',
  lua = 'Lua',
}

local M = {}

-- These files are generated with "flow" layout (non fixed-width, wrapped text paragraphs).
-- All other files are "legacy" files which require fixed-width layout.
local new_layout = {
  ['api.txt'] = true,
  ['channel.txt'] = true,
  ['develop.txt'] = true,
  ['luaref.txt'] = true,
  ['nvim.txt'] = true,
  ['pi_health.txt'] = true,
  ['provider.txt'] = true,
  ['ui.txt'] = true,
}

-- TODO: These known invalid |links| require an update to the relevant docs.
local exclude_invalid = {
  ["'previewpopup'"] = "quickref.txt",
  ["'pvp'"] = "quickref.txt",
  ["'string'"] = "eval.txt",
  Query = "treesitter.txt",
  ["eq?"] = "treesitter.txt",
  ["lsp-request"] = "lsp.txt",
  matchit = "vim_diff.txt",
  ["matchit.txt"] = "help.txt",
  ["set!"] = "treesitter.txt",
  ["v:_null_blob"] = "builtin.txt",
  ["v:_null_dict"] = "builtin.txt",
  ["v:_null_list"] = "builtin.txt",
  ["v:_null_string"] = "builtin.txt",
  ["vim.lsp.buf_request()"] = "lsp.txt",
  ["vim.lsp.util.get_progress_messages()"] = "lsp.txt",
  ["vim.treesitter.start()"] = "treesitter.txt",
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

local function html_esc(s)
  return s:gsub(
    '&', '&amp;'):gsub(
    '<', '&lt;'):gsub(
    '>', '&gt;')
end

local function url_encode(s)
  -- Credit: tpope / vim-unimpaired
  -- NOTE: these chars intentionally *not* escaped: ' ( )
  return vim.fn.substitute(vim.fn.iconv(s, 'latin1', 'utf-8'),
    [=[[^A-Za-z0-9()'_.~-]]=],
    [=[\="%".printf("%02X",char2nr(submatch(0)))]=],
    'g')
end

local function expandtabs(s)
  return s:gsub('\t', (' '):rep(8))
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

local function trim(s, dir)
  return vim.fn.trim(s, '\r\t\n ', dir or 0)
end

-- Remove common punctuation from URLs.
--
-- TODO: fix this in the parser instead... https://github.com/neovim/tree-sitter-vimdoc
--
-- @returns (fixed_url, removed_chars) where `removed_chars` is in the order found in the input.
local function fix_url(url)
  local removed_chars = ''
  local fixed_url = url
  -- Remove up to one of each char from end of the URL, in this order.
  for _, c in ipairs({ '.', ')', }) do
    if fixed_url:sub(-1) == c then
      removed_chars = c .. removed_chars
      fixed_url = fixed_url:sub(1, -2)
    end
  end
  return fixed_url, removed_chars
end

-- Checks if a given line is a "noise" line that doesn't look good in HTML form.
local function is_noise(line, noise_lines)
  if (
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
    or line:find('^%s*vi[m]%:.*ft=help')
    or line:find('^%s*vi[m]%:.*filetype=help')
    or line:find('[*>]local%-additions[*<]')
  ) then
    -- table.insert(stats.noise_lines, getbuflinestr(root, opt.buf, 0))
    table.insert(noise_lines or {}, line)
    return true
  end
  return false
end

-- Creates a github issue URL at neovim/tree-sitter-vimdoc with prefilled content.
local function get_bug_url_vimdoc(fname, to_fname, sample_text)
  local this_url = string.format('https://neovim.io/doc/user/%s', vim.fs.basename(to_fname))
  local bug_url = ('https://github.com/neovim/tree-sitter-vimdoc/issues/new?labels=bug&title=parse+error%3A+'
    ..vim.fs.basename(fname)
    ..'+&body=Found+%60tree-sitter-vimdoc%60+parse+error+at%3A+'
    ..this_url
    ..'%0D%0DContext%3A%0D%0D%60%60%60%0D'
    ..url_encode(sample_text)
    ..'%0D%60%60%60')
  return bug_url
end

-- Creates a github issue URL at neovim/neovim with prefilled content.
local function get_bug_url_nvim(fname, to_fname, sample_text, token_name)
  local this_url = string.format('https://neovim.io/doc/user/%s', vim.fs.basename(to_fname))
  local bug_url = ('https://github.com/neovim/neovim/issues/new?labels=bug&title=user+docs+HTML%3A+'
    ..vim.fs.basename(fname)
    ..'+&body=%60gen_help_html.lua%60+problem+at%3A+'
    ..this_url
    ..'%0D'
    ..(token_name and '+unhandled+token%3A+%60'..token_name..'%60' or '')
    ..'%0DContext%3A%0D%0D%60%60%60%0D'
    ..url_encode(sample_text)
    ..'%0D%60%60%60')
  return bug_url
end

-- Gets a "foo.html" name from a "foo.txt" helpfile name.
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

  return (f:gsub('%.txt$', '.html'))
end

-- Counts leading spaces (tab=8) to decide the indent size of multiline text.
--
-- Blank lines (empty or whitespace-only) are ignored.
local function get_indent(s)
  local min_indent = nil
  for line in vim.gsplit(s, '\n') do
    if line and not is_blank(line) then
      local ws = expandtabs(line:match('^%s+') or '')
      min_indent = (not min_indent or ws:len() < min_indent) and ws:len() or min_indent
    end
  end
  return min_indent or 0
end

-- Removes the common indent level, after expanding tabs to 8 spaces.
local function trim_indent(s)
  local indent_size = get_indent(s)
  local trimmed = ''
  for line in vim.gsplit(s, '\n') do
    line = expandtabs(line)
    trimmed = ('%s%s\n'):format(trimmed, line:sub(indent_size + 1))
  end
  return trimmed:sub(1, -2)
end

-- Gets raw buffer text in the node's range (+/- an offset), as a newline-delimited string.
local function getbuflinestr(node, bufnr, offset)
  local line1, _, line2, _ = node:range()
  line1 = line1 - offset
  line2 = line2 + offset
  local lines = vim.fn.getbufline(bufnr, line1 + 1, line2 + 1)
  return table.concat(lines, '\n')
end

local function get_tagname(node, bufnr)
  local text = vim.treesitter.get_node_text(node, bufnr)
  local tag = (node:type() == 'optionlink' or node:parent():type() == 'optionlink') and ("'%s'"):format(text) or text
  local helpfile = vim.fs.basename(tagmap[tag]) or nil  -- "api.txt"
  local helppage = get_helppage(helpfile)               -- "api.html"
  return helppage, tag
end

-- Returns true if the given invalid tagname is a false positive.
local function ignore_invalid(s)
  return not not (
    exclude_invalid[s]
    -- Strings like |~/====| appear in various places and the parser thinks they are links, but they
    -- are just table borders.
    or s:find('===')
    or s:find('---')
  )
end

local function ignore_parse_error(s)
  -- Ignore parse errors for unclosed codespan/optionlink/tag.
  -- This is common in vimdocs and is treated as plaintext by :help.
  return s:find("^[`'|*]")
end

local function has_ancestor(node, ancestor_name)
  local p = node
  while true do
    p = p:parent()
    if not p or p:type() == 'help_file' then
      break
    elseif p:type() == ancestor_name then
      return true
    end
  end
  return false
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

-- Traverses the tree at `root` and checks that |tag| links point to valid helptags.
local function visit_validate(root, level, lang_tree, opt, stats)
  level = level or 0
  local node_name = (root.named and root:named()) and root:type() or nil
  local toplevel = level < 1
  local function node_text(node)
    return vim.treesitter.get_node_text(node or root, opt.buf)
  end
  local text = trim(node_text())

  if root:child_count() > 0 then
    for node, _ in root:iter_children() do
      if node:named() then
        visit_validate(node, level + 1, lang_tree, opt, stats)
      end
    end
  end

  if node_name == 'ERROR' then
    if ignore_parse_error(text) then
      return
    end
    -- Store the raw text to give context to the error report.
    local sample_text = not toplevel and getbuflinestr(root, opt.buf, 3) or '[top level!]'
    table.insert(stats.parse_errors, sample_text)
  elseif node_name == 'word' or node_name == 'uppercase_name' then
    if spell_dict[text] then
      if not invalid_spelling[text] then
        invalid_spelling[text] = { vim.fs.basename(opt.fname) }
      else
        table.insert(invalid_spelling[text], vim.fs.basename(opt.fname))
      end
    end
  elseif node_name == 'url' then
    if text:find('http%:') then
      invalid_urls[text] = vim.fs.basename(opt.fname)
    end
  elseif node_name == 'taglink' or node_name == 'optionlink' then
    local _, _, _ = validate_link(root, opt.buf, opt.fname)
  end
end

-- Generates HTML from node `root` recursively.
local function visit_node(root, level, lang_tree, headings, opt, stats)
  level = level or 0

  local node_name = (root.named and root:named()) and root:type() or nil
  -- Previous sibling kind (string).
  local prev = root:prev_sibling() and (root:prev_sibling().named and root:prev_sibling():named()) and root:prev_sibling():type() or nil
  -- Next sibling kind (string).
  local next_ = root:next_sibling() and (root:next_sibling().named and root:next_sibling():named()) and root:next_sibling():type() or nil
  -- Parent kind (string).
  local parent = root:parent() and root:parent():type() or nil
  local text = ''
  local trimmed
  local function node_text(node)
    return vim.treesitter.get_node_text(node or root, opt.buf)
  end
  -- Gets leading whitespace of the current node.
  local function ws()
    return node_text():match('^%s+') or ''
  end

  if root:child_count() == 0 or node_name == 'ERROR' then
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

  if node_name == 'help_file' then  -- root node
    return text
  elseif node_name == 'url' then
    local fixed_url, removed_chars = fix_url(trimmed)
    return ('%s<a href="%s">%s</a>%s'):format(ws(), fixed_url, fixed_url, removed_chars)
  elseif node_name == 'word' or node_name == 'uppercase_name' then
    return text
  elseif node_name == 'h1' or node_name == 'h2' or node_name == 'h3' then
    if is_noise(text, stats.noise_lines) then
      return ''  -- Discard common "noise" lines.
    end
    -- Remove "===" and tags from ToC text.
    local hname = (node_text():gsub('%-%-%-%-+', ''):gsub('%=%=%=%=+', ''):gsub('%*.*%*', ''))
    if node_name == 'h1' or #headings == 0 then
      table.insert(headings, { name = hname, subheadings = {}, })
    else
      table.insert(headings[#headings].subheadings, { name = hname, subheadings = {}, })
    end
    local el = node_name == 'h1' and 'h2' or 'h3'
    return ('<a name="%s"></a><%s class="help-heading">%s</%s>\n'):format(to_heading_tag(hname), el, text, el)
  elseif node_name == 'column_heading' or node_name == 'column_name' then
    if root:has_error() then
      return text
    end
    return ('<div class="help-column_heading">%s%s</div>'):format(ws(), trimmed)
  elseif node_name == 'block' then
    if is_blank(text) then
      return ''
    end
    if opt.old then
      -- XXX: Treat "old" docs as preformatted: they use indentation for layout.
      --      Trim trailing newlines to avoid too much whitespace between divs.
      return ('<div class="old-help-para">%s</div>\n'):format(trim(text, 2))
    end
    return string.format('<div class="help-para">\n%s\n</div>\n', text)
  elseif node_name == 'line' then
    if parent ~= 'codeblock' and (is_blank(text) or is_noise(text, stats.noise_lines)) then
      return ''  -- Discard common "noise" lines.
    end
    -- XXX: Avoid newlines (too much whitespace) after block elements in old (preformatted) layout.
    local div = opt.old and root:child(0) and vim.tbl_contains({'column_heading', 'h1', 'h2', 'h3'}, root:child(0):type())
    return string.format('%s%s', div and trim(text) or text, div and '' or '\n')
  elseif node_name == 'line_li' then
    local sib = root:prev_sibling()
    local prev_li = sib and sib:type() == 'line_li'

    if not prev_li then
      opt.indent = 1
    else
      -- The previous listitem _sibling_ is _logically_ the _parent_ if it is indented less.
      local parent_indent = get_indent(node_text(sib))
      local this_indent = get_indent(node_text())
      if this_indent > parent_indent then
        opt.indent = opt.indent + 1
      elseif this_indent < parent_indent then
        opt.indent = math.max(1, opt.indent - 1)
      end
    end
    local margin = opt.indent == 1 and '' or ('margin-left: %drem;'):format((1.5 * opt.indent))

    return string.format('<div class="help-li" style="%s">%s</div>', margin, text)
  elseif node_name == 'taglink' or node_name == 'optionlink' then
    local helppage, tagname, ignored = validate_link(root, opt.buf, opt.fname)
    if ignored then
      return text
    end
    return ('%s<a href="%s#%s">%s</a>'):format(ws(), helppage, url_encode(tagname), html_esc(tagname))
  elseif vim.tbl_contains({'codespan', 'keycode'}, node_name) then
    if root:has_error() then
      return text
    end
    return ('%s<code>%s</code>'):format(ws(), trimmed)
  elseif node_name == 'argument' then
    return ('%s<code>{%s}</code>'):format(ws(), text)
  elseif node_name == 'codeblock' then
    if is_blank(text) then
      return ''
    end
    return ('<pre>%s</pre>'):format(trim(trim_indent(text), 2))
  elseif node_name == 'tag' then  -- anchor
    if root:has_error() then
      return text
    end
    local in_heading = vim.tbl_count({'h1', 'h2', 'h3'}, parent)
    local cssclass = (not in_heading and get_indent(node_text()) > 8) and 'help-tag-right' or 'help-tag'
    local tagname = node_text(root:child(1))
    if vim.tbl_count(stats.first_tags) < 2 then
      -- First 2 tags in the doc will be anchored at the main heading.
      table.insert(stats.first_tags, tagname)
      return ''
    end
    local s = ('%s<a name="%s"></a><span class="%s">%s</span>'):format(ws(), url_encode(tagname), cssclass, trimmed)
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
  elseif node_name == 'ERROR' then
    if ignore_parse_error(trimmed) then
      return text
    end

    -- Store the raw text to give context to the bug report.
    local sample_text = level > 0 and getbuflinestr(root, opt.buf, 3) or '[top level!]'
    table.insert(stats.parse_errors, sample_text)
    return ('<a class="parse-error" target="_blank" title="Report bug... (parse error)" href="%s">%s</a>'):format(
      get_bug_url_vimdoc(opt.fname, opt.to_fname, sample_text), trimmed)
  else  -- Unknown token.
    local sample_text = level > 0 and getbuflinestr(root, opt.buf, 3) or '[top level!]'
    return ('<a class="unknown-token" target="_blank" title="Report bug... (unhandled token "%s")" href="%s">%s</a>'):format(
      node_name, get_bug_url_nvim(opt.fname, opt.to_fname, sample_text, node_name), trimmed), ('unknown-token:"%s"'):format(node_name)
  end
end

local function get_helpfiles(include)
  local dir = './build/runtime/doc'
  local rv = {}
  for f, type in vim.fs.dir(dir) do
    if (vim.endswith(f, '.txt')
        and type == 'file'
        and (not include or vim.tbl_contains(include, f))) then
      local fullpath = vim.fn.fnamemodify(('%s/%s'):format(dir, f), ':p')
      table.insert(rv, fullpath)
    end
  end
  return rv
end

-- Populates the helptags map.
local function get_helptags(help_dir)
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

-- Use the help.so parser defined in the build, not whatever happens to be installed on the system.
local function ensure_runtimepath()
  if not vim.o.runtimepath:find('build/lib/nvim/') then
    vim.cmd[[set runtimepath^=./build/lib/nvim/]]
  end
end

-- Opens `fname` in a buffer and gets a treesitter parser for the buffer contents.
--
-- @returns lang_tree, bufnr
local function parse_buf(fname)
  local buf
  if type(fname) == 'string' then
    vim.cmd('split '..vim.fn.fnameescape(fname))  -- Filename.
    buf = vim.api.nvim_get_current_buf()
  else
    buf = fname
    vim.cmd('sbuffer '..tostring(fname))          -- Buffer number.
  end
  -- vim.treesitter.require_language('help', './build/lib/nvim/parser/help.so')
  local lang_tree = vim.treesitter.get_parser(buf, 'help')
  return lang_tree, buf
end

-- Validates one :help file `fname`:
--  - checks that |tag| links point to valid helptags.
--  - recursively counts parse errors ("ERROR" nodes)
--
-- @returns { invalid_links: number, parse_errors: number }
local function validate_one(fname)
  local stats = {
    parse_errors = {},
  }
  local lang_tree, buf = parse_buf(fname)
  for _, tree in ipairs(lang_tree:trees()) do
    visit_validate(tree:root(), 0, tree, { buf = buf, fname = fname, }, stats)
  end
  lang_tree:destroy()
  vim.cmd.close()
  return stats
end

-- Generates HTML from one :help file `fname` and writes the result to `to_fname`.
--
-- @param fname Source :help file
-- @param to_fname Destination .html file
-- @param old boolean Preformat paragraphs (for old :help files which are full of arbitrary whitespace)
--
-- @returns html, stats
local function gen_one(fname, to_fname, old, commit)
  local stats = {
    noise_lines = {},
    parse_errors = {},
    first_tags = {},  -- Track the first few tags in doc.
  }
  local lang_tree, buf = parse_buf(fname)
  local headings = {}  -- Headings (for ToC). 2-dimensional: h1 contains h2/h3.
  local title = to_titlecase(basename_noext(fname))

  local html = ([[
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Neovim user documentation">
    <link href="/css/normalize.min.css" rel="stylesheet">
    <link href="/css/bootstrap.css" rel="stylesheet">
    <link href="/css/main.css" rel="stylesheet">
    <link href="help.css" rel="stylesheet">
    <title>%s - Neovim docs</title>
  </head>
  <body>
  ]]):format(title)

  local logo_svg = [[
    <svg xmlns="http://www.w3.org/2000/svg" role="img" width="173" height="50" viewBox="0 0 742 214" aria-label="Neovim">
      <title>Neovim</title>
      <defs>
        <linearGradient x1="50%" y1="0%" x2="50%" y2="100%" id="a">
          <stop stop-color="#16B0ED" stop-opacity=".8" offset="0%" />
          <stop stop-color="#0F59B2" stop-opacity=".837" offset="100%" />
        </linearGradient>
        <linearGradient x1="50%" y1="0%" x2="50%" y2="100%" id="b">
          <stop stop-color="#7DB643" offset="0%" />
          <stop stop-color="#367533" offset="100%" />
        </linearGradient>
        <linearGradient x1="50%" y1="0%" x2="50%" y2="100%" id="c">
          <stop stop-color="#88C649" stop-opacity=".8" offset="0%" />
          <stop stop-color="#439240" stop-opacity=".84" offset="100%" />
        </linearGradient>
      </defs>
      <g fill="none" fill-rule="evenodd">
        <path
          d="M.027 45.459L45.224-.173v212.171L.027 166.894V45.459z"
          fill="url(#a)"
          transform="translate(1 1)"
        />
        <path
          d="M129.337 45.89L175.152-.149l-.928 212.146-45.197-45.104.31-121.005z"
          fill="url(#b)"
          transform="matrix(-1 0 0 1 305 1)"
        />
        <path
          d="M45.194-.137L162.7 179.173l-32.882 32.881L12.25 33.141 45.194-.137z"
          fill="url(#c)"
          transform="translate(1 1)"
        />
        <path
          d="M46.234 84.032l-.063 7.063-36.28-53.563 3.36-3.422 32.983 49.922z"
          fill-opacity=".13"
          fill="#000"
        />
        <g fill="#444">
          <path
            d="M227 154V64.44h4.655c1.55 0 2.445.75 2.685 2.25l.806 13.502c4.058-5.16 8.786-9.316 14.188-12.466 5.4-3.15 11.413-4.726 18.037-4.726 4.893 0 9.205.781 12.935 2.34 3.729 1.561 6.817 3.811 9.264 6.751 2.448 2.942 4.297 6.48 5.55 10.621 1.253 4.14 1.88 8.821 1.88 14.042V154h-8.504V96.754c0-8.402-1.91-14.987-5.729-19.757-3.82-4.771-9.667-7.156-17.544-7.156-5.851 0-11.28 1.516-16.292 4.545-5.013 3.032-9.489 7.187-13.427 12.467V154H227zM350.624 63c5.066 0 9.755.868 14.069 2.605 4.312 1.738 8.052 4.268 11.219 7.592s5.638 7.412 7.419 12.264C385.11 90.313 386 95.883 386 102.17c0 1.318-.195 2.216-.588 2.696-.393.48-1.01.719-1.851.719h-64.966v1.70c0 6.708.784 12.609 2.353 17.7 1.567 5.09 3.8 9.357 6.695 12.802 2.895 3.445 6.393 6.034 10.495 7.771 4.1 1.738 8.686 2.606 13.752 2.606 4.524 0 8.446-.494 11.762-1.483 3.317-.988 6.108-2.097 8.37-3.324 2.261-1.227 4.056-2.336 5.383-3.324 1.326-.988 2.292-1.482 2.895-1.482.784 0 1.388.3 1.81.898l2.352 2.875c-1.448 1.797-3.362 3.475-5.745 5.031-2.383 1.558-5.038 2.891-7.962 3.998-2.926 1.109-6.062 1.991-9.41 2.65a52.21 52.21 0 01-10.088.989c-6.152 0-11.762-1.064-16.828-3.19-5.067-2.125-9.415-5.225-13.043-9.298-3.63-4.074-6.435-9.06-8.415-14.96C310.99 121.655 310 114.9 310 107.294c0-6.408.92-12.323 2.76-17.744 1.84-5.421 4.493-10.093 7.961-14.016 3.467-3.922 7.72-6.991 12.758-9.209C338.513 64.11 344.229 63 350.624 63zm.573 6c-4.696 0-8.904.702-12.623 2.105-3.721 1.404-6.936 3.421-9.65 6.053-2.713 2.631-4.908 5.79-6.586 9.474S319.55 94.439 319 99h60c0-4.679-.672-8.874-2.013-12.588-1.343-3.712-3.232-6.856-5.67-9.43-2.44-2.571-5.367-4.545-8.782-5.92-3.413-1.374-7.192-2.062-11.338-2.062zM435.546 63c6.526 0 12.368 1.093 17.524 3.28 5.154 2.186 9.5 5.286 13.04 9.298 3.538 4.013 6.238 8.85 8.099 14.51 1.861 5.66 2.791 11.994 2.791 19.002 0 7.008-.932 13.327-2.791 18.957-1.861 5.631-4.561 10.452-8.099 14.465-3.54 4.012-7.886 7.097-13.04 9.254-5.156 2.156-10.998 3.234-17.524 3.234-6.529 0-12.369-1.078-17.525-3.234-5.155-2.157-9.517-5.242-13.085-9.254-3.57-4.013-6.285-8.836-8.145-14.465-1.861-5.63-2.791-11.95-2.791-18.957 0-7.008.93-13.342 2.791-19.002 1.861-5.66 4.576-10.496 8.145-14.51 3.568-4.012 7.93-7.112 13.085-9.299C423.177 64.094 429.017 63 435.546 63zm-.501 86c5.341 0 10.006-.918 13.997-2.757 3.99-1.838 7.32-4.474 9.992-7.909 2.67-3.435 4.664-7.576 5.986-12.428 1.317-4.85 1.98-10.288 1.98-16.316 0-5.965-.66-11.389-1.98-16.27-1.322-4.88-3.316-9.053-5.986-12.519-2.67-3.463-6-6.13-9.992-7.999-3.991-1.867-8.657-2.802-13.997-2.802s-10.008.935-13.997 2.802c-3.991 1.87-7.322 4.536-9.992 8-2.671 3.465-4.68 7.637-6.03 12.518-1.35 4.881-2.026 10.305-2.026 16.27 0 6.026.675 11.465 2.025 16.316 1.35 4.852 3.36 8.993 6.031 12.428 2.67 3.435 6 6.07 9.992 7.91 3.99 1.838 8.656 2.756 13.997 2.756z"
            fill="currentColor"
          />
          <path
            d="M530.57 152h-20.05L474 60h18.35c1.61 0 2.967.39 4.072 1.166 1.103.778 1.865 1.763 2.283 2.959l17.722 49.138a92.762 92.762 0 012.551 8.429c.686 2.751 1.298 5.5 1.835 8.25.537-2.75 1.148-5.499 1.835-8.25a77.713 77.713 0 012.64-8.429l18.171-49.138c.417-1.196 1.164-2.181 2.238-2.96 1.074-.776 2.356-1.165 3.849-1.165H567l-36.43 92zM572 61h23v92h-23zM610 153V60.443h13.624c2.887 0 4.78 1.354 5.682 4.06l1.443 6.856a52.7 52.7 0 015.097-4.962 32.732 32.732 0 015.683-3.879 30.731 30.731 0 016.496-2.57c2.314-.632 4.855-.948 7.624-.948 5.832 0 10.63 1.579 14.39 4.736 3.758 3.157 6.57 7.352 8.434 12.585 1.444-3.068 3.248-5.698 5.413-7.894 2.165-2.194 4.541-3.984 7.127-5.367a32.848 32.848 0 018.254-3.068 39.597 39.597 0 018.796-.992c5.111 0 9.653.783 13.622 2.345 3.97 1.565 7.307 3.849 10.014 6.857 2.706 3.007 4.766 6.675 6.18 11.005C739.29 83.537 740 88.5 740 94.092V153h-22.284V94.092c0-5.894-1.294-10.329-3.878-13.306-2.587-2.977-6.376-4.465-11.368-4.465-2.286 0-4.404.391-6.358 1.172a15.189 15.189 0 00-5.144 3.383c-1.473 1.474-2.631 3.324-3.474 5.548-.842 2.225-1.263 4.781-1.263 7.668V153h-22.37V94.092c0-6.194-1.249-10.704-3.744-13.532-2.497-2.825-6.18-4.24-11.051-4.24-3.19 0-6.18.798-8.976 2.391-2.799 1.593-5.399 3.775-7.804 6.54V153H610zM572 30h23v19h-23z"
            fill="currentColor"
            fill-opacity=".8"
          />
        </g>
      </g>
    </svg>
  ]]

  local main = ''
  for _, tree in ipairs(lang_tree:trees()) do
    main = main .. (visit_node(tree:root(), 0, tree, headings,
      { buf = buf, old = old, fname = fname, to_fname = to_fname, indent = 1, },
      stats))
  end

  main = ([[
  <header class="container">
    <nav class="navbar navbar-expand-lg">
      <div>
        <a href="/" class="navbar-brand" aria-label="logo">
          <!--TODO: use <img src="….svg"> here instead. Need one that has green lettering instead of gray. -->
          %s
          <!--<img src="https://neovim.io/logos/neovim-logo.svg" width="173" height="50" alt="Neovim" />-->
        </a>
      </div>
    </nav>
  </header>

  <div class="container golden-grid help-body">
  <div class="col-wide">
  <a name="%s"></a><a name="%s"></a><h1>%s</h1>
  <p>
    <i>
    Nvim <code>:help</code> pages, <a href="https://github.com/neovim/neovim/blob/master/scripts/gen_help_html.lua">generated</a>
    from <a href="https://github.com/neovim/neovim/blob/master/runtime/doc/%s">source</a>
    using the <a href="https://github.com/neovim/tree-sitter-vimdoc">tree-sitter-vimdoc</a> parser.
    </i>
  </p>
  <hr/>
  %s
  </div>
  ]]):format(logo_svg, stats.first_tags[1] or '', stats.first_tags[2] or '', title, vim.fs.basename(fname), main)

  local toc = [[
    <div class="col-narrow toc">
      <div><a href="index.html">Main</a></div>
      <div><a href="vimindex.html">Commands index</a></div>
      <div><a href="quickref.html">Quick reference</a></div>
      <hr/>
  ]]

  local n = 0  -- Count of all headings + subheadings.
  for _, h1 in ipairs(headings) do n = n + 1 + #h1.subheadings end
  for _, h1 in ipairs(headings) do
    toc = toc .. ('<div class="help-toc-h1"><a href="#%s">%s</a>\n'):format(to_heading_tag(h1.name), h1.name)
    if n < 30 or #headings < 10 then  -- Show subheadings only if there aren't too many.
      for _, h2 in ipairs(h1.subheadings) do
        toc = toc .. ('<div class="help-toc-h2"><a href="#%s">%s</a></div>\n'):format(to_heading_tag(h2.name), h2.name)
      end
    end
    toc = toc .. '</div>'
  end
  toc = toc .. '</div>\n'

  local bug_url = get_bug_url_nvim(fname, to_fname, 'TODO', nil)
  local bug_link = string.format('(<a href="%s" target="_blank">report docs bug...</a>)', bug_url)

  local footer = ([[
  <footer>
    <div class="container flex">
      <div class="generator-stats">
        Generated at %s from <code><a href="https://github.com/neovim/neovim/commit/%s">%s</a></code>
      </div>
      <div class="generator-stats">
      parse_errors: %d %s | <span title="%s">noise_lines: %d</span>
      </div>
    <div>
  </footer>
  ]]):format(
    os.date('%Y-%m-%d %H:%M'), commit, commit:sub(1, 7), #stats.parse_errors, bug_link,
    html_esc(table.concat(stats.noise_lines, '\n')), #stats.noise_lines)

  html = ('%s%s%s</div>\n%s</body>\n</html>\n'):format(
    html, main, toc, footer)
  vim.cmd('q!')
  lang_tree:destroy()
  return html, stats
end

local function gen_css(fname)
  local css = [[
    :root {
      --code-color: #008B8B;
      --tag-color: gray;
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
    @media (prefers-color-scheme: dark) {
      :root {
        --code-color: cyan;
      }
    }
    .toc {
      /* max-width: 12rem; */
      height: 95%;  /* Scroll if there are too many items. https://github.com/neovim/neovim.github.io/issues/297 */
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
      border-bottom: 1px solid #41464bd6; /*rgba(0, 0, 0, .9);*/
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
      white-space: normal;
      display: list-item;
      margin-left: 1.5rem; /* padding-left: 1rem; */
    }
    .help-para {
      padding-top: 10px;
      padding-bottom: 10px;
    }
    .old-help-para {
      padding-top: 10px;
      padding-bottom: 10px;
      /* Tabs are used for alignment in old docs, so we must match Vim's 8-char expectation. */
      tab-size: 8;
      white-space: pre;
      font-size: 16px;
      font-family: ui-monospace,SFMono-Regular,SF Mono,Menlo,Consolas,Liberation Mono,monospace;
    }
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
    }
    h1 .help-tag, h2 .help-tag, h3 .help-tag {
      font-size: smaller;
    }
    .help-heading {
      overflow: hidden;
      white-space: nowrap;
      display: flex;
      justify-content: space-between;
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
      white-space: pre;
      line-height: 1.3;  /* Important for ascii art. */
      overflow: visible;
      /* font-family: ui-monospace,SFMono-Regular,SF Mono,Menlo,Consolas,Liberation Mono,monospace; */
      font-size: 16px;
      margin-top: 10px;
    }
    pre:hover,
    .help-heading:hover {
      overflow: visible;
    }
    .generator-stats {
      color: gray;
      font-size: smaller;
    }
  ]]
  tofile(fname, css)
end

function M._test()
  tagmap = get_helptags('./build/runtime/doc')
  helpfiles = get_helpfiles()

  local function ok(cond, expected, actual)
    assert((not expected and not actual) or (expected and actual), 'if "expected" is given, "actual" is also required')
    if expected then
      return assert(cond, ('expected %s, got: %s'):format(vim.inspect(expected), vim.inspect(actual)))
    else
      return assert(cond)
    end
  end
  local function eq(expected, actual)
    return ok(expected == actual, expected, actual)
  end

  ok(vim.tbl_count(tagmap) > 3000, '>3000', vim.tbl_count(tagmap))
  ok(vim.endswith(tagmap['vim.diagnostic.set()'], 'diagnostic.txt'), tagmap['vim.diagnostic.set()'], 'diagnostic.txt')
  ok(vim.endswith(tagmap['%:s'], 'cmdline.txt'), tagmap['%:s'], 'cmdline.txt')
  ok(is_noise([[vim:tw=78:isk=!-~,^*,^\|,^\":ts=8:noet:ft=help:norl:]]))
  ok(is_noise([[          NVIM  REFERENCE  MANUAL     by  Thiago  de  Arruda      ]]))
  ok(not is_noise([[vim:tw=78]]))

  eq(0, get_indent('a'))
  eq(1, get_indent(' a'))
  eq(2, get_indent('  a\n  b\n  c\n'))
  eq(5, get_indent('     a\n      \n        b\n      c\n      d\n      e\n'))
  eq('a\n        \n   b\n c\n d\n e\n', trim_indent('     a\n             \n        b\n      c\n      d\n      e\n'))

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

  print('all tests passed')
end

--- Generates HTML from :help docs located in `help_dir` and writes the result in `to_dir`.
---
--- Example:
---
---   gen('./build/runtime/doc', '/path/to/neovim.github.io/_site/doc/', {'api.txt', 'autocmd.txt', 'channel.txt'}, nil)
---
--- @param help_dir string Source directory containing the :help files. Must run `make helptags` first.
--- @param to_dir string Target directory where the .html files will be written.
--- @param include table|nil Process only these filenames. Example: {'api.txt', 'autocmd.txt', 'channel.txt'}
---
--- @returns info dict
function M.gen(help_dir, to_dir, include, commit)
  vim.validate{
    help_dir={help_dir, function(d) return vim.fn.isdirectory(d) == 1 end, 'valid directory'},
    to_dir={to_dir, 's'},
    include={include, 't', true},
    commit={commit, 's', true},
  }

  local err_count = 0
  ensure_runtimepath()
  tagmap = get_helptags(help_dir)
  helpfiles = get_helpfiles(include)

  print(('output dir: %s'):format(to_dir))
  vim.fn.mkdir(to_dir, 'p')
  gen_css(('%s/help.css'):format(to_dir))

  for _, f in ipairs(helpfiles) do
    local helpfile = vim.fs.basename(f)
    local to_fname = ('%s/%s'):format(to_dir, get_helppage(helpfile))
    local html, stats = gen_one(f, to_fname, not new_layout[helpfile], commit or '?')
    tofile(to_fname, html)
    print(('generated (%-4s errors): %-15s => %s'):format(#stats.parse_errors, helpfile, vim.fs.basename(to_fname)))
    err_count = err_count + #stats.parse_errors
  end
  print(('generated %d html pages'):format(#helpfiles))
  print(('total errors: %d'):format(err_count))
  print(('invalid tags:\n%s'):format(vim.inspect(invalid_links)))

  return {
    helpfiles = helpfiles,
    err_count = err_count,
    invalid_links = invalid_links,
  }
end

-- Validates all :help files found in `help_dir`:
--  - checks that |tag| links point to valid helptags.
--  - recursively counts parse errors ("ERROR" nodes)
--
-- This is 10x faster than gen(), for use in CI.
--
-- @returns results dict
function M.validate(help_dir, include)
  vim.validate{
    help_dir={help_dir, function(d) return vim.fn.isdirectory(d) == 1 end, 'valid directory'},
    include={include, 't', true},
  }
  local err_count = 0
  ensure_runtimepath()
  tagmap = get_helptags(help_dir)
  helpfiles = get_helpfiles(include)

  for _, f in ipairs(helpfiles) do
    local helpfile = vim.fs.basename(f)
    local rv = validate_one(f)
    print(('validated (%-4s errors): %s'):format(#rv.parse_errors, helpfile))
    err_count = err_count + #rv.parse_errors
  end

  return {
    helpfiles = #helpfiles,
    err_count = err_count,
    invalid_links = invalid_links,
    invalid_urls = invalid_urls,
    invalid_spelling = invalid_spelling,
  }
end

return M
