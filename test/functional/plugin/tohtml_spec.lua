local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec = n.exec
local exec_lua = n.exec_lua
local eq = t.eq
local fn = n.fn
local api = n.api
local insert = n.insert

local function html_syntax_match()
  local styles =
    vim.split(api.nvim_exec2([[/<style>/+,/<\/style>/-p]], { output = true }).output, '\n')
  local attrnames = {
    ['font%-weight: bold'] = 'bold',
    ['text%-decoration%-line: [^;]*underline'] = 'underline',
    ['font%-style: italic'] = 'italic',
    ['text%-decoration%-line: [^;]*line%-through'] = 'strikethrough',
  }
  local hls = {}
  for _, style in ipairs(styles) do
    local attr = {}
    for match, attrname in pairs(attrnames) do
      if style:find(match) then
        ---@type boolean
        attr[attrname] = true
      end
    end
    if style:find('text%-decoration%-style: wavy') and attr.underline then
      ---@type boolean
      attr.underline = nil
      attr.undercurl = true
    end
    attr.bg = style:match('background%-color: #(%x+)')
    if attr.bg then
      attr.bg = tonumber(attr.bg, 16)
    end
    attr.fg = style:match('[^%-]color: #(%x+)')
    if attr.fg then
      attr.fg = tonumber(attr.fg, 16)
    end
    if style:match('^%.(%w+)') then
      ---@type table
      hls[style:match('^%.(%w+)')] = attr
    end
  end
  local whitelist = {
    'fg',
    'bg',
    --'sp',
    --'blend',
    'bold',
    --'standout',
    'underline',
    'undercurl',
    --'underdouble',
    --'underdotted',
    --'underdashed',
    'strikethrough',
    'italic',
    --'reverse',
    --'nocombine',
  }
  for name, attrs_old in
    pairs(api.nvim_get_hl(0, { link = true }) --[[@as table<string,table>]])
  do
    ---@type table
    local other = hls[name:gsub('%.', '-'):gsub('@', '-')]
    if other then
      local attrs = {}
      for _, attrname in ipairs(whitelist) do
        ---@type table
        attrs[attrname] = attrs_old[attrname]
      end
      eq(attrs, other)
    end
  end
  return hls
end

