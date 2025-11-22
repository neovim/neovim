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

describe(':help', function()
  before_each(function()
    os.remove('test.log')
    clear{
      env = {
        -- NVIM_LOG_FILE = 'test.log',
      },
    }
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

describe(':help', function()
  setup(function()
    n.clear{
      args = {
        '+helptags $VIMRUNTIME/doc'
      }
    }
    command('enew')
    command('set filetype=help')
    -- XXX: hacky way to load the `help.lua` module.
    n.exec_lua([[
      _G.test_help = dofile(vim.fs.joinpath(vim.env.VIMRUNTIME, 'ftplugin/help.lua'))
    ]])
  end)

  before_each(function()
    command('enew')
    command('set filetype=help')
  end)

  it('":help FOO" guesses the best tag near cursor', function()
    local function set_lines(text)
      n.exec_lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, ...)]], text)
    end
    local cursor = n.api.nvim_win_set_cursor
    local function open_helptag()
      -- TODO: also test ":help FOO" explicitly.
      n.exec[[:normal! K]]
      local word = n.fn.expand('<cWORD>')
      local bufname = n.fn.fnamemodify(n.fn.bufname('%'), ':t')
      if n.fn.winnr('$') > 1 then
        n.command('close')
      end
      return { word, bufname }
    end

    n.command[[set keywordprg=:help]]

    set_lines {'some plain text'}
    cursor(0, {1, 5}) -- on 'plain'
    eq({'*ft-plaintex-syntax*', 'syntax.txt'}, open_helptag())

    set_lines {':help command'}
    cursor(0, {1, 4})
    eq({'*:help*', 'helphelp.txt'}, open_helptag())

    set_lines {' :help command'}
    cursor(0, {1, 5})
    eq({'*:help*', 'helphelp.txt'}, open_helptag())

    set_lines {'v:version name'}
    cursor(0, {1, 5})
    eq({'*v:version*', 'vvars.txt'}, open_helptag())
    cursor(0, {1, 2})
    eq({'*v:version*', 'vvars.txt'}, open_helptag())

    set_lines {"See 'option' for more."}
    cursor(0, {1, 6}) -- on 'option'
    eq({"*'option'*", 'intro.txt'}, open_helptag())

    set_lines {':command-nargs'}
    cursor(0, {1, 7}) -- on 'nargs'
    eq({'*:command-nargs*', 'map.txt'}, open_helptag())

    set_lines {'|("vim.lsp.foldtext()")|'}
    cursor(0, {1, 10})
    eq({'*vim.lsp.foldtext()*', 'lsp.txt'}, open_helptag())

    set_lines {'nvim_buf_detach_event[{buf}]'}
    cursor(0, {1, 10})
    eq({'*nvim_buf_detach_event*', 'api.txt'}, open_helptag())

    set_lines {'{buf}'}
    cursor(0, {1, 1})
    eq({'*:buf*', 'windows.txt'}, open_helptag())

    set_lines {'(`vim.lsp.ClientConfig`)'}
    cursor(0, {1, 1})
    eq({'*vim.lsp.ClientConfig*', 'lsp.txt'}, open_helptag())

    set_lines {"vim.lsp.enable('clangd')"}
    cursor(0, {1, 3})
    eq({'*vim.lsp.enable()*', 'lsp.txt'}, open_helptag())

    set_lines {"vim.lsp.enable('clangd')"}
    cursor(0, {1, 6})
    eq({'*vim.lsp.enable()*', 'lsp.txt'}, open_helptag())

    set_lines {"vim.lsp.enable('clangd')"}
    cursor(0, {1, 9})
    eq({'*vim.lsp.enable()*', 'lsp.txt'}, open_helptag())

    set_lines {'assert(vim.lsp.get_client_by_id(client_id))'}
    cursor(0, {1, 12})
    eq({'*vim.lsp.get_client_by_id()*', 'lsp.txt'}, open_helptag())

    set_lines {"vim.api.nvim_create_autocmd('LspAttach', {"}
    cursor(0, {1, 7})
    eq({'*nvim_create_autocmd()*', 'api.txt'}, open_helptag())

    -- set_lines {' |vim.lsp.start()|. '}
    -- cursor(0, {1, 4})
    -- eq({'*vim.lsp.start()*', 'lsp.txt'}, open_helptag())
    --
    -- (`table<integer, {error: lsp.ResponseError?, result: any}>?`) result
  end)
end)
