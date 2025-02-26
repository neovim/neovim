#!/usr/bin/env -S nvim -l

-- Validate vimdoc files on $VIMRUNTIME/doc, and test generating HTML docs.
-- Checks for duplicate/missing tags, parse errors, and invalid links/urls/spellings.
-- See also `make lintdoc`.
--
-- Usage:
--   $ nvim -l scripts/lintdoc.lua
--   $ make lintdoc

print('Running lintdoc ...')

-- gen_help_html requires :helptags to be generated on $VIMRUNTIME/doc
-- :helptags checks for duplicate tags.
vim.cmd [[ helptags ALL ]]

require('src.gen.gen_help_html').run_validate()
require('src.gen.gen_help_html').test_gen()

print('lintdoc PASSED.')
