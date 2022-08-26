" vimexpect.vim is a small object-oriented library that simplifies the task of
" scripting communication with jobs or any interactive program. The name
" `expect` comes from the famous tcl extension that has the same purpose.
"
" This library is built upon two simple concepts: Parsers and States.
"
" A State represents a program state and associates a set of regular
" expressions(to parse program output) with method names(to deal with parsed
" output). States are created with the vimexpect#State(patterns) function.
"
" A Parser manages data received from the program. It also manages State
" objects by storing them into a stack, where the top of the stack is the
" current State. Parsers are created with the vimexpect#Parser(initial_state,
" target) function
"
" The State methods are defined by the user, and are always called with `self`
" set as the Parser target. Advanced control flow is achieved by changing the
" current state with the `push`/`pop`/`switch` parser methods.
"
" An example of this library in action can be found in Neovim source
" code(contrib/neovim_gdb subdirectory)

let s:State = {}


" Create a new State instance with a list where each item is a [regexp, name]
" pair. A method named `name` must be defined in the created instance.
function s:State.create(patterns)
  let this = copy(self)
  let this._patterns = a:patterns
  return this
endfunction


let s:Parser = {}
let s:Parser.LINE_BUFFER_MAX_LEN = 100


" Create a new Parser instance with the initial state and a target. The target
" is a dictionary that will be the `self` of every State method call associated
" with the parser, and may contain options normally passed to
" `jobstart`(on_stdout/on_stderr will be overridden). Returns the target so it
" can be called directly as the second argument of `jobstart`:
"
" call jobstart(prog_argv, vimexpect#Parser(initial_state, {'pty': 1}))
function s:Parser.create(initial_state, target)
  let parser = copy(self)
  let parser._line_buffer = []
  let parser._stack = [a:initial_state]
  let parser._target = a:target
  let parser._target.on_stdout = function('s:JobOutput')
  let parser._target.on_stderr = function('s:JobOutput')
  let parser._target._parser = parser
  return parser._target
endfunction


" Push a state to the state stack
function s:Parser.push(state)
  call add(self._stack, a:state)
endfunction


" Pop a state from the state stack. Fails if there's only one state remaining.
function s:Parser.pop()
  if len(self._stack) == 1
    throw 'vimexpect:emptystack:State stack cannot be empty'
  endif
  return remove(self._stack, -1)
endfunction


" Replace the state currently in the top of the stack.
function s:Parser.switch(state)
  let old_state = self._stack[-1]
  let self._stack[-1] = a:state
  return old_state
endfunction


" Append a list of lines to the parser line buffer and try to match it the
" current state. This will shift old lines if the buffer crosses its
" limit(defined by the LINE_BUFFER_MAX_LEN field). During normal operation,
" this function is called by the job handler provided by this module, but it
" may be called directly by the user for other purposes(testing for example)
function s:Parser.feed(lines)
  if empty(a:lines)
    return
  endif
  let lines = a:lines
  let linebuf = self._line_buffer
  if lines[0] != "\n" && !empty(linebuf)
    " continue the previous line
    let linebuf[-1] .= lines[0]
    call remove(lines, 0)
  endif
  " append the newly received lines to the line buffer
  let linebuf += lines
  " keep trying to match handlers while the line isnt empty
  while !empty(linebuf)
    let match_idx = self.parse(linebuf)
    if match_idx == -1
      break
    endif
    let linebuf = linebuf[match_idx + 1 : ]
  endwhile
  " shift excess lines from the buffer
  while len(linebuf) > self.LINE_BUFFER_MAX_LEN
    call remove(linebuf, 0)
  endwhile
  let self._line_buffer = linebuf
endfunction


" Try to match a list of lines with the current state and call the handler if
" the match succeeds. Return the index in `lines` of the first match.
function s:Parser.parse(lines)
  let lines = a:lines
  if empty(lines)
    return -1
  endif
  let state = self.state()
  " search for a match using the list of patterns
  for [pattern, handler] in state._patterns
    let matches = matchlist(lines, pattern)
    if empty(matches)
      continue
    endif
    let match_idx = match(lines, pattern)
    call call(state[handler], matches[1:], self._target)
    return match_idx
  endfor
endfunction


" Return the current state
function s:Parser.state()
  return self._stack[-1]
endfunction


" Job handler that simply forwards lines to the parser.
function! s:JobOutput(_id, lines, _event) dict
  call self._parser.feed(a:lines)
endfunction

function vimexpect#Parser(initial_state, target)
  return s:Parser.create(a:initial_state, a:target)
endfunction


function vimexpect#State(patterns)
  return s:State.create(a:patterns)
endfunction
