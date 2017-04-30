mpack = require('mpack')

local nvimdir = arg[1]
package.path = nvimdir .. '/?.lua;' .. package.path

assert(#arg == 6)
input = io.open(arg[2], 'rb')
proto_output = io.open(arg[3], 'wb')
call_output = io.open(arg[4], 'wb')
remote_output = io.open(arg[5], 'wb')
bridge_output = io.open(arg[6], 'wb')

c_grammar = require('generators.c_grammar')
local events = c_grammar.grammar:match(input:read('*all'))

function write_signature(output, ev, prefix, notype)
  output:write('('..prefix)
  if prefix == "" and #ev.parameters == 0 then
    output:write('void')
  end
  for j = 1, #ev.parameters do
    if j > 1 or prefix ~= '' then
      output:write(', ')
    end
    local param = ev.parameters[j]
    if not notype then
      output:write(param[1]..' ')
    end
    output:write(param[2])
  end
  output:write(')')
end

function write_arglist(output, ev, need_copy)
  output:write('  Array args = ARRAY_DICT_INIT;\n')
  for j = 1, #ev.parameters do
    local param = ev.parameters[j]
    local kind = string.upper(param[1])
    local do_copy = need_copy and (kind == "ARRAY" or kind == "DICTIONARY" or kind == "STRING")
    output:write('  ADD(args, ')
    if do_copy then
      output:write('copy_object(')
    end
    output:write(kind..'_OBJ('..param[2]..')')
    if do_copy then
      output:write(')')
    end
    output:write(');\n')
  end
end

for i = 1, #events do
  ev = events[i]
  assert(ev.return_type == 'void')

  if not ev.remote_only then
    proto_output:write('  void (*'..ev.name..')')
    write_signature(proto_output, ev, 'UI *ui')
    proto_output:write(';\n')

    if not ev.remote_impl then
      remote_output:write('static void remote_ui_'..ev.name)
      write_signature(remote_output, ev, 'UI *ui')
      remote_output:write('\n{\n')
      write_arglist(remote_output, ev, true)
      remote_output:write('  push_call(ui, "'..ev.name..'", args);\n')
      remote_output:write('}\n\n')
    end

    if not ev.bridge_impl then

      send, argv, recv, recv_argv, recv_cleanup = '', '', '', '', ''
      argc = 1
      for j = 1, #ev.parameters do
        local param = ev.parameters[j]
        copy = 'copy_'..param[2]
        if param[1] == 'String' then
          send = send..'  String copy_'..param[2]..' = copy_string('..param[2]..');\n'
          argv = argv..', '..copy..'.data, INT2PTR('..copy..'.size)'
          recv = (recv..'  String '..param[2]..
                          ' = (String){.data = argv['..argc..'],'..
                          '.size = (size_t)argv['..(argc+1)..']};\n')
          recv_argv = recv_argv..', '..param[2]
          recv_cleanup = recv_cleanup..'  api_free_string('..param[2]..');\n'
          argc = argc+2
        elseif param[1] == 'Array' then
          send = send..'  Array copy_'..param[2]..' = copy_array('..param[2]..');\n'
          argv = argv..', '..copy..'.items, INT2PTR('..copy..'.size)'
          recv = (recv..'  Array '..param[2]..
                          ' = (Array){.items = argv['..argc..'],'..
                          '.size = (size_t)argv['..(argc+1)..']};\n')
          recv_argv = recv_argv..', '..param[2]
          recv_cleanup = recv_cleanup..'  api_free_array('..param[2]..');\n'
          argc = argc+2
        elseif param[1] == 'Integer' or param[1] == 'Boolean' then
          argv = argv..', INT2PTR('..param[2]..')'
          recv_argv = recv_argv..', PTR2INT(argv['..argc..'])'
          argc = argc+1
        else
          assert(false)
        end
      end
      bridge_output:write('static void ui_bridge_'..ev.name..
                          '_event(void **argv)\n{\n')
      bridge_output:write('  UI *ui = UI(argv[0]);\n')
      bridge_output:write(recv)
      bridge_output:write('  ui->'..ev.name..'(ui'..recv_argv..');\n')
      bridge_output:write(recv_cleanup)
      bridge_output:write('}\n\n')

      bridge_output:write('static void ui_bridge_'..ev.name)
      write_signature(bridge_output, ev, 'UI *ui')
      bridge_output:write('\n{\n')
      bridge_output:write(send)
      bridge_output:write('  UI_CALL(ui, '..ev.name..', '..argc..', ui'..argv..');\n}\n')
    end
  end

  call_output:write('void ui_call_'..ev.name)
  write_signature(call_output, ev, '')
  call_output:write('\n{\n')
  if ev.remote_only then
    write_arglist(call_output, ev, false)
    call_output:write('  ui_event("'..ev.name..'", args);\n')
  else
    call_output:write('  UI_CALL')
    write_signature(call_output, ev, ev.name, true)
    call_output:write(";\n")
  end
  call_output:write("}\n\n")

end

proto_output:close()
call_output:close()
remote_output:close()
