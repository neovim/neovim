# Nvim's built-in GUI (`nvim --gui`)

biscide: Nvim as a graph IDE for Go and Rust. One declaration in the middle,
its file's parts stacked around it, what uses it on the left, what it uses
on the right, the one you came from at the far left. Every card is a Nvim
window on the real file's buffer, kept to its part (|nvim_win_set_range()|):
a declaration with its doc comment, the package clause, the imports, a
comment. The language server sees the whole file; `:w` is an ordinary write.

```sh
make CMAKE_EXTRA_FLAGS="-DENABLE_GUI=ON"      # or: cmake -B build -D ENABLE_GUI=ON
VIMRUNTIME=runtime build/bin/nvim --gui [DIR | FILE]
```

Qt 6 (Widgets, Svg). Without `ENABLE_GUI`, `--gui` says Nvim was built
without it.

## How it is built

It is one process: the editor on Nvim's main thread, Qt on a thread of its
own.

- **A UI in the process** (`gui.c`). `--gui` (main.c) attaches a `RemoteUI`
  with `gui` set, `ext_linegrid`, `ext_multigrid`, and `ext_messages`,
  `ext_cmdline`, `ext_popupmenu` (the GUI shows messages, the command line
  and the popup menu itself), where a remote UI would wait to attach. Its
  events are not packed for a channel: api/ui.c hands them over as Nvim's
  own values (`push_call` → `gui_ui_call`), the lines as Nvim's cells
  (`raw_line` → `gui_ui_raw_line`), and `flush`.
- **The bridge** (`bridge.h`): plain C, so the C++ side never includes
  Nvim's headers. `guiq_*`: Nvim → GUI, on the editor's thread; the GUI
  copies what it is given. `gui_*`: GUI → Nvim, from any thread; keys and
  the mouse are fast events on the main loop, Lua and Ex commands deferred
  ones (as an RPC request would be).
- **The GUI** (`qt/`, a C++ library linked into `nvim`). Events gather in a
  batch; at `flush` the batch goes to the GUI's thread, which keeps the
  screen (`screen.*`: a grid per window; `messages.*`: the messages, the
  command line, the popup menu) and shows it. `window.*` lays out the
  widgets:
  - `tree_panel.*`: the project's files, drawn from biscide.tree's rows.
  - `canvas.*`: the cards. `stage.*` decides where they lie and how they
    move; `camera.*` is a state machine that frames the lanes or follows
    the card cursor; `card_painter.*` paints a card (its bars and its
    window's grid) and the curves; `overlays.*` adds the history and the
    colour key.
  - `messages_panel.*`: every message, with its kind and time, floating
    over the canvas's right.
  - `status_bar.*`: the mode, the command line or the last message, and
    the panel's switch.
  - Over the canvas, `picker_panel.*` draws biscide.picker's list. Its prompt
    and preview are Nvim windows.
  - `popups.*`: prompts' questions, the command line's block, the popup
    menu.

  Every key goes to the editor.
- **biscide's runtime** (`runtime/lua/biscide/`, loaded when `vim.g.biscide` is
  set, which `--gui` does), each module one thing:
  - `state`: the state in one place, as Nvim keeps curbuf/curwin.
  - `cards`: cards as structs with handles in a registry, as windows.
  - `narrow`: a card kept to its part.
  - `history`: a jumplist.
  - `lanes`: worked out from the graph, no side effects.
  - `view`: the presenter. It lays the windows out, marks the linked
    names, and tells the GUI with `vim._gui_send`.
  - `navigate` and `program`: the actions.
  - `keymaps`: the GUI's keymaps.
  - `commands`: a table.
  - `graph` and `outline`: the program read with `vim.treesitter`.
  - `tree`: the files' model; its keys are a buffer's.
  - `picker`: a picker. That is a source, a prompt, fuzzy matching
    (|matchfuzzypos()|) and a preview.
  - `pickers`: the pickers.
  - `ui`: `vim.ui.select`, `vim.ui.input` and `vim.notify`, shown by the
    GUI. It also turns noice.nvim off.
  - `missing` and `templates`: names that are nowhere, and what new
    declarations start from.
  - `init`: the facade.
- **Parsers**: the Go and Rust grammars (`grammars/`, MIT) are built into
  `lib/nvim/parser` beside the bundled ones; their highlight queries are in
  `runtime/biscide/grammars/`.

## Using it

The user's manual is `:help biscide` (`runtime/doc/biscide.txt`): configuring
it, its keys, the file tree, the messages, the pickers, writing code, the Lua
API. In short:

