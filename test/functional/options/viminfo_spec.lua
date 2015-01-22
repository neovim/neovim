local helpers = require('test.functional.helpers')
local clear, execute, ok = helpers.clear, helpers.execute, helpers.ok

describe('viminfo', function()
  setup(clear)

  it('`n`: uses a different viminfo name', function()
    local viminfo_name = 'nviminfo_foobar'
    execute("set viminfo='100,n"..viminfo_name)

    os.remove(viminfo_name)
    execute('wviminfo!')
    execute("call system('sync')")
    ok(os.remove(viminfo_name))
  end)

  --pending('`!`: saves/restores uppercase variables - migrate test74')
  --pending('`"`: tests max number of lines saved for each register')
  --pending('`<`: tests max number of lines saved for each register')
  --pending('`%`: saves/restores the buffer list')
  --pending("`'`: remembers marks for a maximum number of files")
  --pending('`/`: tests max number of items in the search pattern history')
  --pending('`:`: tests max number of items in the command-line history')
  --pending('`@`: tests max number of items in the input-line history')
  --pending('`c`: converts viminfo file to different encoding')
  --pending('`f`: stores file marks')
  --pending("`h`: disables the effect of 'hlsearch'")
  --pending("`r`: doesn't store marks for removable media")
  --pending('`s`: tests maximum size of an item')
end)
