local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua

local big_linux_file_url = 'https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/include/asic_reg/dcn/dcn_3_2_0_sh_mask.h'

describe('treesitter perf', function()
  setup(function()
    clear()
  end)

  it('can handle large folds', function()
    helpers.command 'edit ./src/nvim/eval.c'
    exec_lua [[
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

      local start = vim.uv.hrtime()
      keys(mk_keys(10))

      for _ = 1, 100 do
        keys "@q"
        vim.cmd'redraw!'
      end

      return vim.uv.hrtime() - start
    ]]
  end)

  -- takes around 2 minutes
  it('iter_matches', function()
    local filename = vim.fs.basename(big_linux_file_url)

    if not vim.uv.fs_stat(filename) then
      helpers.repeated_read_cmd('wget', big_linux_file_url)
    end
    helpers.command('edit '..filename)

    --- @param samples integer[]
    --- @param matches integer
    local function compute(samples, matches)
      local sum = 0
      local sumsq = 0
      local min = math.huge
      local max = 0
      local n = #samples
      for i = 1, n  do
        local sample = samples[i]
        sum = sum + sample
        sumsq = sumsq + (sample * sample)
        if sample > max then
          max = sample
        end
        if sample < min then
          min = sample
        end
      end

      local mean = sum / n
      local sqsum = sum * sum
      local std = math.sqrt((sumsq - (sqsum / n)) / (n - 1))

      return string.format('N=%d, matches=%d mean=%f, std=%f, min=%f, max=%f', n, matches/n, mean, std, min, max)
    end

    local result = exec_lua[[
      local tree = vim.treesitter.get_parser(0, 'c', {})
      local query = vim.treesitter.query.get('c', 'highlights')
      tree:parse(true)

      local samples = {} --- @type integer[]
      local matches = 0

      for i = 1, 10 do
        local start = vim.uv.hrtime()

        tree:for_each_tree(function(tstree)
          local root = tstree:root()
          for _ in query:iter_matches(root, 0) do
            matches = matches + 1
          end
        end)

        local elapsed = vim.uv.hrtime() - start
        samples[i] = elapsed / 1000000
      end

      return {samples, matches}
    ]]

    print(compute(result[1], result[2]))
  end)

end)
