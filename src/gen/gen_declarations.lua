local grammar = require('gen.c_grammar').grammar

--- @param fname string
--- @return string?
local function read_file(fname)
  local f = io.open(fname, 'r')
  if not f then
    return
  end
  local contents = f:read('*a')
  f:close()
  return contents
end

--- @param fname string
--- @param contents string[]
local function write_file(fname, contents)
  local contents_s = table.concat(contents, '\n') .. '\n'
  local fcontents = read_file(fname)
  if fcontents == contents_s then
    return
  end
  local f = assert(io.open(fname, 'w'))
  f:write(contents_s)
  f:close()
end

--- @param fname string
--- @param non_static_fname string
--- @return string? non_static
local function add_iwyu_non_static(fname, non_static_fname)
  if fname:find('.*/src/nvim/.*%.c$') then
    -- Add an IWYU pragma comment if the corresponding .h file exists.
    local header_fname = fname:sub(1, -3) .. '.h'
    local header_f = io.open(header_fname, 'r')
    if header_f then
      header_f:close()
      return (header_fname:gsub('.*/src/nvim/', 'nvim/'))
    end
  elseif non_static_fname:find('/include/api/private/dispatch_wrappers%.h%.generated%.h$') then
    return 'nvim/api/private/dispatch.h'
  elseif non_static_fname:find('/include/ui_events_call%.h%.generated%.h$') then
    return 'nvim/ui.h'
  elseif non_static_fname:find('/include/ui_events_client%.h%.generated%.h$') then
    return 'nvim/ui_client.h'
  elseif non_static_fname:find('/include/ui_events_remote%.h%.generated%.h$') then
    return 'nvim/api/ui.h'
  end
end

--- @param d string
local function process_decl(d)
  -- Comments are really handled by preprocessor, so the following is not
  -- needed
  d = d:gsub('/%*.-%*/', '')
  d = d:gsub('//.-\n', '\n')
  d = d:gsub('# .-\n', '')
  d = d:gsub('\n', ' ')
  d = d:gsub('%s+', ' ')
  d = d:gsub(' ?%( ?', '(')
  d = d:gsub(' ?, ?', ', ')
  d = d:gsub(' ?(%*+) ?', ' %1')
  d = d:gsub(' ?(FUNC_ATTR_)', ' %1')
  d = d:gsub(' $', '')
  d = d:gsub('^ ', '')
  return d .. ';'
end

--- @param fname string
--- @param text string
--- @return string[] static
--- @return string[] non_static
--- @return boolean any_static
local function gen_declarations(fname, text)
  local non_static = {} --- @type string[]
  local static = {} --- @type string[]

  local neededfile = fname:match('[^/]+$')
  local curfile = nil
  local any_static = false
  for _, node in ipairs(grammar:match(text)) do
    if node[1] == 'preproc' then
      curfile = node.content:match('^%a* %d+ "[^"]-/?([^"/]+)"') or curfile
    elseif node[1] == 'proto' and curfile == neededfile then
      local node_text = text:sub(node.pos, node.endpos - 1)
      local declaration = process_decl(node_text)

      if node.static then
        if not any_static and declaration:find('FUNC_ATTR_') then
          any_static = true
        end
        static[#static + 1] = declaration
      else
        non_static[#non_static + 1] = 'DLLEXPORT ' .. declaration
      end
    end
  end

  return static, non_static, any_static
end

local usage = [[
Usage:

    gen_declarations.lua definitions.c static.h non-static.h definitions.i

Generates declarations for a C file definitions.c, putting declarations for
static functions into static.h and declarations for non-static functions into
non-static.h. File `definitions.i' should contain an already preprocessed
version of definitions.c and it is the only one which is actually parsed,
definitions.c is needed only to determine functions from which file out of all
functions found in definitions.i are needed and to generate an IWYU comment.
]]

local function main()
  local fname = arg[1]
  local static_fname = arg[2]
  local non_static_fname = arg[3]
  local preproc_fname = arg[4]
  local static_basename = arg[5]

  if fname == '--help' or #arg < 5 then
    print(usage)
    os.exit()
  end

  local text = assert(read_file(preproc_fname))

  local static_decls, non_static_decls, any_static = gen_declarations(fname, text)

  local static = {} --- @type string[]
  if fname:find('.*/src/nvim/.*%.h$') then
    static[#static + 1] = ('// IWYU pragma: private, include "%s"'):format(
      fname:gsub('.*/src/nvim/', 'nvim/')
    )
  end
  vim.list_extend(static, {
    '#define DEFINE_FUNC_ATTRIBUTES',
    '#include "nvim/func_attr.h"',
    '#undef DEFINE_FUNC_ATTRIBUTES',
  })
  vim.list_extend(static, static_decls)
  vim.list_extend(static, {
    '#define DEFINE_EMPTY_ATTRIBUTES',
    '#include "nvim/func_attr.h"  // IWYU pragma: export',
    '',
  })

  write_file(static_fname, static)

  if any_static then
    local orig_text = assert(read_file(fname))
    local pat = '\n#%s?include%s+"' .. static_basename .. '"\n'
    local pat_comment = '\n#%s?include%s+"' .. static_basename .. '"%s*//'
    if not orig_text:find(pat) and not orig_text:find(pat_comment) then
      error(('fail: missing include for %s in %s'):format(static_basename, fname))
    end
  end

  if non_static_fname ~= 'SKIP' then
    local non_static = {} --- @type string[]
    local iwyu_non_static = add_iwyu_non_static(fname, non_static_fname)
    if iwyu_non_static then
      non_static[#non_static + 1] = ('// IWYU pragma: private, include "%s"'):format(
        iwyu_non_static
      )
    end
    vim.list_extend(non_static, {
      '#define DEFINE_FUNC_ATTRIBUTES',
      '#include "nvim/func_attr.h"',
      '#undef DEFINE_FUNC_ATTRIBUTES',
      '#ifndef DLLEXPORT',
      '#  ifdef MSWIN',
      '#    define DLLEXPORT __declspec(dllexport)',
      '#  else',
      '#    define DLLEXPORT',
      '#  endif',
      '#endif',
    })
    vim.list_extend(non_static, non_static_decls)
    non_static[#non_static + 1] = '#include "nvim/func_attr.h"'
    write_file(non_static_fname, non_static)
  end
end

return main()
