local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local clear = n.clear
local Screen = require('test.functional.ui.screen')

before_each(clear)

describe('Scrollbind', function()
  local screen --- @type test.functional.ui.screen

  before_each(function()
    screen = Screen.new(40, 12)
    screen:attach()
  end)

  it('works with one buffer with virtual lines', function()
    n.exec_lua(function()
      local lines = {} --- @type string[]

      for i = 1, 20 do
        lines[i] = tostring(i * 2 - 1)
      end

      local ns = vim.api.nvim_create_namespace('test')

      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.bo.buftype = 'nofile'

      for i in ipairs(lines) do
        vim.api.nvim_buf_set_extmark(0, ns, i - 1, 0, {
          virt_lines = { { { tostring(2 * i) .. ' v' } } },
        })
      end

      vim.wo.scrollbind = true
      vim.cmd.vsplit()
      vim.wo.scrollbind = true
    end)

    n.feed('<C-d>')

    t.eq(5, n.api.nvim_get_option_value('scroll', {}))

    screen:expect({
      grid = [[
        6 v                 │6 v                |
        7                   │7                  |
        8 v                 │8 v                |
        9                   │9                  |
        10 v                │10 v               |
        ^11                  │11                 |
        12 v                │12 v               |
        13                  │13                 |
        14 v                │14 v               |
        15                  │15                 |
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })

    n.feed('<C-u>')

    local line1_grid = [[
      ^1                   │1                  |
      2 v                 │2 v                |
      3                   │3                  |
      4 v                 │4 v                |
      5                   │5                  |
      6 v                 │6 v                |
      7                   │7                  |
      8 v                 │8 v                |
      9                   │9                  |
      10 v                │10 v               |
      {3:[Scratch]            }{2:[Scratch]          }|
                                              |
    ]]

    screen:expect({ grid = line1_grid })

    n.api.nvim_set_option_value('scroll', 6, {})

    n.feed('<C-d>')

    screen:expect({
      grid = [[
        7                   │7                  |
        8 v                 │8 v                |
        9                   │9                  |
        10 v                │10 v               |
        11                  │11                 |
        12 v                │12 v               |
        ^13                  │13                 |
        14 v                │14 v               |
        15                  │15                 |
        16 v                │16 v               |
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })

    n.feed('<C-u>')

    screen:expect({ grid = line1_grid })
  end)

  it('works with two buffers with virtual lines on one side', function()
    n.exec_lua(function()
      local lines = {} --- @type string[]

      for i = 1, 20 do
        lines[i] = tostring(i)
      end

      local ns = vim.api.nvim_create_namespace('test')

      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.bo.buftype = 'nofile'

      vim.wo.scrollbind = true
      vim.cmd.vnew()

      lines = {} --- @type string[]

      for i = 1, 20 do
        lines[i] = tostring(i + (i > 3 and 4 or 0))
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.bo.buftype = 'nofile'

      vim.api.nvim_buf_set_extmark(0, ns, 2, 0, {
        virt_lines = {
          { { '4 v' } },
          { { '5 v' } },
          { { '6 v' } },
          { { '7 v' } },
        },
      })

      vim.wo.scrollbind = true
    end)

    n.feed('<C-d>')

    t.eq(5, n.api.nvim_get_option_value('scroll', {}))

    screen:expect({
      grid = [[
        6 v                 │6                  |
        7 v                 │7                  |
        8                   │8                  |
        9                   │9                  |
        ^10                  │10                 |
        11                  │11                 |
        12                  │12                 |
        13                  │13                 |
        14                  │14                 |
        15                  │15                 |
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })

    n.feed('<C-u>')

    local line1_grid = [[
      ^1                   │1                  |
      2                   │2                  |
      3                   │3                  |
      4 v                 │4                  |
      5 v                 │5                  |
      6 v                 │6                  |
      7 v                 │7                  |
      8                   │8                  |
      9                   │9                  |
      10                  │10                 |
      {3:[Scratch]            }{2:[Scratch]          }|
                                              |
    ]]

    screen:expect({ grid = line1_grid })

    n.api.nvim_set_option_value('scroll', 6, {})

    n.feed('<C-d>')

    screen:expect({
      grid = [[
        7 v                 │7                  |
        8                   │8                  |
        9                   │9                  |
        10                  │10                 |
        ^11                  │11                 |
        12                  │12                 |
        13                  │13                 |
        14                  │14                 |
        15                  │15                 |
        16                  │16                 |
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })

    n.feed('<C-u>')

    screen:expect({ grid = line1_grid })

    -- Note: not the same as n.feed('4<C-e>')
    n.feed('<C-e>')
    n.feed('<C-e>')
    n.feed('<C-e>')
    n.feed('<C-e>')

    screen:expect({
      grid = [[
        5 v                 │5                  |
        6 v                 │6                  |
        7 v                 │7                  |
        ^8                   │8                  |
        9                   │9                  |
        10                  │10                 |
        11                  │11                 |
        12                  │12                 |
        13                  │13                 |
        14                  │14                 |
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })

    n.feed('<C-e>')

    screen:expect({
      grid = [[
        6 v                 │6                  |
        7 v                 │7                  |
        ^8                   │8                  |
        9                   │9                  |
        10                  │10                 |
        11                  │11                 |
        12                  │12                 |
        13                  │13                 |
        14                  │14                 |
        15                  │15                 |
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })

    n.feed('<C-y>')
    n.feed('<C-y>')

    screen:expect({
      grid = [[
        4 v                 │4                  |
        5 v                 │5                  |
        6 v                 │6                  |
        7 v                 │7                  |
        ^8                   │8                  |
        9                   │9                  |
        10                  │10                 |
        11                  │11                 |
        12                  │12                 |
        13                  │13                 |
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })
  end)

  it('works with buffers of different lengths', function()
    n.exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { '1', '2', '3' })
      vim.bo.buftype = 'nofile'

      vim.wo.scrollbind = true
      vim.cmd.vnew()

      local lines = {} --- @type string[]

      for i = 1, 50 do
        lines[i] = tostring(i)
      end

      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.bo.buftype = 'nofile'
      vim.wo.scrollbind = true
    end)

    n.feed('10<C-e>')

    screen:expect({
      grid = [[
        ^11                  │3                  |
        12                  │{1:~                  }|
        13                  │{1:~                  }|
        14                  │{1:~                  }|
        15                  │{1:~                  }|
        16                  │{1:~                  }|
        17                  │{1:~                  }|
        18                  │{1:~                  }|
        19                  │{1:~                  }|
        20                  │{1:~                  }|
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })

    n.feed('<C-y>')

    screen:expect({
      grid = [[
        10                  │3                  |
        ^11                  │{1:~                  }|
        12                  │{1:~                  }|
        13                  │{1:~                  }|
        14                  │{1:~                  }|
        15                  │{1:~                  }|
        16                  │{1:~                  }|
        17                  │{1:~                  }|
        18                  │{1:~                  }|
        19                  │{1:~                  }|
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })
  end)

  it('works with buffers of different lengths and virtual lines', function()
    n.exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { '1', '5', '6' })

      local ns = vim.api.nvim_create_namespace('test')
      vim.api.nvim_buf_set_extmark(0, ns, 0, 0, {
        virt_lines = {
          { { '2 v' } },
          { { '3 v' } },
          { { '4 v' } },
        },
      })

      vim.bo.buftype = 'nofile'

      vim.wo.scrollbind = true
      vim.cmd.vnew()

      local lines = {} --- @type string[]

      for i = 1, 50 do
        lines[i] = tostring(i)
      end

      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.bo.buftype = 'nofile'
      vim.wo.scrollbind = true
    end)

    n.feed('<C-e>')
    n.feed('<C-e>')
    screen:expect({
      grid = [[
        ^3                   │3 v                |
        4                   │4 v                |
        5                   │5                  |
        6                   │6                  |
        7                   │{1:~                  }|
        8                   │{1:~                  }|
        9                   │{1:~                  }|
        10                  │{1:~                  }|
        11                  │{1:~                  }|
        12                  │{1:~                  }|
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })

    n.feed('8<C-e>')

    screen:expect({
      grid = [[
        ^11                  │6                  |
        12                  │{1:~                  }|
        13                  │{1:~                  }|
        14                  │{1:~                  }|
        15                  │{1:~                  }|
        16                  │{1:~                  }|
        17                  │{1:~                  }|
        18                  │{1:~                  }|
        19                  │{1:~                  }|
        20                  │{1:~                  }|
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })

    n.feed('<C-y>')
    n.feed('<C-y>')
    n.feed('<C-y>')
    n.feed('<C-y>')
    n.feed('<C-y>')

    t.eq(n.exec_lua [[return vim.fn.line('w0', 1001)]], 6)
    t.eq(n.exec_lua [[return vim.fn.line('w0', 1000)]], 3)

    screen:expect({
      grid = [[
        6                   │6                  |
        7                   │{1:~                  }|
        8                   │{1:~                  }|
        9                   │{1:~                  }|
        10                  │{1:~                  }|
        ^11                  │{1:~                  }|
        12                  │{1:~                  }|
        13                  │{1:~                  }|
        14                  │{1:~                  }|
        15                  │{1:~                  }|
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })

    n.feed('<C-y>')
    n.feed('<C-y>')
    n.feed('<C-y>')

    screen:expect({
      grid = [[
        3                   │3 v                |
        4                   │4 v                |
        5                   │5                  |
        6                   │6                  |
        7                   │{1:~                  }|
        8                   │{1:~                  }|
        9                   │{1:~                  }|
        10                  │{1:~                  }|
        ^11                  │{1:~                  }|
        12                  │{1:~                  }|
        {3:[Scratch]            }{2:[Scratch]          }|
                                                |
      ]],
    })
  end)
end)
