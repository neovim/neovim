local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local curbufmeths = helpers.curbufmeths
local eq = helpers.eq
local meths = helpers.meths

describe('get_commands', function()
  local dummy_dict = {dummy=''}
  local cmd_string = 'command Hello echo "Hello World"'
  local cmd_string2 = 'command Pwd pwd'
  local cmd_dict = {
    name='Hello',
    nargs='0',
    script_id=0,
    definition='echo "Hello World"',
  }
  local cmd_dict2 = {
    name='Pwd',
    nargs='0',
    script_id=0,
    definition='pwd',
  }
  before_each(clear)
  it('get empty list of user-def commands if no command is there', function()
    eq({}, meths.get_commands(dummy_dict))
  end)
  it('get the dictionary when we add a user-def command', function()
    -- Insert a command
    command(cmd_string)
    eq({cmd_dict}, meths.get_commands(dummy_dict))
    -- Insert a another command
    command(cmd_string2);
    eq({cmd_dict, cmd_dict2}, meths.get_commands(dummy_dict))
    -- Delete a command
    command('delcommand Pwd')
    eq({cmd_dict}, meths.get_commands(dummy_dict))
  end)
  it('consider different buffers', function()
    -- Insert a command
    command('command -buffer Hello echo "Hello World"')
    eq({cmd_dict}, curbufmeths.get_commands(dummy_dict))
    -- Insert a another command
    command('command -buffer Pwd pwd')
    eq({cmd_dict, cmd_dict2}, curbufmeths.get_commands(dummy_dict))
    -- Delete a command
    command('delcommand Pwd')
    eq({cmd_dict}, curbufmeths.get_commands(dummy_dict))
  end)
  it('get dicts for different attributes of different commands', function()
    local cmd1 = {
      complete='custom',
      nargs='1',
      name='Finger',
      script_id=0,
      complete_arg='ListUsers',
      definition='!finger <args>',
    }
    local cmd2 = {
      complete='dir',
      nargs='0',
      name='TestCmd',
      range='10c',
      addr='arguments',
      script_id=0,
      definition='pwd <args>',
    }
    command('command -complete=custom,ListUsers -nargs=1 Finger !finger <args>')
    eq({cmd1}, meths.get_commands(dummy_dict))
    command('command -complete=dir -addr=arguments -count=10 TestCmd pwd <args>')
    eq({cmd1, cmd2}, meths.get_commands(dummy_dict))
  end)
end)
