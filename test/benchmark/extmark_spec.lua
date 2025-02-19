local n = require('test.functional.testnvim')()

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
end)
