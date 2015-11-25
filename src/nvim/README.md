## Source code overview

Since Neovim has inherited most code from Vim, some information in [its
README](https://raw.githubusercontent.com/vim/vim/master/src/README.txt) still
applies.

This document aims to give a high level overview of how Neovim works internally,
focusing on parts that are different from Vim. Currently this is still a work in
progress, especially because I have avoided adding too many details about parts
that are constantly changing. As the code becomes more organized and stable,
this document will be updated to reflect the changes.

If you are looking for module-specific details, it is best to read the source
code. Some files are extensively commented at the top(eg: terminal.c,
screen.c).

### Top-level program loops

First let's understand what a Vim-like program does by analyzing the workflow of
a typical editing session:

01. Vim dispays the welcome screen
02. User types: `:`
03. Vim enters command-line mode
04. User types: `edit README.txt<CR>`
05. Vim opens the file and returns to normal mode
06. User types: `G`
07. Vim navigates to the end of the file
09. User types: `5`
10. Vim enters count-pending mode
11. User types: `d`
12. Vim enters operator-pending mode
13. User types: `w`
14. Vim deletes 5 words
15. User types: `g`
16. Vim enters the "g command mode"
17. User types: `g`
18. Vim goes to the beginning of the file
19. User types: `i`
20. Vim enters insert mode
21. User types: `word<ESC>`
22. Vim inserts "word" at the beginning and returns to normal mode

Note that we have split user actions into sequences of inputs that change the
state of the editor. While there's no documentation about a "g command
mode"(step 16), internally it is implemented similarly to "operator-pending
mode".

From this we can see that Vim has the behavior of a input-driven state
machine(more specifically, a pushdown automaton since it requires a stack for
transitioning back from states). Assuming each state has a callback responsible
for handling keys, this pseudocode(a python-like language) shows a good
representation of the main program loop:

```py
def state_enter(state_callback, data):
  do
    key = readkey()                 # read a key from the user
  while state_callback(data, key)   # invoke the callback for the current state
```

That is, each state is entered by calling `state_enter` and passing a
state-specific callback and data. Here is a high-level pseudocode for a program
that implements something like the workflow described above:

```py
def main()
  state_enter(normal_state, {}):

def normal_state(data, key):
  if key == ':':
    state_enter(command_line_state, {})
  elif key == 'i':
    state_enter(insert_state, {})
  elif key == 'd':
    state_enter(delete_operator_state, {})
  elif key == 'g':
    state_enter(g_command_state, {})
  elif is_number(key):
    state_enter(get_operator_count_state, {'count': key})
  elif key == 'G'
    jump_to_eof()
  return true

def command_line_state(data, key):
  if key == '<cr>':
    if data['input']:
      execute_ex_command(data['input'])
    return false
  elif key == '<esc>'
    return false

  if not data['input']:
    data['input'] = ''

  data['input'] += key
  return true

def delete_operator_state(data, key):
  count = data['count'] or 1
  if key == 'w':
    delete_word(count)
  elif key == '$':
    delete_to_eol(count)
  return false  # return to normal mode

def g_command_state(data, key):
  if key == 'g':
    go_top()
  elif key == 'v':
    reselect()
  return false  # return to normal mode

def get_operator_count_state(data, key):
  if is_number(key):
    data['count'] += key
    return true
  unshift_key(key)  # return key to the input buffer
  state_enter(delete_operator_state, data)
  return false

def insert_state(data, key):
  if key == '<esc>':
    return false  # exit insert mode
  self_insert(key)
  return true
```

While the actual code is much more complicated, the above gives an idea of how
Neovim is organized internally. Some states like the `g_command_state` or
`get_operator_count_state` do not have a dedicated `state_enter` callback, but
are implicitly embedded into other states(this will change later as we continue
the refactoring effort). To start reading the actual code, here's the
recommended order:

1. `state_enter()` function(state.c). This is the actual program loop,
   note that a `VimState` structure is used, which contains function pointers
   for the callback and state data.
2. `main()` function(main.c). After all startup, `normal_enter` is called
   at the end of function to enter normal mode.
3. `normal_enter()` function(normal.c) is a small wrapper for setting
   up the NormalState structure and calling `state_enter`.
4. `normal_check()` function(normal.c) is called before each iteration of
   normal mode.
5. `normal_execute()` function(normal.c) is called when a key is read in normal
   mode.

The basic structure described for normal mode in 3, 4 and 5 is used for other
modes managed by the `state_enter` loop:

- command-line mode: `command_line_{enter,check,execute}()`(`ex_getln.c`)
- insert mode: `insert_{enter,check,execute}()`(`edit.c`)
- terminal mode: `terminal_{enter,execute}()`(`terminal.c`)

### Async event support

One of the features Neovim added is the support for handling arbitrary
asynchronous events, which can include:

- msgpack-rpc requests
- job control callbacks
- timers(not implemented yet but the support code is already there)

Neovim implements this functionality by entering another event loop while
waiting for characters, so instead of:

```py
def state_enter(state_callback, data):
  do
    key = readkey()                 # read a key from the user
  while state_callback(data, key)   # invoke the callback for the current state
```

Neovim program loop is more like:

```py
def state_enter(state_callback, data):
  do
    event = read_next_event()       # read an event from the operating system
  while state_callback(data, event) # invoke the callback for the current state
```

where `event` is something the operating system delivers to us, including(but
not limited to) user input. The `read_next_event()` part is internally
implemented by libuv, the platform layer used by Neovim.

Since Neovim inherited its code from Vim, the states are not prepared to receive
"arbitrary events", so we use a special key to represent those(When a state
receives an "arbitrary event", it normally doesn't do anything other update the
screen).
