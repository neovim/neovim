local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local dedent = helpers.dedent
local eq = helpers.eq
local funcs = helpers.funcs

describe(":autocmd", function()
  before_each(clear)

  it("should not segfault when you just do autocmd", function()
    command ":autocmd"
  end)

  it("should filter based on ++once", function()
    command "autocmd! BufEnter"
    command "autocmd BufEnter * :echo 'Hello'"
    command [[augroup TestingOne]]
    command [[  autocmd BufEnter * :echo "Line 1"]]
    command [[  autocmd BufEnter * :echo "Line 2"]]
    command [[augroup END]]

    eq(dedent([[

       --- Autocommands ---
       BufEnter
           *         :echo 'Hello'
       TestingOne  BufEnter
           *         :echo "Line 1"
                     :echo "Line 2"]]),
       funcs.execute('autocmd BufEnter'))

  end)
end)
