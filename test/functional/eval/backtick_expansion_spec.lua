local lfs = require('lfs')
local helpers = require('test.functional.helpers')(after_each)
local clear, command, eval, eq = helpers.clear, helpers.command, helpers.eval, helpers.eq
local write_file = helpers.write_file

describe("backtick expansion", function()
  setup(function()
    clear()
    lfs.mkdir("test-backticks")
    write_file("test-backticks/file1", "test file 1")
    write_file("test-backticks/file2", "test file 2")
    write_file("test-backticks/file3", "test file 3")
    lfs.mkdir("test-backticks/subdir")
    write_file("test-backticks/subdir/file4", "test file 4")
    -- Long path might cause "Press ENTER" prompt; use :silent to avoid it.
    command('silent cd test-backticks')
  end)

  teardown(function()
    helpers.rmdir('test-backticks')
  end)

  it("with default 'shell'", function()
    if helpers.iswin() then
      command(":silent args `dir /b *2`")
    else
      command(":silent args `echo ***2`")
    end
    eq({ "file2", }, eval("argv()"))
    if helpers.iswin() then
      command(":silent args `dir /s/b *4`")
      eq({ "subdir\\file4", }, eval("map(argv(), 'fnamemodify(v:val, \":.\")')"))
    else
      command(":silent args `echo */*4`")
      eq({ "subdir/file4", }, eval("argv()"))
    end
  end)

  it("with shell=fish", function()
    if eval("executable('fish')") == 0 then
      pending('missing "fish" command')
      return
    end
    command("set shell=fish")
    command(":silent args `echo ***2`")
    eq({ "file2", }, eval("argv()"))
    command(":silent args `echo */*4`")
    eq({ "subdir/file4", }, eval("argv()"))
  end)
end)
