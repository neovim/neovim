# yanvim — Yet Another Neovim

## What is this?

yanvim is a fork of Neovim that adds a first-class **selection-first editing paradigm** (noun-verb), inspired by the Helix editor.

The goal is not to replace Neovim's classic operator-first model, but to offer it as an opt-in alternative — controlled by a single global option — without breaking the existing plugin ecosystem.

---

## Motivation

Neovim follows the Vim tradition of **operator-first** (verb-noun) editing:

```
d w  →  delete → word
c i "  →  change → inside → quotes
```

Helix introduced a **selection-first** (noun-verb) model:

```
w d  →  select word → delete
m i " d  →  select inside quotes → delete
```

The selection-first model is more visual and predictable: you always see what will be affected before acting. yanvim brings this model into Neovim without forking the plugin ecosystem.

---

## Design principles

1. **Opt-in** — the classic Vim paradigm is the default. The new mode is enabled via `vim.opt.paradigm = 'helix'`.
2. **Plugin-transparent** — `mode()` always returns `'n'` in the new mode. Plugins like Telescope, which depend on Normal mode, continue to work.
3. **No ambiguity** — in helix paradigm, every motion selects. There is no "navigate without selecting". This eliminates the need for lookahead or context inference.
4. **Global scope** — the option is global, not per-buffer, keeping the implementation simple.

---

## Name

**yanvim** — Yet Another Neovim.

The acronym is intentional. `yan` also echoes `yank`, a core Vim concept, which fits the project's nature as a Vim-lineage editor.
