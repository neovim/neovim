local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec_lua = n.exec_lua

describe('extmark perf', function()
  before_each(function()
    clear()

    exec_lua([[
      out = {}
      function start()
        ts = vim.uv.hrtime()
      end
      function stop(name)
        out[#out+1] = ('%14.6f ms - %s'):format((vim.uv.hrtime() - ts) / 1000000, name)
      end
    ]])
  end)

  after_each(function()
    for _, line in ipairs(exec_lua([[return out]])) do
      print(line)
    end
  end)

  it('repeatedly calling nvim_buf_clear_namespace #28615', function()
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'foo', 'bar' })
      local ns0 = vim.api.nvim_create_namespace('ns0')
      local ns1 = vim.api.nvim_create_namespace('ns1')

      for _ = 1, 10000 do
        vim.api.nvim_buf_set_extmark(0, ns0, 0, 0, {})
      end
      vim.api.nvim_buf_set_extmark(0, ns1, 1, 0, {})

      start()
      for _ = 1, 10000 do
        vim.api.nvim_buf_clear_namespace(0, ns1, 0, -1)
      end
      stop('nvim_buf_clear_namespace')
    ]])
  end)

  it('many non-wrapped virtual lines', function()
    local screen = Screen.new(40, 999)
    exec_lua([[
      vim.cmd('1new')
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
      local ns = vim.api.nvim_create_namespace('virt_lines')
      local virt_lines = {}
      for i = 1, 2000 do
        virt_lines[i] = { { 'VIRT_LINE', 'ErrorMsg' } }
      end
      vim.api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_lines = virt_lines })
    ]])

    exec_lua([[
      vim.cmd('resize 995')

      start()
      vim.cmd('redraw')
      stop('redraw with virt lines at the bottom')
    ]])
    screen:expect([[
      ^line1                                   |
      {9:VIRT_LINE}                               |*994
      {3:[No Name] [+]                           }|
                                              |
      {2:[No Name]                               }|
                                              |
    ]])

    n.command('resize 1')
    screen:expect([[
      ^line1                                   |
      {3:[No Name] [+]                           }|
                                              |
      {1:~                                       }|*994
      {2:[No Name]                               }|
                                              |
    ]])

    exec_lua([[
      vim.cmd('resize 995')

      start()
      vim.cmd('normal! j')
      stop('moving cursor down to line 2')

      start()
      vim.cmd('normal! j')
      stop('moving cursor down to line 3')

      start()
      vim.cmd('redraw')
      stop('redraw with virt lines at the top')
    ]])
    screen:expect([[
      {9:VIRT_LINE}                               |*993
      line2                                   |
      ^line3                                   |
      {3:[No Name] [+]                           }|
                                              |
      {2:[No Name]                               }|
                                              |
    ]])

    exec_lua([[
      start()
      vim.cmd('normal! k')
      stop('moving cursor up to line 2')

      start()
      vim.cmd('normal! k')
      stop('moving cursor up to line 1')
    ]])
  end)
end)
