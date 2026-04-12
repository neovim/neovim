local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local fn = n.fn
local api = n.api
local mkdir = t.mkdir
local rmdir = n.rmdir
local write_file = t.write_file

local cursor = n.api.nvim_win_set_cursor

local function buf_word()
  local word = n.fn.expand('<cWORD>')
  local bufname = n.fn.fnamemodify(n.fn.bufname('%'), ':t')
  return { word, bufname }
end

local function open_helptag()
  -- n.exec [[:normal! K]]
  n.exec [[:help!]]
  local rv = buf_word()
  if n.fn.winnr('$') > 1 then
    n.command('close')
  end
  return rv
end

local function set_lines(text)
  n.exec_lua(
    [[
    vim.cmd'%delete _'
    vim.api.nvim_paste(vim.text.indent(-1, ...), false, -1)
  ]],
    text
  )
end

describe(':help', function()
  before_each(clear)

  it('{subject}', function()
    n.command('helptags ++t $VIMRUNTIME/doc')
    local function check_tag(cmd, tag)
      local cmd_ok = t.pcall(n.command, cmd)
      local found = n.api.nvim_get_current_line():find(tag, 1, true)
      local errmsg = (not cmd_ok and 'command failed') or (not found and 'tag not found') or '?'
      assert(
        cmd_ok and found,
        string.format('Expected `:%s` to jump to tag `%s`, but %s', cmd, tag, errmsg)
      )
      n.command('helpclose')
    end

    check_tag('help', '*help.txt*')
    check_tag('help |', '*bar*')
    check_tag('help "*', '*quotestar*')
    check_tag('help ch??khealth', '*:checkhealth*')

    check_tag([[help \\star]], [[*/\star*]])
    check_tag('help /*', [[*/\star*]])
    check_tag('help ?', '*?*')
    check_tag('help ??', '*??*')
    check_tag('help expr-!=?', '*expr-!=?*')

    check_tag('help /<cr>', '*/<CR>*')
    check_tag([[help %(\\)]], [[*/\%(\)*]])
    check_tag('help %^', [[/\%^]])
    check_tag('help /_^G', '/_CTRL-G')
    check_tag([[help \0]], [[\0]])

    check_tag('help !', '*!*')
    check_tag('help #{}', '*#{}*')
    check_tag('help %:8', '*%:8*')
    check_tag('help &', '*&*')
    check_tag([[help '']], [[*''*]])
    check_tag([[help '(]], [[*'(*]])
    check_tag([[help '0]], [[*'0*]])
    check_tag([[help 'ac']], [[*'ac'*]])
    check_tag([[help '{]], [[*'{*]])
    check_tag('help )', '*)*')
    check_tag('help +', '*+*')

    check_tag('help +opt', '*++opt*')
    check_tag('help --', '*--*')
    check_tag('help -?', '*-?*')
    check_tag('help .', '*.*')
    check_tag('help :', '*:*')
    check_tag([[help :'}]], [[*:'}*]])
    check_tag('help :,', '*:,*')
    check_tag('help :<abuf>', '*:<abuf>*')
    check_tag([[help :\|]], [[*:\bar*]])
    check_tag([[help :\\|]], [[*:\bar*]])
    check_tag('help _', '*_*')
    check_tag('help `', '*`*')
    check_tag('help `(', '*`(*')
    check_tag([[help `:ls`.]], [[*:ls*]])

    check_tag('help [', '*[*')
    check_tag('help [#', '*[#*')
    check_tag([[help [']], [[*['*]])
    check_tag('help [(', '*[(*')
    check_tag('help [++opt]', '*[++opt]*')
    check_tag('help [:tab:]', '*[:tab:]*')
    check_tag('help [count]', '*[count]*')
    check_tag('help :[range]', '*:[range]*')
    check_tag('help [<space>', '[<Space>')
    check_tag('help ]_^D', ']_CTRL-D')

    check_tag([[help $HOME]], [[*$HOME*]])

    check_tag('help <C-pagedown>', '*CTRL-<PageDown>*')
    check_tag('help ^A', '*CTRL-A*')
    check_tag('help ^W_+', '*CTRL-W_+*')
    check_tag('help ^W<up>', '*CTRL-W_<Up>*')
    check_tag('help ^W>', '*CTRL-W_>*')
    check_tag('help ^W^]', '*CTRL-W_CTRL-]*')
    check_tag('help ^W^', '*CTRL-W_^*')
    check_tag('help ^W|', '*CTRL-W_bar*')
    check_tag('help ^Wg<tab>', '*CTRL-W_g<Tab>*')
    check_tag('help ^]', '*CTRL-]*')
    check_tag('help ^{char}', 'CTRL-{char}')
    check_tag('help [^L', '[_CTRL-L')
    check_tag('help <C-', '*<C-*')
    check_tag('help <S-CR>', '*<S-CR>*')
    check_tag('help <<', '*<<*')
    check_tag('help <>', '*<>*')
    check_tag([[help i^x^y]], '*i_CTRL-X_CTRL-Y*')
    check_tag([[help CTRL-\_CTRL-N]], [[*CTRL-\_CTRL-N*]])

    check_tag([[exe "help i\<C-\>\<C-G>"]], [[*i_CTRL-\_CTRL-G*]])
    check_tag([[exe "help \<C-V>"]], '*CTRL-V*')
    check_tag([[exe "help! arglistid([{winnr})"]], '*arglistid()*')
    check_tag([[exe "help! 'autoindent'."]], [[*'autoindent'*]])

    check_tag('exusage', '*:index*')
    check_tag('viusage', '*normal-index*')

    -- Test cases for removed exceptions
    check_tag('help /\\(\\)', '*/\\(\\)*')
    check_tag('help :s\\=', '*:s\\=*')
    check_tag([[help expr-']], [[*expr-'*]])
    check_tag('help expr-barbar', '*expr-barbar*')
    check_tag([[help s/\9]], [[*s/\9*]])
    check_tag([[help s/\U]], [[*s/\U*]])
    check_tag([[help s/\~]], [[*s/\~*]])
    check_tag([[help \|]], [[*/\bar*]])
  end)

  it('":help!" (bang + no args) guesses the best tag near cursor', function()
    n.command('helptags ++t $VIMRUNTIME/doc')
    -- n.command('enew')
    -- n.command('set filetype=help')
    -- n.command [[set keywordprg=:help]]

    -- Failure modes:
    set_lines ''
    cursor(0, { 1, 1 })
    t.matches('E349: No identifier under cursor', t.pcall_err(n.exec, [[:help!]]))

    set_lines 'xxxxxxxxx'
    cursor(0, { 1, 4 })
    t.matches('E149: No help for xxxxxxxxx', t.pcall_err(n.exec, [[:help!]]))

    -- Success:

    set_lines 'some plain text'
    cursor(0, { 1, 5 }) -- on 'plain'
    eq({ '*ft-plaintex-syntax*', 'syntax.txt' }, open_helptag())

    set_lines ':help command'
    cursor(0, { 1, 4 })
    eq({ '*:help*', 'helphelp.txt' }, open_helptag())

    set_lines ' :help command'
    cursor(0, { 1, 5 })
    eq({ '*:command*', 'map.txt' }, open_helptag())

    set_lines 'v:version name'
    cursor(0, { 1, 5 })
    eq({ '*v:version*', 'vvars.txt' }, open_helptag())
    cursor(0, { 1, 2 })
    eq({ '*v:version*', 'vvars.txt' }, open_helptag())

    set_lines "See 'option' for more."
    cursor(0, { 1, 6 }) -- on 'option'
    eq({ "*'option'*", 'helphelp.txt' }, open_helptag())

    set_lines ':command-nargs'
    cursor(0, { 1, 7 }) -- on 'nargs'
    eq({ '*:command-nargs*', 'map.txt' }, open_helptag())

    set_lines '|("vim.lsp.foldtext()")|'
    cursor(0, { 1, 10 })
    eq({ '*vim.lsp.foldtext()*', 'lsp.txt' }, open_helptag())

    set_lines 'nvim_buf_detach_event[{buf}]'
    cursor(0, { 1, 10 })
    eq({ '*nvim_buf_detach_event*', 'api.txt' }, open_helptag())

    set_lines '{buf}'
    cursor(0, { 1, 1 })
    eq({ '*:buf*', 'windows.txt' }, open_helptag())

    set_lines '(`vim.lsp.ClientConfig`)'
    cursor(0, { 1, 1 })
    eq({ '*vim.lsp.ClientConfig*', 'lsp.txt' }, open_helptag())

    set_lines "vim.lsp.enable('clangd')"
    cursor(0, { 1, 3 })
    eq({ '*vim.lsp.enable()*', 'lsp.txt' }, open_helptag())

    set_lines "vim.lsp.enable('clangd')"
    cursor(0, { 1, 6 })
    eq({ '*vim.lsp.enable()*', 'lsp.txt' }, open_helptag())

    set_lines "vim.lsp.enable('clangd')"
    cursor(0, { 1, 9 })
    eq({ '*vim.lsp.enable()*', 'lsp.txt' }, open_helptag())

    set_lines 'assert(vim.lsp.get_client_by_id(client_id))'
    cursor(0, { 1, 12 })
    eq({ '*vim.lsp.get_client_by_id()*', 'lsp.txt' }, open_helptag())

    set_lines "vim.api.nvim_create_autocmd('LspAttach', {"
    cursor(0, { 1, 7 })
    eq({ '*nvim_create_autocmd()*', 'api.txt' }, open_helptag())

    -- Falls back to <cword> when all trimming fails.
    set_lines "'@lsp.type.function'"
    cursor(0, { 1, 2 }) -- on 'lsp'
    eq({ '*lsp*', 'lsp.txt' }, open_helptag())
    set_lines "'@lsp.type.function'"
    cursor(0, { 1, 14 }) -- on 'function'
    eq({ '*:function*', 'userfunc.txt' }, open_helptag())

    set_lines '  • `@lsp.type.<type>.<ft>` for the type'
    cursor(0, { 1, 6 }) -- on backtick '`' (byte 6, after 2 spaces + 3-byte '•' + space)
    eq({ '*lsp*', 'lsp.txt' }, open_helptag())

    set_lines [[
    - `root_dir` usages akin to >lua
       root_dir  = require'lspconfig.util'.root_pattern(...)
    <
    require'lspconfig.util'.root_pattern(...)
    ]]
    cursor(0, { 2, 17 }) -- on "require"
    eq({ '*require()*', 'luaref.txt' }, open_helptag())

    set_lines '`:lsp restart`. You'
    cursor(0, { 1, 6 }) -- on "restart"
    eq({ '*:restart*', 'gui.txt' }, open_helptag())

    --
    -- Test with actual helpfiles. This affects getcompletion(…,'help') ...
    --

    n.command(':help lua')
    n.feed('gg/package.searchpath<cr>')
    eq({ "vim.cmd.edit(package.searchpath('jit.p',", 'lua.txt' }, buf_word())
    --               ^ cursor on "package"
    n.command(':help!')
    eq({ '*packages*', 'pack.txt' }, buf_word())

    n.command(':help lsp')
    n.feed('gg/type.<lt>type><cr>')
    eq({ '`@lsp.type.<type>.<ft>`', 'lsp.txt' }, buf_word())
    --          ^ cursor on "type"
    n.command(':help!')
    eq({ '*type()*', 'vimfn.txt' }, buf_word())
    n.feed('<c-o>f<lt>')
    eq({ '`@lsp.type.<type>.<ft>`', 'lsp.txt' }, buf_word())
    --               ^ cursor on "<"
    n.command(':help!')

    n.command(':help lsp')
    n.feed('gg/codelens.run()|<cr>')
    eq({ '|vim.lsp.codelens.run()|', 'lsp.txt' }, buf_word())
    --             ^ cursor on "codelens"
    n.command(':help!')
    eq({ '*vim.lsp.codelens.run()*', 'lsp.txt' }, buf_word())
  end)

  it('window closed makes cursor return to a valid win/buf #9773', function()
    n.add_builddir_to_rtp()
    command('help help')
    eq(1001, fn.win_getid())
    command('quit')
    eq(1000, fn.win_getid())

    command('autocmd WinNew * wincmd p')

    command('help help')
    -- Window 1002 is opened, but the autocmd switches back to 1000 and
    -- creates the help buffer there instead.
    eq(1000, fn.win_getid())
    command('quit')
    -- Before #9773, Nvim would crash on quitting the help window.
    eq(1002, fn.win_getid())
  end)

  it('multibyte help tags work #23975', function()
    mkdir('Xhelptags')
    finally(function()
      rmdir('Xhelptags')
    end)
    mkdir('Xhelptags/doc')
    write_file('Xhelptags/doc/Xhelptags.txt', '*…*')
    command('helptags Xhelptags/doc')
    command('set rtp+=Xhelptags')
    command('help …')
    eq('*…*', api.nvim_get_current_line())
  end)
end)
