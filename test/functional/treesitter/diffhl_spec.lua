local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local t = require('test.testutil')
local clear = n.clear
local api = n.api
local command = n.command
local exec_lua = n.exec_lua
local write_file = t.write_file

local diff_lines = {
  'diff --git a/foo.lua b/foo.lua',
  '--- a/foo.lua',
  '+++ b/foo.lua',
  '@@ -1,2 +1,2 @@',
  ' local x = 1',
  '-local y = 2',
  '+local y = 3',
}

describe('diff hunk highlighting', function()
  before_each(function()
    clear()
    command('filetype plugin on')
  end)

  it('highlights code inside lua hunks via tree-sitter', function()
    local screen = Screen.new(44, 8)
    api.nvim_buf_set_lines(0, 0, -1, false, diff_lines)
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       {15:local} {25:x} {15:=} {26:1}                                |
      -{15:local} {25:y} {15:=} {26:2}                                |
      +{15:local} {25:y} {15:=} {26:3}                                |
                                                  |
    ]])
  end)

  it('highlights the viewport of a large hunk without blocking', function()
    local screen = Screen.new(44, 8)
    local lines = {
      'diff --git a/big.lua b/big.lua',
      '--- /dev/null',
      '+++ b/big.lua',
      '@@ -0,0 +1,2000 @@',
    }
    for i = 1, 2000 do
      lines[#lines + 1] = ('+local v%d = %d'):format(i, i)
    end
    api.nvim_buf_set_lines(0, 0, -1, false, lines)
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/big.lua b/big.lua              |
      --- /dev/null                               |
      +++ b/big.lua                               |
      @@ -0,0 +1,2000 @@                          |
      +{15:local} {25:v1} {15:=} {26:1}                               |
      +{15:local} {25:v2} {15:=} {26:2}                               |
      +{15:local} {25:v3} {15:=} {26:3}                               |
                                                  |
    ]])
  end)

  it('does not highlight when disabled via vim.g.diffhl', function()
    local screen = Screen.new(44, 8)
    api.nvim_set_var('diffhl', false)
    api.nvim_buf_set_lines(0, 0, -1, false, diff_lines)
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       local x = 1                                |
      -local y = 2                                |
      +local y = 3                                |
                                                  |
    ]])
  end)

  it('re-highlights when a parser becomes available on runtimepath', function()
    local screen = Screen.new(44, 8)
    exec_lua(function()
      local so = vim.api.nvim_get_runtime_file('parser/lua.so', false)[1]
      _G.parser_dir = vim.fn.fnamemodify(so, ':h:h')
      vim.opt.rtp:remove(_G.parser_dir)
    end)
    api.nvim_buf_set_lines(0, 0, -1, false, diff_lines)
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       local x = 1                                |
      -local y = 2                                |
      +local y = 3                                |
                                                  |
    ]])
    exec_lua(function()
      vim.opt.rtp:append(_G.parser_dir)
    end)
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       {15:local} {25:x} {15:=} {26:1}                                |
      -{15:local} {25:y} {15:=} {26:2}                                |
      +{15:local} {25:y} {15:=} {26:3}                                |
                                                  |
    ]])
  end)

  it('keeps highlighting after an autoread reload', function()
    local screen = Screen.new(44, 8)
    local dir = 'Xtest-diffhl'
    n.mkdir_p(dir)
    finally(function()
      n.rmdir(dir)
    end)
    local path = dir .. '/foo.diff'
    write_file(path, table.concat(diff_lines, '\n') .. '\n')
    command('edit ' .. path)
    command('set autoread')
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       {15:local} {25:x} {15:=} {26:1}                                |
      -{15:local} {25:y} {15:=} {26:2}                                |
      +{15:local} {25:y} {15:=} {26:3}                                |
                                                  |
    ]])
    write_file(
      path,
      table.concat({
        'diff --git a/foo.lua b/foo.lua',
        '--- a/foo.lua',
        '+++ b/foo.lua',
        '@@ -1,2 +1,2 @@',
        ' local x = 1',
        '-local y = 2',
        '+local y = 30',
      }, '\n') .. '\n'
    )
    command('checktime')
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       {15:local} {25:x} {15:=} {26:1}                                |
      -{15:local} {25:y} {15:=} {26:2}                                |
      +{15:local} {25:y} {15:=} {26:30}                               |
                                                  |
    ]])
  end)

  it('highlights deleted-file hunks via the old path', function()
    local screen = Screen.new(44, 8)
    api.nvim_buf_set_lines(0, 0, -1, false, {
      'diff --git a/foo.lua b/foo.lua',
      'deleted file mode 100644',
      '--- a/foo.lua',
      '+++ /dev/null',
      '@@ -1,2 +0,0 @@',
      '-local x = 1',
      '-local y = 2',
    })
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      deleted file mode 100644                    |
      --- a/foo.lua                               |
      +++ /dev/null                               |
      @@ -1,2 +0,0 @@                             |
      -{15:local} {25:x} {15:=} {26:1}                                |
      -{15:local} {25:y} {15:=} {26:2}                                |
                                                  |
    ]])
  end)

  it('highlights hunks for spaced and quoted (non-ascii) paths', function()
    local screen = Screen.new(44, 8)
    api.nvim_buf_set_lines(0, 0, -1, false, {
      'diff --git a/my file.lua b/my file.lua',
      '--- a/my file.lua',
      '+++ b/my file.lua',
      '@@ -1,1 +1,1 @@',
      '-local y = 2',
      '+local y = 3',
    })
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/my file.lua b/my file.lua      |
      --- a/my file.lua                           |
      +++ b/my file.lua                           |
      @@ -1,1 +1,1 @@                             |
      -{15:local} {25:y} {15:=} {26:2}                                |
      +{15:local} {25:y} {15:=} {26:3}                                |
      {1:~                                           }|
                                                  |
    ]])

    api.nvim_buf_set_lines(0, 0, -1, false, {
      'diff --git "a/\\303\\251.lua" "b/\\303\\251.lua"',
      '--- "a/\\303\\251.lua"',
      '+++ "b/\\303\\251.lua"',
      '@@ -1,1 +1,1 @@',
      '-local y = 2',
      '+local y = 3',
    })
    screen:expect([[
      ^diff --git "a/\303\251.lua" "b/\303\251.lua"|
      --- "a/\303\251.lua"                        |
      +++ "b/\303\251.lua"                        |
      @@ -1,1 +1,1 @@                             |
      -{15:local} {25:y} {15:=} {26:2}                                |
      +{15:local} {25:y} {15:=} {26:3}                                |
      {1:~                                           }|
                                                  |
    ]])
  end)
end)
