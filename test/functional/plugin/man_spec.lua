local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local command, rawfeed = helpers.command, helpers.rawfeed
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local funcs = helpers.funcs
local nvim_prog = helpers.nvim_prog
local matches = helpers.matches
local write_file = helpers.write_file
local tmpname = helpers.tmpname
local eq = helpers.eq
local skip = helpers.skip
local is_ci = helpers.is_ci

-- Collects all names passed to find_path() after attempting ":Man foo".
local function get_search_history(name)
  local args = vim.split(name, ' ')
  local code = [[
    local args = ...
    local man = require('runtime.lua.man')
    local res = {}
    man.find_path = function(sect, name)
      table.insert(res, {sect, name})
      return nil
    end
    local ok, rv = pcall(man.open_page, -1, {tab = 0}, args)
    assert(not ok)
    assert(rv and rv:match('no manual entry'))
    return res
  ]]
  return exec_lua(code, args)
end

clear()
if funcs.executable('man') == 0 then
  pending('missing "man" command', function() end)
  return
end

describe(':Man', function()
  before_each(function()
    clear()
  end)

  describe('man.lua: highlight_line()', function()
    local screen

    before_each(function()
      command('syntax on')
      command('set filetype=man')
      command('syntax off')  -- Ignore syntax groups
      screen = Screen.new(52, 5)
      screen:set_default_attr_ids({
        b = { bold = true },
        i = { italic = true },
        u = { underline = true },
        bi = { bold = true, italic = true },
        biu = { bold = true, italic = true, underline = true },
        c = { foreground = Screen.colors.Blue }, -- control chars
        eob = { bold = true, foreground = Screen.colors.Blue } -- empty line '~'s
      })
      screen:attach()
    end)

    it('clears backspaces from text and adds highlights', function()
      rawfeed([[
        ithis i<C-v><C-h>is<C-v><C-h>s a<C-v><C-h>a test
        with _<C-v><C-h>o_<C-v><C-h>v_<C-v><C-h>e_<C-v><C-h>r_<C-v><C-h>s_<C-v><C-h>t_<C-v><C-h>r_<C-v><C-h>u_<C-v><C-h>c_<C-v><C-h>k text<ESC>]])

      screen:expect{grid=[[
        this i{c:^H}is{c:^H}s a{c:^H}a test                             |
        with _{c:^H}o_{c:^H}v_{c:^H}e_{c:^H}r_{c:^H}s_{c:^H}t_{c:^H}r_{c:^H}u_{c:^H}c_{c:^H}k tex^t  |
        {eob:~                                                   }|
        {eob:~                                                   }|
                                                            |
      ]]}

      exec_lua[[require'man'.init_pager()]]

      screen:expect([[
      ^this {b:is} {b:a} test                                      |
      with {i:overstruck} text                                |
      {eob:~                                                   }|
      {eob:~                                                   }|
                                                          |
      ]])
    end)

    it('clears escape sequences from text and adds highlights', function()
      rawfeed([[
        ithis <C-v><ESC>[1mis <C-v><ESC>[3ma <C-v><ESC>[4mtest<C-v><ESC>[0m
        <C-v><ESC>[4mwith<C-v><ESC>[24m <C-v><ESC>[4mescaped<C-v><ESC>[24m <C-v><ESC>[4mtext<C-v><ESC>[24m<ESC>]])

      screen:expect{grid=[=[
        this {c:^[}[1mis {c:^[}[3ma {c:^[}[4mtest{c:^[}[0m                  |
        {c:^[}[4mwith{c:^[}[24m {c:^[}[4mescaped{c:^[}[24m {c:^[}[4mtext{c:^[}[24^m  |
        {eob:~                                                   }|
        {eob:~                                                   }|
                                                            |
      ]=]}

      exec_lua[[require'man'.init_pager()]]

      screen:expect([[
      ^this {b:is }{bi:a }{biu:test}                                      |
      {u:with} {u:escaped} {u:text}                                   |
      {eob:~                                                   }|
      {eob:~                                                   }|
                                                          |
      ]])
    end)

    it('highlights multibyte text', function()
      rawfeed([[
        ithis i<C-v><C-h>is<C-v><C-h>s あ<C-v><C-h>あ test
        with _<C-v><C-h>ö_<C-v><C-h>v_<C-v><C-h>e_<C-v><C-h>r_<C-v><C-h>s_<C-v><C-h>t_<C-v><C-h>r_<C-v><C-h>u_<C-v><C-h>̃_<C-v><C-h>c_<C-v><C-h>k te<C-v><ESC>[3mxt¶<C-v><ESC>[0m<ESC>]])
      exec_lua[[require'man'.init_pager()]]

      screen:expect([[
      ^this {b:is} {b:あ} test                                     |
      with {i:överstrũck} te{i:xt¶}                               |
      {eob:~                                                   }|
      {eob:~                                                   }|
                                                          |
      ]])
    end)

    it('highlights underscores based on context', function()
      rawfeed([[
        i_<C-v><C-h>_b<C-v><C-h>be<C-v><C-h>eg<C-v><C-h>gi<C-v><C-h>in<C-v><C-h>ns<C-v><C-h>s
        m<C-v><C-h>mi<C-v><C-h>id<C-v><C-h>d_<C-v><C-h>_d<C-v><C-h>dl<C-v><C-h>le<C-v><C-h>e
        _<C-v><C-h>m_<C-v><C-h>i_<C-v><C-h>d_<C-v><C-h>__<C-v><C-h>d_<C-v><C-h>l_<C-v><C-h>e<ESC>]])
      exec_lua[[require'man'.init_pager()]]

      screen:expect([[
      {b:^_begins}                                             |
      {b:mid_dle}                                             |
      {i:mid_dle}                                             |
      {eob:~                                                   }|
                                                          |
      ]])
    end)

    it('highlights various bullet formats', function()
      rawfeed([[
        i· ·<C-v><C-h>·
        +<C-v><C-h>o
        +<C-v><C-h>+<C-v><C-h>o<C-v><C-h>o double<ESC>]])
      exec_lua[[require'man'.init_pager()]]

      screen:expect([[
      ^· {b:·}                                                 |
      {b:·}                                                   |
      {b:·} double                                            |
      {eob:~                                                   }|
                                                          |
      ]])
    end)

    it('handles : characters in input', function()
      rawfeed([[
        i<C-v><C-[>[40m    0  <C-v><C-[>[41m    1  <C-v><C-[>[42m    2  <C-v><C-[>[43m    3
        <C-v><C-[>[44m    4  <C-v><C-[>[45m    5  <C-v><C-[>[46m    6  <C-v><C-[>[47m    7  <C-v><C-[>[100m    8  <C-v><C-[>[101m    9
        <C-v><C-[>[102m   10  <C-v><C-[>[103m   11  <C-v><C-[>[104m   12  <C-v><C-[>[105m   13  <C-v><C-[>[106m   14  <C-v><C-[>[107m   15
        <C-v><C-[>[48:5:16m   16  <ESC>]])
      exec_lua[[require'man'.init_pager()]]

      screen:expect([[
       ^    0      1      2      3                          |
           4      5      6      7      8      9            |
          10     11     12     13     14     15            |
          16                                               |
                                                           |
      ]])
    end)
  end)

  it('q quits in "$MANPAGER mode" (:Man!) #18281', function()
    -- This will hang if #18281 regresses.
    local args = {nvim_prog, '--headless', '+autocmd VimLeave * echo "quit works!!"', '+Man!', '+call nvim_input("q")'}
    matches('quit works!!', funcs.system(args, {'manpage contents'}))
  end)

  it('reports non-existent man pages for absolute paths', function()
    skip(is_ci('cirrus'))
    local actual_file = tmpname()
    -- actual_file must be an absolute path to an existent file for us to test against it
    matches('^/.+', actual_file)
    write_file(actual_file, '')
    local args = {nvim_prog, '--headless', '+:Man ' .. actual_file, '+q'}
    matches(('Error detected while processing command line:\r\n' ..
      'man.lua: "no manual entry for %s"'):format(actual_file),
      funcs.system(args, {''}))
    os.remove(actual_file)
  end)

  it('tries variants with spaces, underscores #22503', function()
    eq({
       {'', 'NAME WITH SPACES'},
       {'', 'NAME_WITH_SPACES'},
      }, get_search_history('NAME WITH SPACES'))
    eq({
       {'3', 'some other man'},
       {'3', 'some_other_man'},
      }, get_search_history('3 some other man'))
    eq({
       {'3x', 'some other man'},
       {'3x', 'some_other_man'},
      }, get_search_history('3X some other man'))
    eq({
       {'3tcl', 'some other man'},
       {'3tcl', 'some_other_man'},
      }, get_search_history('3tcl some other man'))
    eq({
       {'n', 'some other man'},
       {'n', 'some_other_man'},
      }, get_search_history('n some other man'))
    eq({
       {'', '123some other man'},
       {'', '123some_other_man'},
      }, get_search_history('123some other man'))
    eq({
       {'1', 'other_man'},
       {'1', 'other_man'},
      }, get_search_history('other_man(1)'))
  end)
end)
