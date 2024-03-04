local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq

local parser = require('scripts/cdoc_parser')

--- @param name string
--- @param text string
--- @param exp table<string,string>
local function test(name, text, exp)
  exp = vim.deepcopy(exp, true)
  it(name, function()
    local _, f = parser.parse_str(text)
    eq(exp, f[1])
  end)
end

describe('cdoc parser', function()
  test(
    'works after a preprocessor directive',
    [[
#endif

/// Executes Vimscript
///
/// @param src      Vimscript code
/// @param opts  Optional
///       parameters.
/// @param[out] err Error details (Vim error), if any
/// @return Dictionary containing information
Dictionary nvim_exec2(uint64_t channel_id, String src, Dict(exec_opts) *opts, Error *err)
  FUNC_API_SINCE(11) FUNC_API_RET_ALLOC
{
]],
    {
      name = 'nvim_exec2',
      desc = 'Executes Vimscript\n',
      params = {
        { name = 'src', type = 'String', desc = 'Vimscript code' },
        { name = 'opts', type = 'Dict(exec_opts) *', desc = 'Optional\nparameters.' },
      },
      returns = {
        {
          type = 'Dictionary',
          desc = 'Dictionary containing information',
        },
      },
    }
  )
end)
