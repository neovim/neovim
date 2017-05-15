
local helpers = require('test.functional.helpers')(after_each)
local clear, nvim, buffer = helpers.clear, helpers.nvim, helpers.buffer
local Screen = require('test.functional.ui.screen')
local os = require('os')
local feed, insert = helpers.feed, helpers.insert
local command = helpers.command
local eval, exc_exec = helpers.eval, helpers.exc_exec
local feed_command, request, eq = helpers.feed_command, helpers.request, helpers.eq
local ok = helpers.ok
local meths = helpers.meths


describe('highlight api', function()
  -- When using manual syntax highlighting, it should be preserved even when
  -- switching buffers... bug did only occur without :set hidden
  -- Ref: vim patch 7.4.1236
  -- local screen

  -- before_each(clear)
  before_each(function()
    clear()
    -- screen = Screen.new(20,5)
    -- screen:attach()
    -- syntax highlight for vimcscripts "echo"
    -- screen:set_default_attr_ids( {
    --   [0] = {bold=true, foreground=Screen.colors.Blue},
    --   [1] = {bold=true, foreground=Screen.colors.Brown}
    -- } )
    end)

  after_each(function()
    -- screen:detach()
    -- os.remove('Xtest-functional-ui-highlight.tmp.vim')
  end)
-- {'foreground': 0, 'background': 65280}
  it("from_id", function()
    -- feed_command('')
    -- local cursor_hl = {foreground= 0, background= 65280}
    -- eval('nvim_hl_from_id(47)')
    -- nvim_async
    --
    local cursor_expected = {Screen.colors.Yellow, foreground = Screen.colors.Red}
    -- local cursor_expected = {Screen.colors.Yellow, foreground = Screen.colors.Red}

    -- feed_command('hi! Cursor guifg=red guibg=yellow guisp=red')
    local cursor_from_name_res = nvim("hl_from_name", 'Normal')
    -- local cursor_from_id_res = eval('nvim_hl_from_id(47)')
    eq(nvim("hl_from_name", 'Normal'), {})
    local err, emsg = pcall(meths.hl_from_name , 'unknown_highlight')
    eq(false, err)
    print("tot", emsg)
    local error_pattern = 'Invalid highlight'

    ok(string.find(emsg, error_pattern) ~= nil)
    -- eq(nvim("hl_from_name", 'unknown_highlight'), {})
    -- eq(cursor_expected, nvim("hl_from_name", 'Normal'))
    -- eq( eval('nvim_hl_from_id(47)')
    -- feed_command('e Xtest-functional-ui-highlight.tmp.vim')
    -- feed_command('filetype on')
    -- feed_command('syntax manual')
    -- feed_command('set ft=vim')
    -- feed_command('set syntax=ON')
    -- feed('iecho 1<esc>0')

    -- feed_command('set hidden')
    -- feed_command('w')
    -- feed_command('bn')
    -- feed_command('bp')
    -- screen:expect([[
    --   {1:^echo} 1              |
    --   {0:~                   }|
    --   {0:~                   }|
    --   {0:~                   }|
    --   <f 1 --100%-- col 1 |
    -- ]])
  end)
end)

