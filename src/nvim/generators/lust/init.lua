--[[

Given a template, generate a generator.

MIT license. 

--]]

local concat = table.concat
local format = string.format

-- util:
local 
function tree_dump_helper(t, p, strlimit, ignorekeys)
	if type(t) == "table" then
		local terms = { "{" }
		local p1 = p .. "  "
		for k, v in pairs(t) do	
			if not ignorekeys[k] then
				local key
				if type(k) == "number" then
					key = tostring(k)
				else
					key = format("%q", k)
				end
				terms[#terms+1] = format("[%s] = %s,", key, tree_dump_helper(v, p1, strlimit-2, ignorekeys))
			end
		end
		return format("%s\n%s}", concat(terms, "\n"..p1), p)
	elseif type(t) == "number" then
		return tostring(t)
	elseif type(t) == "string" and #t > strlimit then
		return format("%q...", t:sub(1, strlimit))
	else
		return format("%q", t)
	end
end

local 
function tree_dump(t, strlimit, ignorekeys)
	print(tree_dump_helper(t, "", strlimit and strlimit or 80, ignorekeys or {}))
end

local 
function qesc(str)
	local len = str:len()
	if(str:sub(1, 1) == '"' and str:sub(len, len) == '"') then
		local s = str:sub(2, len-1)
		if(s:sub(1, 1) == "\n") then
			s = "\n"..s
		end
		return format("[===[%s]===]", s)
	else
		return str
	end
end

local
function printlines(s, from, to)
	from = from or 0
	to = to or 100000000
	local l = 1
	for w in s:gmatch("(.-)\r?\n") do
		if l >= from and l <= to then print(l, w) end
		l = l + 1
	end
end

local gensym = (function()
	local id = 0
	return function(s)
		id = id + 1
		local pre = s or "v"
		return format("%s%d", pre, id)
	end
end)()

--------------------------------------------------------------------------------
-- Code accumulator (like a rope)
--------------------------------------------------------------------------------

local writer = {}
writer.__index = writer

function writer.create(prefix, indent)
	local s = {
		level = 0,
		prefix = prefix or "",
		indent = indent or "    ",
		stack = {},
	}
	s.current = s
	return setmetatable(s, writer)
end

function writer:write(s)
	self.current[#self.current+1] = s
	return self
end
writer.__call = writer.write

function writer:format(s, ...)
	self.current[#self.current+1] = format(s, ...)
	return self
end

function writer:comment(s, ...)
	self.current[#self.current+1] = "-- " .. format(s, ...)
	return self
end

-- indentation:
function writer:push()
	local w1 = writer.create(self.indent)
	self.current[#self.current+1] = w1
	self.stack[#self.stack+1] = self.current
	self.current = w1
	return self
end
function writer:pop()
	if #self.stack > 0 then
		self.current = self.stack[#self.stack]
		self.stack[#self.stack] = nil
	else
		error("too many pops")
	end
	return self
end

function writer:concat(sep)
	sep = sep or ""
	sep = sep .. self.prefix
	for i = 1, #self do
		local v = self[i]
		if type(v) == "table" then
			if v.concat then
				self[i] = v:concat(sep)
			else
				self[i] = concat(v, sep)
			end
		end
	end
	return self.prefix .. concat(self, sep)
end

--------------------------------------------------------------------------------
-- Template definition grammar
--------------------------------------------------------------------------------

local lpeg = require "lpeg"
local P = lpeg.P
local C = lpeg.C
local Carg = lpeg.Carg
local Cc = lpeg.Cc
local Cg = lpeg.Cg
local Ct = lpeg.Ct
local Cp = lpeg.Cp
local V = lpeg.V

-- utils:
local 
function left_binop(x, pos1, op, y, pos2, ...)
	--print("left_binop", op, x, y, ...)
	return op and left_binop({x, y, rule="binop", op=op, start=pos1, finish=pos2 }, pos1, ...) or x
end

local 
function left_unop(start, op, x, finish, chained, ...)
	if finish then
		if chained then
			x = left_unop(x, finish, chained, ...)
			finish = x.finish
		end
		return { 
			x, 
			rule="unop", 
			op=op, 
			start=start, 
			finish=finish
		} 
	else
		return start
	end
end

local function delimited(patt)
	return patt * C((1-patt)^0) * patt
end

-- basic patterns:

-- numerics:
local digit = lpeg.R("09")
local integer = digit^1
local quoted_integer	= P'"' * C(integer) * P'"'

local newline = lpeg.S"\n\r"

-- optional white space:
local space = lpeg.S" \t"
local _ = space^0

-- pure alphabetic words:
local alpha = lpeg.R"az" + lpeg.R"AZ"
local symbol = alpha * (alpha)^0

local literal = delimited(P"'") + delimited(P'"')

-- typical C-like variable names:
local name = (alpha + P"_") * (alpha + integer + P"_")^0

-- the patten to pick up the global state:
local g = Carg(1)

-- General rule constructors:
local function Rule(patt, name)
	return Ct(
		Cg(Cp(), "start") *
		patt *
		Cg(Cp(), "finish") *
		Cg(Cc(name), "rule")
	)
end

-- constructors for left-recursive operator rules:
-- O is the operator, B is the next pattern to try
function BinRule(O, B)
	-- matches B
	-- matches B op B
	-- matches B op B op B etc.
	return (B * Cp() * (_ * O *_* B * Cp())^0) / left_binop
end

-- O is the operator, B is the next pattern to try
function UnRule(O, B)
	-- matches op B
	-- matches op op B
	-- else matches B
	return (((Cp() * O * _)^1 * B * Cp()) / left_unop) + B
end

-- the grammar:
local grammar = P{

	-- start symbol (grammar entry point):
	Rule(V"firstinsert"^-1 * (V"insert" + V"anything")^0, "main"),
	
	-- anything that isn't an insertion point:
	anything			= Rule(
							C((P(1) - V"insert")^1), 
							"anything"
						),
	
	-- all the insertion points are wrapped in an indentation detector:
	indent 				= Cg(C(space^1), "indent"),
	-- special rule if an insertion appears before an 'anything' rule
	-- because the initial newline anchor is not needed
	-- and the generated code will also omit this newline		
	firstinsert 		= Rule(
							(Cg(Cc"true", "first") * V"indent")^-1 * 
							V"insertbody",
							"insert"
						),
	-- subsequent insertions must be anchored by a newline for indent to work:
	insert 				= Rule(
							(newline * V"indent")^-1 * 
							V"insertbody",
							"insert"
						),
			
	insertbody			= Rule(
							P"@if" * V"cond", 
							"cond"
						)
						+ Rule(
							P"@iter" * V"iter_env" * P":" * V"iter_body", 
							"iter"
						)
						+ Rule(
							P"@" * (C"map" + C"rest" + C"first" + C"last") * 
							(V"env_dict" + V"env") * P":" * V"iter_body", 
							"map"
						)
						+ Rule(
							(
								(P"@<" * V"apply_body" * P">")
								+ (P"@" * V"apply_body")
							), 
							"apply"
						)
						+ Rule(
							(
								(P"$<" * V"index" * P">")
								+ (P"$" * V"index")
							),
							"substitute"
						),
	
	
	-- main applications:
	
	apply_env_nil		= V"path_nil",
	apply_env			= (V"env" * P":")
						+ (V"path" * P":"),
			
						-- dynamic template path:
						-- e.g. a.(b.c).d
	apply_eval_term		= V"eval" 
						+ C(name),
						
	apply_eval_path		= Rule(
							C"#"^-1 * V"apply_eval_term" * (P"." * V"apply_eval_term")^0,
							"apply_eval_path"
						),
					
	apply_body_env		= Rule(V"apply_env" * V"apply_eval_path", "apply_eval")
						+ Rule(V"apply_env" * V"inline", "apply_inline"),
						
	apply_body_no_env	= Rule(V"apply_env_nil" * V"apply_eval_path", "apply_eval") 
						+ Rule(V"apply_env_nil" * V"inline", "apply_inline"),
						
	apply_body			= V"apply_body_env" 
						+ V"apply_body_no_env",
	
	iter_range_term		= Rule(quoted_integer, "quoted")
						+ Rule(V"path", "len"),

	iter_range			= Rule(
							P"[" *_* V"iter_range_term" 
							*_* "," *_* V"iter_range_term" *_* P"]",
							"iter_range"
						)
						+ V"iter_range_term",
	
	iter_env			= Rule(
							P"{" *_* V"iter_range" *_* 
							(P"," *_* V"env_separator")^-1 
							*_* P"}",
							"iter_env"
						),
	
	iter_body			= Rule(V"apply_eval_path", "iter_eval")
						+ Rule(V"inline", "iter_inline"),
												
	
	cond				= P"(" * V"cmp7" * P")<" * V"apply_body_no_env" * P">" 
						* (P"else<" * V"apply_body_no_env" * P">")^-1,
																																							
	-- environment indexing:
	path_term			= V"eval"
						+ C(name) 
						+ (integer / tonumber),
	path_nil			= Rule(
							Cc".",
							"path_nil"
						),
	path_current		= Rule(
							C".",
							"path_current"
						),

	path				= V"path_current"
						+ Rule(
							V"path_term" * (P"." * V"path_term")^0,
							"path"
						),
	
	index				= Rule(P"#" * V"path", "len")
						+ V"path",
	
	-- environments:
	
	env_term_value		= V"apply_body_env"
						+ V"env"
						+ V"env_array"
						+ Rule(literal, "literal")
						+ V"index",
	
	env_separator		= Rule(
							((P"_separator" + P"_") *_* P"=" *_* V"env_term_value"),
							"separator"
						),
	
	env_tuple			= V"env_separator"
						+ Rule(
							C(name) *_* P"=" *_* V"env_term_value", 
							"tuple"
						),
	
	env_term			= V"env_tuple" + V"env_term_value",
	
	env_term_list		= (V"env_term" * (_ * P"," *_* V"env_term")^0 *_* P","^-1),
	
	env_array			= Rule(
							P"[" *_* V"env_term_list" *_* P"]",
							"env_array"
						),
	
	env					= Rule(
							P"{" *_* V"env_term_list" *_* P"}", 
							"env"
						),
							
						-- like env, but only allows tuples:
	env_tuple_list		= (V"env_tuple" * (_ * P"," *_* V"env_tuple")^0 *_* P","^-1),
	env_dict			= Rule(
							P"{" *_* V"env_tuple_list" *_* P"}", 
							"env_dict"
						),
	
	
	-- application bodies:
	
	eval				= P"(" * V"path" * P")",
	
	inline_term			= V"insert" 
						+ Rule(C((P(1) - (P"}}" + V"insert"))^1), "inline_text"),
	inline				= P"{{" 
						* Rule(
							V"inline_term"^0, 
							"inline"
						) 
						* P"}}",
						
	-- conditionals:
	
	cmp0				= Rule(P"?(" *_* V"path" *_* P")", "exists")
						+ Rule(V"eval", "lookup")
						+ Rule(quoted_integer, "quoted") 
						+ Rule(C(literal), "quoted")
						+ V"index",
						
	cmp1				= UnRule(
							C"^",
							V"cmp0"
						),
	cmp2				= Rule(	-- legacy length{x} operator:
							Cg(Cc"#", "op") * P"length{" *_* V"cmp0" *_* P"}",
							"unop"
						) 
						+ UnRule(
							C"not" + C"#" + C"-",
							V"cmp1"
						),
	cmp3				= BinRule(
							C"*" + C"/" + C"%",
							V"cmp2"
						),
	cmp4				= BinRule(
							C"+" + C"-",
							V"cmp3"
						),
	cmp5				= BinRule(
							C"==" + C"~=" + C"!=" + C">=" + C"<=" + C"<" + C">",
							V"cmp4"
						),
	cmp6				= BinRule(
							C"and",
							V"cmp5"
						),
	cmp7				= BinRule(
							C"or",
							V"cmp6"
						),
					
}

--------------------------------------------------------------------------------
-- Generator generator
--------------------------------------------------------------------------------

-- a table to store the semantic actions for the grammar
-- i.e. the routines to generate the code generator code
local action = {}

-- NOTE: the 'self' argument to these actions is not an 'action', but 
-- actually a 'gen' object, as defined below.

-- all actions take two arguments: 
-- @node: the parse tree node to evaluate
-- @out: an array of strings to append to

function action:main(node, out)
	out("local out = {}")
	for i, v in ipairs(node) do
		out( self:dispatch(v, out) )
	end
	out("local result = concat(out)")
	out("return result")
end

function action:anything(node, out)
	return format("out[#out+1] = %q", node[1])
end

function action:insert(node, out)
	local indent = node.indent
	-- write the first line indentation:
	if indent and indent ~= "" then
		-- generate the body:
		out:comment("rule insert (child)")
		out:write("local indented = {}")
		out:write("do"):push()
		out:comment("accumulate locally into indented:")
		out:write("local out = indented")
		-- everything in this dispatch should be indented:
		out:write(self:dispatch(node[1], out))
		out:pop():write("end")
		-- mix sub back into parent:
		out:comment("apply insert indentation:")
		if not node.first then
			out:write("out[#out+1] = newline")
		end
		out:format("out[#out+1] = %q", indent)
		out:format("out[#out+1] = concat(indented):gsub('\\n', %q)", '\n' .. indent)
	else	
		out:write(self:dispatch(node[1], out))
	end
end

function action:path(node, out)
	-- TODO: check if this has already been indexed in this scope
	local name = gensym(env) --"env_"..concat(node, "_")
	
	local env = "env"
	local vname = "''"
	local nterms = #node
	for i = 1, nterms do
		local v = node[i]
		local term
		
		if type(v) == "table" then
			local value = self:dispatch(v, out)
			term = format("%s[%s]", env, value)
			--out:format("print('value', %s, %s)", value, term)
			vname = gensym("env")
		else
			if type(v) == "number" then
				term = format("%s[%d]", env, v)
			elseif type(v) == "string" then
				term = format("%s[%q]", env, v)
			else
				error("bad path")
			end
			vname = format("%s_%s", env, v)
			
		end
		
		out:format("local %s = (type(%s) == 'table') and %s or nil", vname, env, term)
		env = vname
	end
	
	return vname
end

function action:separator(node, out)
	return node[1]
end

function action:len(node, out)
	local path = self:dispatch(node[1], out)
	
	return format("len(%s)", path)
end

function action:path_current(node, out)
	return "env"
end

function action:path_nil(node, out)
	return action.path_current(self, node, out)
end

function action:substitute(node, out)
	local content = assert(node[1])
	local text = self:dispatch(content, out)
	return format("out[#out+1] = %s", text)
end

function action:apply(node, out)
	local text = self:dispatch(node[1], out)
	if text then
		return format("out[#out+1] = %s", text)
	end
end

function action:loop_helper(body, out, it, start, len, terms, mt, sep, parent)
	local insep = sep
	
	-- start loop:
	out:format("for %s = %s, %s do", it, start, len)	
		:push()
	
	-- the dynamic env:
	out("local env = setmetatable({")
		:push()
		:format("i1 = %s,", it)
		:format("i0 = %s - 1,", it)
	if terms then
		for i, v in ipairs(terms) do
			-- TODO: only index if type is table!
			out(v)
		end
	end
	out:pop()
		:format("}, %s)", mt)
	
	if parent then
		out:format([[if(type(parent[%s]) == "table") then]], it)
			:push()
				:format("for k, v in pairs(parent[%s]) do", it)
				:push()
				:write("env[k] = v")
				:pop()
				:write("end")
			:pop()
		:write("else")
			:push()
				:format("env[1] = parent[%s]", it)
			:pop()
			:write("end")
	end
	
	-- the body:
	local result = self:dispatch(body, out)
	out:format("out[#out+1] = %s", result)
	
	-- the separator:
	if insep then 
		out:comment("separator:")
		out:format("if %s < %s then", it, len)
			:push()
			:format("out[#out+1] = %s", qesc(insep))
			:pop()
			:write("end")
	end
	
	-- end of loop:
	out:pop()
		:write("end")
	return ""
end

function action:iter(node, out)
	
	local env, body = node[1], node[2]
	local sep
	local start = "1"
	local len
	
	assert(env.rule == "iter_env", "malformed iter env")
	local range = assert(env[1], "missing iter range")
	local v = env[2] -- optional
	if v then
		assert(v.rule == "separator", "second @iter term must be a separator")
		sep = self:dispatch(v[1], out)
	end
	
	--out:comment("range " .. range.rule)
	if range.rule == "iter_range" then
		-- explicit range
		if #range > 1 then
			start = gensym("s")
			out:format("local %s = %s", start, self:dispatch(range[1], out))
			
			len = gensym("len")
			out:format("local %s = %s", len, self:dispatch(range[2], out))
		else
			len = gensym("len")
			out:format("local %s = %s", len, self:dispatch(range[1], out))
		end
	else
		len = gensym("len")
		out:format("local %s = %s", len, self:dispatch(range, out))
	end
	
	local it = gensym("it")
	-- an environment to inherit:
	local mt = gensym("mt")
	out:format("local %s = { __index=env }", mt)
	return action.loop_helper(self, body, out, it, start, len, terms, mt, sep)
end

function action:map(node, out)
	--tree_dump(node)
	
	local ty, env, body = node[1], node[2], node[3]
	-- loop boundaries:
	local it = gensym("it")
	local start
	local len = gensym("len")
	-- loop separator:
	local sep 
	-- loop environment terms:
	local terms = {}
	local parent
	local idx = 1
	out:comment("%s over %s", ty, env.rule)
	
	-- the environment to inherit:
	local mt
	
	if env.rule == "env_dict" then
		-- tuple-only iterator
		-- each tuple value is indexed during iteration
		
		-- len will be derived according to max length of each item
		-- default zero is needed
		out:format("local %s = 0", len)
		
		for i, v in ipairs(env) do	
			-- detect & lift out separator:
			if v.rule == "separator" then
				sep = self:dispatch(v[1], out)
				break
			end
			
		
			-- parse each item:
			local k, s
			if v.rule == "tuple" then
				k = format("%q", self:dispatch(v[1], out))
				v = v[2]
			else
				k = idx
				idx = idx + 1
			end
			s = self:dispatch(v, out)
			if v.rule == "literal" 
			or v.rule == "len" 
			or v.rule == "apply_template" then
				-- these rules only return strings:
				terms[i] = format("[%s] = %s,", k, s)
			elseif v.rule == "env_array" then
				-- these rules only return arrays:
				terms[i] = format("[%s] = %s[%s] or '',", k, s, it)
				out:format("%s = max(len(%s), %s)", len, s, len)
			else
				-- these rules might be strings or tables, need to index safely:
				local b = gensym("b")
				out:format("local %s = type(%s) == 'table'", b, s)
				out:format("if %s then", b):push()
				out:format("%s = max(len(%s), %s)", len, s, len)
				out:pop()
				out("end")
				
				--out:format("print('loop', '%s', %s)", len, len)
	
				
				terms[i] = format("[%s] = %s and (%s[%s] or '') or %s,", k, b, s, it, s)
			end
		end
		
		-- but meta-environment is always the same:
		mt = gensym("mt")
		out:format("local %s = { __index=env }", mt)
		
	elseif env.rule == "env" then
		-- list iterator
		assert(#env > 0, "missing item to iterate")
		-- only the first array item is iterated
		for i, v in ipairs(env) do	
			if v.rule == "separator" then
				sep = self:dispatch(v[1], out)
				break
			elseif v.rule == "tuple" then
				-- copy evaluted dict items into the env:
				local k = format("%q", self:dispatch(v[1], out))
				local s = self:dispatch(v[2], out)
				
				terms[#terms+1] = format("[%s] = %s,", k, s)
			else
				-- the array portion is copied in element by element:
				local s = self:dispatch(v, out)
				out:format("local parent = %s", s)
					:format("local %s = (type(parent) == 'table') and #parent or 0", len, s, s)
				
				mt = "getmetatable(parent)"
				parent = true
			end
		end
	else
		error("malformed map env")
	end
	
	if ty == "rest" then
		start = "2"
	elseif ty == "first" then
		start = "1"
		len = string.format("math.min(1, %s)", len)
	elseif ty == "last" then
		start = len
	else -- map
		start = "1"
	end
	
	return action.loop_helper(self, body, out, it, start, len, terms, mt, sep, parent)
end

function action:apply_helper(tmp, env, out)
	out:comment("apply helper")
	local name = gensym("apply")
	out:format("local %s = ''", name)
	out:format("if %s then", tmp)
		:push()
	out:format("%s = %s(%s)", name, tmp, env)
	out:pop()
		:write("end")
	return name
end

function action:apply_template(node, out)
	local env = self:dispatch(node[1], out)
	return action.apply_template_helper(self, node[2], env, out)
end
function action:iter_template(node, out)
	return action.apply_template_helper(self, node[1], "env", out)
end

function action:lookup_helper(rule, out)
	local ctx = self.ctx
	local ctxlen = #ctx
	
	-- construct the candidate rules:
	local candidates = {}
	for i = ctxlen, 1, -1 do
		candidates[#candidates+1] = format("rules[%q .. %s]", concat(ctx, ".", 1, i) .. ".", rule)
	end
	candidates[#candidates+1] = format("rules[%s]", rule)
	
	local tmp = gensym("tmp")
	out:format("local %s = %s", tmp, concat(candidates, " or "))
	--[==[
	out:format([[if(tem__ == 'unit.self.coordinates.norm') then 
		print("rule", %s)
	end
	]], tmp)
	--]==]
	return tmp
end

function action:lookup(node, out)
	local rule = action.path(self, node[1], out)	
	return action.lookup_helper(self, rule, out)
end



function action:apply_template_helper(body, env, out)
	out:comment("template application:")
	local rule = self:dispatch(body, out)
	return action.apply_helper(self, rule, env, out)
end

-- OK too much special casing here
-- also, #rooted paths are not being handed for the dynamic case
function action:apply_eval_path(node, out)
	local terms = {}
	local sterms = {}
	local isdynamic = false
	local isabsolute = false
	for i, v in ipairs(node) do
		if v == "#" then
			isabsolute = true
		else
			if type(v) ~= "string" then
				-- instead, we could break here and just 
				-- return tailcall to the dynamic method
				isdynamic = true
				local term = self:dispatch(v, out)
				terms[#terms+1] = term
			else
				local term = v
				sterms[#sterms+1] = term
				terms[#terms+1] = format("%q", term)
			end
		end
	end
	
	if isdynamic then
		out:comment("dynamic application")
		
		local evaluated = concat(terms, ", ")
		--out:format([[print("dynamic path", %s)]], evaluated)
		
		local rule = gensym("rule")
		out:format([[local %s = concat({%s}, ".")]], rule, evaluated)
		--[==[
		out:format([[
		 if(tem__ == 'unit.self.coordinates.norm') then 
			print("%s", %s)
		end
		]], rule, rule)
		--]==]
		return action.lookup_helper(self, rule, out)
	else	
		out:comment("static application")
		-- absolute or relative?
		local ctx = self.ctx 
		local ctxlen = #ctx
		local pathname = concat(sterms, ".")
		--print("pathname", pathname)
		
		if isabsolute or ctxlen == 0 then
			-- we are at root level, just use the absolute version:
			return self:reify(pathname)
		end
		
		-- this is the template name we are looking for:
		
		--print("looking for", pathname)
		--print("in context", unpack(self.ctx))
		
		-- we are in a sub-namepsace context
		-- keep trying options by moving up the namespace:
		local ok, rulename
		for i = ctxlen, 1, -1 do
			-- generate a candidate template name
			-- by prepending segments of the current namepace:
			local candidate = format("%s.%s", concat(ctx, ".", 1, i), pathname)
			
			ok, rulename = pcall(self.reify, self, candidate)
			if ok then
				-- found a match, break here:
				return rulename
			end
		end
		
		-- try at the root level:
		local ok, rulename = pcall(self.reify, self, pathname)
		if ok then
			-- found a match!
			return rulename
		end
		
		-- if we got here, we didn't find a match:
		-- should this really be an error, or just return a null template?
		for k, v in pairs(self.definitions) do print("defined", k) end
		
		error(format("could not resolve template %s (%s) in context %s",
			pathname, rulename, concat(ctx, ".")
		))
	end
end

-- env, apply_eval
-- apply_eval e.g. a.(x).c
function action:apply_eval(node, out)
	local env = self:dispatch(node[1], out)
	local tmp = self:dispatch(node[2], out)
	return action.apply_helper(self, tmp, env, out)
end

function action:iter_eval(node, out)
	local env = "env"
	local tmp = self:dispatch(node[1], out)
	return action.apply_helper(self, tmp, env, out)
end

function action:apply_inline_helper(body, env, out)
	local name = gensym("apply")
	out:comment("inline application:")
	out:format("local %s", name)
		:write("--- test")
		:write("do")
		:push()
		:format("local env = %s", env)
		:write("local out = {}")
	local rule = self:dispatch(body, out)
	out:format("%s = concat(out)", name)
		:pop()
		:write("end")
	return name
end

function action:apply_inline(node, out)
	local env = self:dispatch(node[1], out)
	return action.apply_inline_helper(self, node[2], env, out)
end
function action:iter_inline(node, out)
	return action.apply_inline_helper(self, node[1], "env", out)
end

function action:cond(node, out)
	
	local c = self:dispatch(node[1], out)
	--[==[
	if(c == "env_formatted") then
		out:write("local tem__ = (type(env) == 'table') and env.template")
		out:write([[if(tem__ == 'unit.self.coordinates.norm') then 
			print('THIS IS A unit.self.coordinates.norm')
			print("env_formatted", env_formatted)
			print("TEMPLATE:", env["template"])
		end]])
	end
	--]==]
	out:format("if %s then", c):push()
	local t = self:dispatch(node[2], out)
	if t then 
		out:format("out[#out+1] = %s", t)
	end
	out:pop()
	if #node > 2 then
		out("else"):push()
		local f = self:dispatch(node[3], out)
		if f then 
			out:format("out[#out+1] = %s", f)
		end
		out:pop()
	end
	out("end")
end

function action:exists(node, out)
	return action.lookup(self, node, out)
end

function action:quoted(node, out)
	return node[1]
end

function action:unop(node, out)
	local o = node.op
	local b = self:dispatch(node[1], out)
	if o == "?" then 
		return format("(%s ~= nil)", b) 
	elseif o == "#" then 
		return format("len(%s)", b) 
	else
		return format("(%s %s)", o, b)
	end
end

function action:binop(node, out)
	local a = self:dispatch(node[1], out)
	local o = node.op
	local b = self:dispatch(node[2], out)
	return format("(%s %s %s)", a, o, b)
end

function action:tuple(node, out)
	local k = self:dispatch(node[1], out)
	local v = self:dispatch(node[2], out)
	return format("[%q] = %s", k, v)
end

function action:env(node, out)
	local name = gensym("env")
	local terms = {}
	for i, v in ipairs(node) do
		terms[i] = self:dispatch(v, out)
	end
	out:comment("env create { %s } ", concat(terms, ", "))
	out:format("local %s = {", name)
		:push()
	for i, v in ipairs(terms) do
		out(v .. ",")
	end
	out:pop()
		:write("}")
	return name
end
action.iter_env = action.env

function action:inline_text(node, out)
	out:format("out[#out+1] = %q", node[1])
end

function action:inline(node, out)
	for i, v in ipairs(node) do
		out:write( self:dispatch(v, out) )
	end
end

function action:env_array(node, out)
	local terms = {}
	for i, v in ipairs(node) do
		terms[i] = format("[%d] = %s,", i, self:dispatch(v, out))
	end
	
	local name = gensym("array")
	out:format("local %s = {", name)
		:push()
	for i, v in ipairs(terms) do
		out(v)
	end
	out:pop()
		:write("}")
	return name
end

-- because %q also quotes escape sequences, which isn't what we want:
function action:literal(node, out)
	local s = node[1]
	local q
	if s:find('"') then
		q = format('[[%s]]', s)
	else
		q = format('"%s"', s)
	end
	return q
end

--------------------------------------------------------------------------------
-- Template constructor
--------------------------------------------------------------------------------

local header = [[
-- GENERATED CODE: DO NOT EDIT!
local gen = ...
-- utils:
local format, gsub = string.format, string.gsub
local max = math.max
local newline = "\n"
-- need this because table.concat() does not call tostring():
local tconcat = table.concat
local function concat(t, sep)
	local t1 = {}
	for i = 1, #t do t1[i] = tostring(t[i]) end
	return tconcat(t1, sep)
end
-- need this because #s returns string length rather than numeric value:
local function len(t)
	if type(t) == "table" then
		return #t
	else
		return tonumber(t) or 0
	end
end

-- rules: --
local rules = {}
]]

local footer = [[

-- result:
return rules
]]

local gen = {}
gen.__index = gen

-- the main switch to select actions according to parse-tree nodes:
function gen:dispatch(node, out)
	if type(node) == "table" then
		local rule = node.rule
		--print("rule", node.rule)
		if rule and action[rule] then	
			-- invoke the corresponding action:
			out:comment("action %s", rule)
			local result = action[rule](self, node, out)
			return result
		else
			tree_dump(node)
			error("no rule "..tostring(rule))
		end
	elseif type(node) == "string" then
		return node
	else
		error( format("-- unexpected type %s", type(node)) )
	end
end

-- the routine which generates code for a particular template rule name:
function gen:reify(name)
	assert(name, "missing template name")
	
	-- only generate if needed:
	local f = self.functions[name]
	if f then return f end
	
	-- the code from which to generate it:
	local src = self.definitions[name]
	if not src then error("missing definition "..name) end
	
	-- parse it:
	local node = grammar:match(src, 1, self)
	if not node or type(node) ~= "table" then
		error("parse failed for template "..name)
	end
	
	self.ast[name] = node
	
	-- generate it:
	local out = writer.create()
	out:comment("rule %s:", name) 
	
	local rulename = format("rules[%q]", name)
	local localname
	
	-- header:
	if self.numlocals < 200 then
		self.numlocals = self.numlocals + 1
		localname = "template_" .. name:gsub("(%.)", "_")
		out:format("local function %s(env)", localname) 
	else
		out:format("%s = function(env)", rulename)
	end
	out:push()
		
	if self.callbacks[name] then
		out:format("local cb = gen.callbacks[%q]", name)
			:write("if cb then")
			:push()
			:write("env = cb(env)")
			:pop()
			:write("end")
	end
	
	-- push the template namepace context:
	local oldctx = self.ctx
	if type(name) == "string" then 
		local ctx = {}
		for w in name:gmatch("[^.]+") do ctx[#ctx+1] = w end
		self.ctx = ctx
	end
	
	-- generate the function:
	self:dispatch(node, out)
	
	-- restore the previous template namepace context:
	self.ctx = oldctx
	
	-- footer:
	out:pop()
		:write("end")
	
	if localname then
		out:format("rules[%q] = %s", name, localname) 
		-- prevent duplicates:
		self.functions[name] = localname
	else
		-- prevent duplicates:
		self.functions[name] = rulename
	end
	
	-- synthesize result into root accumulator:
	self.out( out:concat("\n") )
	
	return rulename
end

function gen:define(name, t, parent)
	if name == 1 then name = "1" end
	
	if type(t) == "table" then
		assert(t[1], "template table must have an entry at index 1")
		local pre = name
		if parent then
			pre = format("%s.%s", parent, pre)
		end
		for k, v in pairs(t) do
			if k == 1 or k == "1" then
				self:define(name, v, parent)
			else
				self:define(k, v, pre)
			end
		end
	elseif type(t) == "string" then
		if parent then
			local defname = format("%s.%s", parent, name)
			self.definitions[defname] = t
		else
			self.definitions[name] = t
		end
	else
		error("unexpected template type")
	end
end

-- syntactic sugar for template:define(name, code):
-- template[name] = code 
gen.__newindex = gen.define


-- model is optional; if not given, it will reify but not apply
-- rulename is optional; if not given, it will assume rule[1]
function gen:gen(model, rulename)
	rulename = rulename or "1"
	
	-- generate lazily:
	local g = self.rules[rulename]
	if not g then
	
		-- self.out is the top-level accumulator
		-- it is generally used to accumulate the functions
		-- (using rawset here because of gen:__newindex)
		rawset(self, "out", writer.create())
		self.out(header)
		
		-- make sure the main rule is available
		-- this will also generate any templates statically referred by main
		-- in the correct ordering
		
		local main = self:reify("1")
		
		-- now reify all remaining rules
		-- these will be available via dynamic template name evaluation
		for k, v in pairs(self.definitions) do
			self:reify(k)
		end

		-- final: 
		self.out(footer)
			
		local code = self.out:concat("\n")
		-- cache for debugging purposes:
		rawset(self, "code", code)
		
		--printlines(code)
		local f, err = loadstring(code)
		if not f then
			--printlines(code, 1, 100)
			printlines(code, 1, 500)
			print("template internal error", err)
		end
		
		-- merge new rules with existing rules
		local rules = assert( f(self), "construct error" ) 
		for k, v in pairs(rules) do
			self.rules[k] = v
		end
		
		-- now try again:
		g = self.rules[rulename]
		
		if not g then
			printlines(code, 1, 100)
			error(format("template rule %s not defined", rulename))
		end
	end
	
	-- invoke it immediately:
	if model then
		return g(model, "")
	end
end

function gen:register(name, cb)
	self.callbacks[name] = cb
end

-- call this to un-set the generated code, so that it can be regenerated
function gen:reset()
	self.functions = {}
	self.gen = nil
end

function gen:dump(from, to)
	printlines(self.code, from, to)
end

function gen:ast_dump()
	for k, v in pairs(self.ast) do
		print("rule ", k)
		tree_dump(v, nil, { start=true, finish=true })
	end
end	

-- return template constructor
-- optional argument to define the 'start' rule template
return function(startrule)
	local template = setmetatable({
		-- the raw source code from which rules are created:
		definitions = {},
		
		-- the parsed AST thereof:
		ast = {},
		
		-- the synthesized implementation code thereof:
		functions = {},
		
		-- the generated generator functions thereof:
		rules = {},
		
		-- a way to remember the template namespace from which a rule is invoked:
		-- (the call-frame, represented as an array of strings)
		-- the root context is an empty list
		ctx = {},
		
		-- because Lua doesn't allow more then 200 locals in a chunk
		-- here count how many have been generated
		-- (including 10 from the header)
		numlocals = 10,
		
		-- callbacks triggered during code-gen:
		callbacks = {},

	}, gen)
	
	if startrule then
		if type(startrule) == "string" then
			template:define("1", startrule)
		else
			for k, v in pairs(startrule) do
				template:define(k, v)
			end
		end
	end
	
	return template
end
