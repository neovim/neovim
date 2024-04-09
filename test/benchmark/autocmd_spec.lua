local t = require('test.functional.testutil')()

local clear = t.clear
local exec_lua = t.exec_lua

local N = 7500

describe('autocmd perf', function()
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

  it('nvim_create_autocmd, nvim_del_autocmd (same pattern)', function()
    exec_lua(
      [[
      local N = ...
      local ids = {}

      start()
        for i = 1, N do
          ids[i] = vim.api.nvim_create_autocmd('User', {
            pattern = 'Benchmark',
            command = 'eval 0', -- noop
          })
        end
      stop('nvim_create_autocmd')

      start()
        for i = 1, N do
          vim.api.nvim_del_autocmd(ids[i])
        end
      stop('nvim_del_autocmd')
    ]],
      N
    )
  end)

  it('nvim_create_autocmd, nvim_del_autocmd (unique patterns)', function()
    exec_lua(
      [[
      local N = ...
      local ids = {}

      start()
        for i = 1, N do
          ids[i] = vim.api.nvim_create_autocmd('User', {
            pattern = 'Benchmark' .. i,
            command = 'eval 0', -- noop
          })
        end
      stop('nvim_create_autocmd')

      start()
        for i = 1, N do
          vim.api.nvim_del_autocmd(ids[i])
        end
      stop('nvim_del_autocmd')
    ]],
      N
    )
  end)

  it('nvim_create_autocmd + nvim_del_autocmd', function()
    exec_lua(
      [[
      local N = ...

      start()
        for _ = 1, N do
          local id = vim.api.nvim_create_autocmd('User', {
            pattern = 'Benchmark',
            command = 'eval 0', -- noop
          })
          vim.api.nvim_del_autocmd(id)
        end
      stop('nvim_create_autocmd + nvim_del_autocmd')
    ]],
      N
    )
  end)

  it('nvim_exec_autocmds (same pattern)', function()
    exec_lua(
      [[
      local N = ...

      for i = 1, N do
        vim.api.nvim_create_autocmd('User', {
          pattern = 'Benchmark',
          command = 'eval 0', -- noop
        })
      end

      start()
        vim.api.nvim_exec_autocmds('User', { pattern = 'Benchmark', modeline = false })
      stop('nvim_exec_autocmds')
    ]],
      N
    )
  end)

  it('nvim_del_augroup_by_id', function()
    exec_lua(
      [[
      local N = ...
      local group = vim.api.nvim_create_augroup('Benchmark', {})

      for i = 1, N do
        vim.api.nvim_create_autocmd('User', {
          pattern = 'Benchmark',
          command = 'eval 0', -- noop
          group = group,
        })
      end

      start()
        vim.api.nvim_del_augroup_by_id(group)
      stop('nvim_del_augroup_by_id')
    ]],
      N
    )
  end)

  it('nvim_del_augroup_by_name', function()
    exec_lua(
      [[
      local N = ...
      local group = vim.api.nvim_create_augroup('Benchmark', {})

      for i = 1, N do
        vim.api.nvim_create_autocmd('User', {
          pattern = 'Benchmark',
          command = 'eval 0', -- noop
          group = group,
        })
      end

      start()
        vim.api.nvim_del_augroup_by_name('Benchmark')
      stop('nvim_del_augroup_by_id')
    ]],
      N
    )
  end)

  it(':autocmd, :autocmd! (same pattern)', function()
    exec_lua(
      [[
      local N = ...

      start()
        for i = 1, N do
          vim.cmd('autocmd User Benchmark eval 0')
        end
      stop(':autocmd')

      start()
        vim.cmd('autocmd! User Benchmark')
      stop(':autocmd!')
    ]],
      N
    )
  end)

  it(':autocmd, :autocmd! (unique patterns)', function()
    exec_lua(
      [[
      local N = ...

      start()
        for i = 1, N do
          vim.cmd(('autocmd User Benchmark%d eval 0'):format(i))
        end
      stop(':autocmd')

      start()
        vim.cmd('autocmd! User')
      stop(':autocmd!')
    ]],
      N
    )
  end)
end)
