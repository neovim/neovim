local mpack = require('mpack')

local nvimdir = arg[1]
package.path = nvimdir .. '/?.lua;' .. package.path

assert(#arg == 8)
local input = io.open(arg[2], 'rb')
local proto_output = io.open(arg[3], 'wb')
local call_output = io.open(arg[4], 'wb')
local remote_output = io.open(arg[5], 'wb')
local bridge_output = io.open(arg[6], 'wb')
local metadata_output = io.open(arg[7], 'wb')
local client_output = io.open(arg[8], 'wb')

local c_grammar = require('generators.c_grammar')
local events = c_grammar.grammar:match(input:read('*all'))

local function write_signature(output, ev, prefix, notype)
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

local function write_arglist(output, ev, need_copy)
  output:write('  Array args = ARRAY_DICT_INIT;\n')
  for j = 1, #ev.parameters do
    local param = ev.parameters[j]
    local kind = string.upper(param[1])
    local do_copy = need_copy and (kind == "ARRAY" or kind == "DICTIONARY" or kind == "STRING" or kind == "OBJECT")
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

local function call_ui_event_method(output, ev)
  output:write('void ui_client_event_'..ev.name..'(Array args)\n{\n')

  local hlattrs_args_count = 0
  if #ev.parameters > 0 then
    output:write('  if (args.size < '..(#ev.parameters))
    for j = 1, #ev.parameters do
      local kind = ev.parameters[j][1]
      if kind ~= "Object" then
        if kind == 'HlAttrs' then kind = 'Dictionary' end
        output:write('\n      || args.items['..(j-1)..'].type != kObjectType'..kind..'')
      end
    end
    output:write(') {\n')
    output:write('    ELOG("Error handling ui event \''..ev.name..'\'");\n')
    output:write('    return;\n')
    output:write('  }\n')
  end

  for j = 1, #ev.parameters do
    local param = ev.parameters[j]
    local kind = param[1]
    output:write('  '..kind..' arg_'..j..' = ')
    if kind == 'HlAttrs' then
      -- The first HlAttrs argument is rgb_attrs and second is cterm_attrs
      output:write('ui_client_dict2hlattrs(args.items['..(j-1)..'].data.dictionary, '..(hlattrs_args_count == 0 and 'true' or 'false')..');\n')
      hlattrs_args_count = hlattrs_args_count + 1
    elseif kind == 'Object' then
      output:write('args.items['..(j-1)..'];\n')
    else
      output:write('args.items['..(j-1)..'].data.'..string.lower(kind)..';\n')
    end
  end

  output:write('  ui_call_'..ev.name..'(')
  for j = 1, #ev.parameters do
    output:write('arg_'..j)
    if j ~= #ev.parameters then
      output:write(', ')
    end
  end
  output:write(');\n')

  output:write('}\n\n')
end

for i = 1, #events do
  local ev = events[i]
  assert(ev.return_type == 'void')

  if ev.since == nil and not ev.noexport then
    print("Ui event "..ev.name.." lacks since field.\n")
    os.exit(1)
  end
  ev.since = tonumber(ev.since)

  if not ev.remote_only then
    proto_output:write('  void (*'..ev.name..')')
    write_signature(proto_output, ev, 'UI *ui')
    proto_output:write(';\n')

    if not ev.remote_impl and not ev.noexport then
      remote_output:write('static void remote_ui_'..ev.name)
      write_signature(remote_output, ev, 'UI *ui')
      remote_output:write('\n{\n')
      write_arglist(remote_output, ev, true)
      remote_output:write('  push_call(ui, "'..ev.name..'", args);\n')
      remote_output:write('}\n\n')
    end

    if not ev.bridge_impl and not ev.noexport then
      local send, argv, recv, recv_argv, recv_cleanup = '', '', '', '', ''
      local argc = 1
      for j = 1, #ev.parameters do
        local param = ev.parameters[j]
        local copy = 'copy_'..param[2]
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
          send = send..'  Array '..copy..' = copy_array('..param[2]..');\n'
          argv = argv..', '..copy..'.items, INT2PTR('..copy..'.size)'
          recv = (recv..'  Array '..param[2]..
                          ' = (Array){.items = argv['..argc..'],'..
                          '.size = (size_t)argv['..(argc+1)..']};\n')
          recv_argv = recv_argv..', '..param[2]
          recv_cleanup = recv_cleanup..'  api_free_array('..param[2]..');\n'
          argc = argc+2
        elseif param[1] == 'Object' then
          send = send..'  Object *'..copy..' = xmalloc(sizeof(Object));\n'
          send = send..'  *'..copy..' = copy_object('..param[2]..');\n'
          argv = argv..', '..copy
          recv = recv..'  Object '..param[2]..' = *(Object *)argv['..argc..'];\n'
          recv_argv = recv_argv..', '..param[2]
          recv_cleanup = (recv_cleanup..'  api_free_object('..param[2]..');\n'..
                          '  xfree(argv['..argc..']);\n')
          argc = argc+1
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
      bridge_output:write('  UI_BRIDGE_CALL(ui, '..ev.name..', '..argc..', ui'..argv..');\n}\n\n')
    end
  end

  if not (ev.remote_only and ev.remote_impl) then
    call_output:write('void ui_call_'..ev.name)
    write_signature(call_output, ev, '')
    call_output:write('\n{\n')
    if ev.remote_only then
      write_arglist(call_output, ev, false)
      call_output:write('  UI_LOG('..ev.name..');\n')
      call_output:write('  ui_event("'..ev.name..'", args);\n')
    elseif ev.compositor_impl then
      call_output:write('  UI_CALL')
      write_signature(call_output, ev, '!ui->composed, '..ev.name..', ui', true)
      call_output:write(";\n")
    else
      call_output:write('  UI_CALL')
      write_signature(call_output, ev, 'true, '..ev.name..', ui', true)
      call_output:write(";\n")
    end
    call_output:write("}\n\n")
  end

  if ev.compositor_impl then
    call_output:write('void ui_composed_call_'..ev.name)
    write_signature(call_output, ev, '')
    call_output:write('\n{\n')
    call_output:write('  UI_CALL')
    write_signature(call_output, ev, 'ui->composed, '..ev.name..', ui', true)
    call_output:write(";\n")
    call_output:write("}\n\n")
  end

  if (not ev.remote_only) and (not ev.noexport) and (not ev.client_impl) then
    call_ui_event_method(client_output, ev)
  end
end

-- Generate the map_init method for client handlers
client_output:write([[
void ui_client_methods_table_init(void)
{

]])

for i = 1, #events do
  local fn = events[i]
  if (not fn.noexport) and ((not fn.remote_only) or fn.client_impl) then
    client_output:write('  add_ui_client_event_handler('..
                '(String) {.data = "'..fn.name..'", '..
                '.size = sizeof("'..fn.name..'") - 1}, '..
                '(UIClientHandler) ui_client_event_'..fn.name..');\n')
  end
end

client_output:write('\n}\n\n')

proto_output:close()
call_output:close()
remote_output:close()
client_output:close()

-- don't expose internal attributes like "impl_name" in public metadata
local exported_attributes = {'name', 'parameters',
                       'since', 'deprecated_since'}
local exported_events = {}
for _,ev in ipairs(events) do
  local ev_exported = {}
  for _,attr in ipairs(exported_attributes) do
    ev_exported[attr] = ev[attr]
  end
  for _,p in ipairs(ev_exported.parameters) do
    if p[1] == 'HlAttrs' then
      p[1] = 'Dictionary'
    end
  end
  if not ev.noexport then
    exported_events[#exported_events+1] = ev_exported
  end
end

local packed = mpack.pack(exported_events)
local dump_bin_array = require("generators.dump_bin_array")
dump_bin_array(metadata_output, 'ui_events_metadata', packed)
metadata_output:close()
