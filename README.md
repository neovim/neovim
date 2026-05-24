<h1 align="center">
  Yet Another Neovim

  <br>
  <sub>Because the world desperately needed one more fork.</sub>
</h1>

<p align="center">
  A Neovim fork that adds a <code>paradigm</code> option, letting you switch Normal mode
  between classic Vim (verb-noun) and Helix-style (noun-verb, selection-first) editing.
  <br><br>
  You select, <i>then</i> you act. Like a civilized person.
</p>

---

## What is this?

This is a hard fork of [Neovim](https://github.com/neovim/neovim) with one meaningful addition: a built-in Helix editing paradigm.

```lua
vim.opt.paradigm = 'vim'    -- default. you already know this one.
vim.opt.paradigm = 'helix'  -- the good one.
```

Set it to `'helix'` and Normal mode becomes selection-first. Every motion selects. Every verb acts on what you selected. No more `d3w` and praying you counted the words right. You press `w` three times, *see* exactly what you're about to obliterate, and *then* press `d`. Revolutionary? No. Helix has been doing this for years. But you like your 847 Neovim plugins, and Helix doesn't have those. So here we are.

## How it works

**Motions select.** Press `w` and the next word lights up. Press `$` and everything to the end of the line lights up. Press `G` and... you get the idea.

**`h`/`j`/`k`/`l` navigate.** They move the cursor and select the single character under it. Like arrow keys, but for people with taste.

**Verbs operate on the selection.** `d` deletes it. `y` yanks it. `c` changes it. No operator-pending mode. No guessing.

**`Esc` cancels.** Collapses the selection back to one character. No verb executed. No harm done.

**Everything else is untouched.** Insert mode works. Visual mode works. Your plugins work. `mode()` returns `'n'` so your statusline plugin doesn't have an identity crisis.

## Why not just use Helix?

Because you have 200 hours invested in your Neovim config and you're not throwing that away. Because Telescope exists. Because LSP in Neovim is actually good now and you've already suffered through configuring it. Because switching editors is for people who don't have deadlines.

This gives you the one thing Helix got right — selection-first editing — without making you abandon your entire setup.

## Why a fork? Why not a plugin?

Because selection-first editing needs to intercept every motion handler at the C level, before Neovim's state machine processes them. A Lua plugin can't do that without being a laggy, fragile hack stapled onto the event loop. This is the kind of change that belongs in the core. So here it is, in the core.

## Update policy

This fork tracks upstream Neovim. I merge in updates when I need them or when something interesting lands. This is not an automated pipeline. There is no bot. There is no CI that rebases nightly.

**This is intentional.**

In an era where your package manager updates 47 things before breakfast — half of which introduce breaking changes that their own test suite didn't catch — this fork updates when a human (me) decides it's worth updating. I use this daily. If upstream ships something I need, it gets merged. If upstream ships something that breaks things, it doesn't.

You might call this "lazy maintenance." I call it "not letting a cron job ruin my editor on a Monday morning."

Think of it as **artisanal software distribution**. Hand-merged. Locally sourced. Certified free of surprise regressions at 3 AM.

## Building

Same as Neovim. It's a Neovim fork, not a different species.

```bash
cmake -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j$(nproc)
```

The binary is called **`yanvim`**, not `nvim`. It installs alongside Neovim without conflicting.

Run it without installing:
```bash
VIMRUNTIME=runtime build/bin/yanvim
```

Or install it system-wide:
```bash
sudo cmake --install build
```

Or to `~/.local` (no sudo, keeps it in your user path):
```bash
cmake --install build --prefix ~/.local
```

yanvim uses the same config directory as Neovim (`~/.config/nvim/`), so your existing setup just works.

See [BUILD.md](./BUILD.md) for dependencies and platform-specific details. If you can build Neovim, you can build this. If you can't build Neovim, that's between you and CMake.

### Arch Linux (AUR)

```bash
yay -S yanvim-git
```

## Configuration

Add to your `init.lua`:

```lua
vim.opt.paradigm = 'helix'
```

That's it. One line. You can switch back to classic Vim at any time:

```lua
vim.opt.paradigm = 'vim'
```

No restart needed. No side effects. Your muscle memory for both paradigms can coexist peacefully.

### Highlight groups

The selection uses two highlight groups you can customize:

| Group | Default | Purpose |
|---|---|---|
| `HelixCursor` | links to `Cursor` | The 1-char resting selection |
| `HelixSelection` | links to `Visual` | Active multi-char selection |

They work with any colorscheme out of the box. Override them if you want your selections to look different from Visual mode.

## Quick reference

| Key | Vim paradigm | Helix paradigm |
|---|---|---|
| `w` | Move to next word | **Select** to next word |
| `b` | Move to prev word | **Select** to prev word |
| `$` | Move to end of line | **Select** to end of line |
| `h`/`l` | Move left/right | Move left/right (1-char select) |
| `j`/`k` | Move up/down | Move up/down (1-char select) |
| `d` | (needs motion) | Delete selection |
| `y` | (needs motion) | Yank selection |
| `c` | (needs motion) | Change selection |
| `Esc` | — | Collapse selection |

## FAQ

**Q: Is this stable?**
A: I use it every day. So either it's stable, or I have a very high tolerance for pain. Probably both.

**Q: Will my plugins break?**
A: No. The helix paradigm reports `mode()` as `'n'`. Plugins see Normal mode. They don't know about the selection state and they don't need to.

**Q: Can I map custom keys in helix mode?**
A: Standard Neovim mappings work. The paradigm only changes what the built-in motions do in Normal mode.

**Q: How far behind upstream are you?**
A: Check the commit log. If it's more than a few weeks, I'm either on vacation or nothing interesting happened upstream. Either way, your editor still works.

## License

Same as Neovim. Apache 2.0 for new contributions, Vim license for code inherited from Vim.
See [LICENSE.txt](./LICENSE.txt).

## Credits

Built on top of [Neovim](https://github.com/neovim/neovim), which is built on top of [Vim](https://www.vim.org/), which is built on top of [vi](https://en.wikipedia.org/wiki/Vi_(text_editor)), which is built on top of [ed](https://en.wikipedia.org/wiki/Ed_(text_editor)). It's turtles all the way down.

<!-- vim: set tw=80: -->
