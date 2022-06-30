" This Vim script deletes all the menus, so that they can be redefined.
" Warning: This also deletes all menus defined by the user!
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2019 Dec 10

aunmenu *
tlunmenu *

unlet! g:did_install_default_menus
unlet! g:did_install_syntax_menu

if exists('g:did_menu_trans')
  menutrans clear
  unlet g:did_menu_trans
endif

unlet! g:find_help_dialog

unlet! g:menutrans_fileformat_choices
unlet! g:menutrans_fileformat_dialog
unlet! g:menutrans_help_dialog
unlet! g:menutrans_no_file
unlet! g:menutrans_path_dialog
unlet! g:menutrans_set_lang_to
unlet! g:menutrans_spell_add_ARG_to_word_list
unlet! g:menutrans_spell_change_ARG_to
unlet! g:menutrans_spell_ignore_ARG
unlet! g:menutrans_tags_dialog
unlet! g:menutrans_textwidth_dialog

" vim: set sw=2 :