local function html_to_extmarks()
  local buf = api.nvim_get_current_buf()
  local ns = api.nvim_create_namespace 'test-namespace'
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  exec 'silent! norm! ggd/^<pre>$\rddG3dk'
  local stack = {}
  exec [[set filetype=]]
  exec [[silent! %s/</¤/g]]
  exec [[silent! %s/&quot;/"/g]]
  exec [[silent! %s/&amp;/\&/g]]
  exec [[silent! %s/&gt;/>/g]]
  exec [[silent! %s/&lt;/</g]]
  for _, match in
    ipairs(
      fn.matchbufline(buf, [[¤span class="\([^"]\+\)">\|¤/span>]], 1, '$', { submatches = true }) --[[@as (table[])]]
    )
  do
    if match.text == '¤/span>' then
      local val = table.remove(stack)
      api.nvim_buf_set_extmark(buf, ns, val.lnum - 1, val.byteidx, {
        hl_group = val.submatches[1],
        end_row = match.lnum - 1,
        end_col = match.byteidx,
      })
    else
      table.insert(stack, match)
    end
  end
  exec [[silent! %s/¤\/span>//g]]
  exec [[silent! %s/¤span[^>]*>//g]]
end

---@param screen test.functional.ui.screen
---@param func function?
local function run_tohtml_and_assert(screen, func)
  exec('norm! ggO-;')
  screen:expect({ any = vim.pesc('-^;') })
  exec('norm! :\rh')
  screen:expect({ any = vim.pesc('^-;') })
  local expected = screen:get_snapshot()
  do
    (func or exec)('TOhtml')
  end
  exec('only')
  html_syntax_match()
  html_to_extmarks()
  exec('norm! gg0f;')
  screen:expect({ any = vim.pesc('-^;') })
  exec('norm! :\rh')
  screen:expect({ grid = expected.grid, attr_ids = expected.attr_ids })
end

describe(':TOhtml', function()
  --- @type test.functional.ui.screen
  local screen
  before_each(function()
    clear({ args = { '--clean' } })
    screen = Screen.new(80, 80)
    screen:attach({ term_name = 'xterm' })
    exec('colorscheme default')
  end)

  it('expected internal html generated', function()
    insert([[line]])
    exec('set termguicolors')
    local bg = fn.synIDattr(fn.hlID('Normal'), 'bg#', 'gui')
    local fg = fn.synIDattr(fn.hlID('Normal'), 'fg#', 'gui')
    exec_lua [[
    local outfile = vim.fn.tempname() .. '.html'
    local html = require('tohtml').tohtml(0,{title="title",font="dumyfont"})
    vim.fn.writefile(html, outfile)
    vim.cmd.split(outfile)
    ]]
    local out_file = api.nvim_buf_get_name(api.nvim_get_current_buf())
    eq({
      '<!DOCTYPE html>',
      '<html>',
      '<head>',
      '<meta charset="UTF-8">',
      '<title>title</title>',
      ('<meta name="colorscheme" content="%s"></meta>'):format(api.nvim_get_var('colors_name')),
      '<style>',
      '* {font-family: dumyfont,monospace}',
      ('body {background-color: %s; color: %s}'):format(bg, fg),
      '</style>',
      '</head>',
      '<body style="display: flex">',
      '<pre>',
      'line',
      '',
      '</pre>',
      '</body>',
      '</html>',
    }, fn.readfile(out_file))
  end)

  it('highlight attributes generated', function()
    --Make sure to uncomment the attribute in `html_syntax_match()`
    exec('hi LINE gui=' .. table.concat({
      'bold',
      'underline',
      'italic',
      'strikethrough',
    }, ','))
    exec('hi UNDERCURL gui=undercurl')
    exec('syn keyword LINE line')
    exec('syn keyword UNDERCURL undercurl')
    insert('line\nundercurl')
    run_tohtml_and_assert(screen)
  end)

  it('syntax', function()
    insert [[
    function main()
      print("hello world")
    end
    ]]
    exec('set termguicolors')
    exec('syntax enable')
    exec('setf lua')
    run_tohtml_and_assert(screen)
  end)

  it('diff', function()
    exec('set diffopt=')
    insert [[
    diffadd
    nochage
    diffchange1
    ]]
    exec('new')
    insert [[
    nochage
    diffchange2
    diffremove
    ]]
    exec('set diff')
    exec('close')
    exec('set diff')
    run_tohtml_and_assert(screen)
  end)

  it('treesitter', function()
    insert [[
    function main()
      print("hello world")
    end
    ]]
    exec('setf lua')
    exec_lua('vim.treesitter.start()')
    run_tohtml_and_assert(screen)
  end)

  it('matchadd', function()
    insert [[
    line
    ]]
    fn.matchadd('Visual', 'line')
    run_tohtml_and_assert(screen)
  end)

  describe('conceallevel', function()
    local function run(level)
      insert([[
      line0
      line1
      line2
      line3
      ]])
      local ns = api.nvim_create_namespace ''
      fn.matchadd('Conceal', 'line1', 3, 5, { conceal = 'a' })
      api.nvim_buf_set_extmark(0, ns, 2, 0, { conceal = 'a', end_col = 5 })
      exec(':syntax match Conceal "line3" conceal cchar=a')
      exec('set conceallevel=' .. level)
      run_tohtml_and_assert(screen)
    end
    it('conceallevel=0', function()
      run(0)
    end)
    it('conceallevel=1', function()
      run(1)
    end)
    it('conceallevel=2', function()
      run(2)
    end)
    it('conceallevel=3', function()
      run(3)
    end)
  end)

  describe('extmarks', function()
    it('virt_text', function()
      insert [[
      line1
      line2
      line3
      line4
      ]]
      local ns = api.nvim_create_namespace ''
      api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = { { 'foo' } } })
      api.nvim_buf_set_extmark(
        0,
        ns,
        1,
        0,
        { virt_text = { { 'foo' } }, virt_text_pos = 'overlay' }
      )
      api.nvim_buf_set_extmark(0, ns, 2, 0, { virt_text = { { 'foo' } }, virt_text_pos = 'inline' })
      --api.nvim_buf_set_extmark(0,ns,3,0,{virt_text={{'foo'}},virt_text_pos='right_align'})
      run_tohtml_and_assert(screen)
    end)
    it('highlight', function()
      insert [[
      line1
      ]]
      local ns = api.nvim_create_namespace ''
      api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 2, hl_group = 'Visual' })
      run_tohtml_and_assert(screen)
    end)
    it('virt_line', function()
      insert [[
      line1
      line2
      ]]
      local ns = api.nvim_create_namespace ''
      api.nvim_buf_set_extmark(0, ns, 1, 0, { end_col = 2, virt_lines = { { { 'foo' } } } })
      run_tohtml_and_assert(screen)
    end)
  end)

  it('listchars', function()
    exec('setlocal list')
    exec(
      'setlocal listchars=eol:$,tab:<->,space:-,multispace:++,lead:_,leadmultispace:##,trail:&,nbsp:%'
    )
    fn.setline(1, '\tfoo\t')
    fn.setline(2, ' foo foo ')
    fn.setline(3, '  foo  foo  ')
    fn.setline(4, 'foo\194\160 \226\128\175foo')
    run_tohtml_and_assert(screen)
    exec('new|only')
    fn.setline(1, '\tfoo\t')
    exec('setlocal list')
    exec('setlocal listchars=tab:a-')
    run_tohtml_and_assert(screen)
  end)

  it('folds', function()
    insert([[
    line1
    line2
    ]])
    exec('set foldtext=foldtext()')
    exec('%fo')
    run_tohtml_and_assert(screen)
  end)

  it('statuscol', function()
    local function run()
      local buf = api.nvim_get_current_buf()
      run_tohtml_and_assert(screen, function()
        exec_lua [[
        local outfile = vim.fn.tempname() .. '.html'
        local html = require('tohtml').tohtml(0,{number_lines=true})
        vim.fn.writefile(html, outfile)
        vim.cmd.split(outfile)
        ]]
      end)
      api.nvim_set_current_buf(buf)
    end
    insert([[
    line1
    line2
    ]])
    exec('setlocal relativenumber')
    run()
    exec('setlocal norelativenumber')
    exec('setlocal number')
    run()
    exec('setlocal relativenumber')
    run()
    exec('setlocal signcolumn=yes:2')
    run()
    exec('setlocal foldcolumn=2')
    run()
    exec('setlocal norelativenumber')
    run()
    exec('setlocal signcolumn=no')
    run()
  end)
end)
