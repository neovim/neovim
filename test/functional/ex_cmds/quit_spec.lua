local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local nvim = helpers.nvim
local insert = helpers.insert
local command = helpers.command
local expect = helpers.expect

describe(':qa', function()
  before_each(function()
    clear('--cmd', 'qa')
  end)

  it('verify #3334', function()
    -- just testing if 'qa' passed as a program argument wont result in memory
    -- errors
  end)
end)

describe(':q!', function()
  before_each(clear)

  describe('does not unload hidden buffers', function()
    local function check_buf_after(...)
      command('new foo')
      local buf = helpers.call('bufnr', '')
      insert('lorem ipsum')
      for _, v in ipairs({...}) do
        command(v)
      end
      command('split +b' .. buf)
      expect('lorem ipsum')
    end

    it('using bufhidden=hide', function()
      check_buf_after('set bufhidden=hide', 'quit!')
    end)

    it('using :hide', function()
      check_buf_after('hide quit!')
    end)

    it("using 'hidden'", function()
      check_buf_after('set hidden', 'quit!')
    end)
  end)
end)
