---
name: Language server client bug report
about: Report a built-in lsp problem in Nvim
title: ''
labels: bug, lsp

---

<!-- Before reporting: search existing issues and check the FAQ. -->

- `nvim --version`:
- language server name/version:
- Operating system/version:

<details>
<summary>nvim -c ":checkhealth nvim nvim_lsp"</summary>

<!-- Paste the results from `nvim -c ":checkhealth nvim nvim_lsp"` here. -->

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

### Steps to reproduce using `nvim -u NORC`

```
nvim -u NORC
```

### Actual behaviour

### Expected behaviour

