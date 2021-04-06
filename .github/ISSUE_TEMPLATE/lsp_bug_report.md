---
name: Language server client bug report
about: Report a built-in lsp problem in Nvim
title: ''
labels: bug, lsp

---

<!-- 
Before reporting: search existing issues and check the FAQ. Usage questions
such as "How do I...?" or "Why isn't X language server/feature working?" belong 
on the [Neovim Discourse](https://neovim.discourse.group/c/7-category/7) and will
be closed.
-->

- `nvim --version`:
- language server name/version:
- Operating system/version:

<details>
<summary>nvim -c ":checkhealth nvim lspconfig"</summary>

<!-- Paste the results from `nvim -c ":checkhealth nvim lspconfig"` here. -->

</details>

<details>
<summary>lsp.log</summary>

<!--
Please paste the lsp log before and after the problem.

You can set log level like this.
`:lua vim.lsp.set_log_level("debug")`

You can find the location of the log with the following command.
`:lua print(vim.lsp.get_log_path())`
-->

</details>

### Steps to reproduce using nvim -u minimal_init.lua
<!-- 
  Note, if the issue is with an autocompletion or other LSP plugin, please
  report to the upstream tracker.  Download the minmal config with 
  wget https://raw.githubusercontent.com/neovim/nvim-lspconfig/master/test/minimal_init.lua
  and modify it to include any specific commands or servers pertaining to your issues.
-->


```
nvim -u minimal_init.lua
```

### Actual behaviour

### Expected behaviour

