local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua

local function tcall(f, ...)
  local start = vim.loop.hrtime()
  local stats = f(...)
  local d = vim.loop.hrtime() - start
  return d / 1000000, stats
end

describe('treesitter perf', function()

  setup(function()
    clear()
  end)

  it('can handle large folds', function()
    helpers.command'edit ./src/nvim/eval.c'
    exec_lua[[
      local parser = vim.treesitter.get_parser(0, "c", {})
      vim.treesitter.highlighter.new(parser)

      local function keys(k)
        vim.api.nvim_feedkeys(k, 't', true)
      end

      vim.opt.foldmethod = "manual"
      vim.opt.lazyredraw = false

      vim.cmd '1000,7000fold'
      vim.cmd '999'

      local function mk_keys(n)
        local acc = ""
        for _ = 1, n do
          acc = acc .. "j"
        end
        for _ = 1, n do
          acc = acc .. "k"
        end

        return "qq" .. acc .. "q"
      end

      local start = vim.loop.hrtime()
      keys(mk_keys(10))

      for _ = 1, 100 do
        keys "@q"
        vim.cmd'redraw!'
      end

      return vim.loop.hrtime() - start
    ]]

  end)

  it ('can handle a stupidly large C file', function()
    local filename = 'dcn_3_2_0_sh_mask.h'
    local file_url = 'https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/include/asic_reg/dcn/dcn_3_2_0_sh_mask.h'
    if not vim.loop.fs_stat(filename) then
      helpers.repeated_read_cmd('wget', file_url)
    end

    local query = [[
      ((preproc_arg) @injection.content
       (#set! injection.language "c"))
    ]]

    helpers.command('edit '..filename)

    print('Times:')
    print('Without injections:')

    local function step(what, t)
      local t2, stats = tcall(exec_lua, [[
        parser:parse()
        return parser:_get_stats()
      ]])

      print('\t- ' .. what .. ':')
      print(string.format('\t  - total : %8.2fms', t + t2))
      for k, s in pairs(stats) do
        print(string.format('\t  - %s:', k))
        for lang, v in pairs(s) do
          if type(v) == 'number' and helpers.endswith(k, '_time') then
            print(string.format('\t    - %-8s : %8.2fms', lang, v))
          else
            print(string.format('\t    - %-8s : %s', lang, vim.inspect(v)))
          end
        end
      end
    end

    step('Initial parse', tcall(exec_lua, [[
      vim.treesitter.query.set('c', 'injections', '')
      parser = vim.treesitter._create_parser(0, 'c')
    ]]))

    step('Edit (modify comment)', tcall(exec_lua, [[
      vim.cmd('normal gg3jx')
    ]]))

    step('Edit (delete line)', tcall(exec_lua, [[
      vim.cmd('28d')
    ]]))

    step('Edit (undo)', tcall(exec_lua, [[
      vim.cmd('u')
    ]]))

    print('With injections:')

    step('Initial parse', tcall(exec_lua, [[
      vim.treesitter.query.set('c', 'injections', ...)
      parser = vim.treesitter._create_parser(0, 'c')
    ]], query))

    step('Edit (modify commment)', tcall(exec_lua, [[
      vim.cmd('normal gg3jx')
     return parser:_get_stats()
    ]]))

    step('Edit (delete line)', tcall(exec_lua, [[
      vim.cmd('28d')
    ]]))

    step('Edit (undo)', tcall(exec_lua, [[
      vim.cmd('u')
    ]]))

  end)

end)