The keys are Nvim's, and the configuration is your own (`~/.config/nvim`,
or `NVIM_APPNAME`). biscide's keys are **GUI keymaps**, a mapping layer of
Nvim's own (|nvim_gui_set_keymap()|, `vim.keymap.set(…, { gui = true })`).
They are looked up first, before the current buffer's mappings and the
global ones, so they work in every buffer. A key with nothing to do where
it is pressed is handed on to the buffer's own map of it, else to Nvim: for
example `<CR>` in the tree, or in a buffer of yours that maps `<CR>`. A GUI
keymap you set in init.lua keeps its keys, and `vim.g.biscide_no_maps` sets
none.

biscide's keys:

| Keys | What they do |
|---|---|
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | Move the card cursor |
| `gU` `gR` | Move the card cursor to what it uses / what uses it |
| `<CR>` | Go to the card cursor's card; in a card that is not the active one, make it the active one |
| `<Esc>` | Drop the card cursor |
| `<A-Left>` `<A-Right>` | Walk the history |
| `<leader>e`, `<A-1>` | The files |
| `<leader>m`, `<A-2>` | The messages |
| `<leader>/`, `<leader>ss` | Declarations |
| `<leader><space>`, `<leader>ff` | Files |
| `<leader>sg` | Grep |
| `<leader>sw` | Grep the word under the cursor |
| `<leader>sd` | Diagnostics |
| `<leader>fr` | The declarations gone to |
| `<leader>sC` | Commands |
| `<leader>sk` | Keymaps |
| `<leader>sR` | The last picker again |
| `<leader>sp` | The pickers |
| `<leader>n` | A new declaration |
| `gm` | Resolve the missing name under the cursor |
| `<leader>b` | Back |
| `<leader>z` | Centre the camera |

In a picker:

| Keys | What they do |
|---|---|
| `<CR>` | Pick |
| `<Esc>` | Close |
| `<C-n>` `<C-p>` `<Down>` `<Up>` `<Tab>` `<S-Tab>` `<C-j>` `<C-k>` | Move |
| `<PageDown>` `<PageUp>` | Move a page |
| `<C-f>` `<C-b>` | Scroll the preview |

In the tree, `j` `k` and the rest of Nvim's motions move. `<CR>` and `o`
open, `l` and `h` open and close folders, `q` closes the tree, and `<Esc>`
goes back to the cards. With the mouse, a click selects and a double click
opens.

A name the language server says is undefined gets a dashed red "missing"
card in the uses lane, with a red link from the name. Clicking the card,
or `gm` on the name (`:BiscideResolve`), opens a picker that offers:

- the language server's quick fixes (such as gopls's "Create function");
- a declaration of that name in the program, to import;
- the name created from scratch as any kind (func, method, struct,
  interface, type, const, var; Rust's fn, struct, enum, trait, …);
- the name created from a template.

New code goes at the end of the active file, in the new declaration's
card. Templates are biscide's (`biscide.templates`) and your own: files in
`~/.config/nvim/biscide/templates/{go,rust}/`, where `${name}` is the name,
`${recv}` a method's type, and `${cursor}` where you start typing.

Messages and errors go to the messages panel. The panel opens by itself for
a typed command's long output (`:messages`, `:ls`). The status line shows
the last message, and the panel's switch counts the errors and warnings you
have not seen.

Commands:

- `:BiscideGo`
- `:BiscideBack`
- `:BiscideLane {dir}`
- `:BiscideHistory {back|forward}`
- `:BiscideTree [toggle|open|close|reveal]`
- `:BiscidePick {name} [query]`
- `:BiscideFind [query]`
- `:BiscideMessages [toggle|open|close|clear]`
- `:BiscideNew`
- `:BiscideResolve`
- `:BiscideCentre`
- `:BiscideReload`
- `:BiscideCardCols {n}`

Events: `User BiscideActive` (data: `name`, `path`, `line`), `User
BiscideReady`.

For checking it without a screen: `QT_QPA_PLATFORM=offscreen
BISCIDE_SCREENSHOT=out.png BISCIDE_KEYS='…' nvim --gui` saves the window and
quits; `BISCIDE_FRAMES=n` also saves n frames 50 ms apart after the last keys
(out-1.png, …), to see how things move; `BISCIDE_DEBUG=1` logs the bridge.

Tests: `make functionaltest TEST_FILE=test/functional/plugin/biscide_spec.lua`.
