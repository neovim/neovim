" This Vim script deletes all the menus, so that they can be redefined.
" Warning: This also deletes all menus defined by the user!
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2001 May 27

aunmenu *

silent! unlet did_install_default_menus
silent! unlet did_install_syntax_menu
if exists("did_menu_trans")
  menutrans clear
  unlet did_menu_trans
endif

silent! unlet find_help_dialog

silent! unlet menutrans_help_dialog
silent! unlet menutrans_path_dialog
silent! unlet menutrans_tags_dialog
silent! unlet menutrans_textwidth_dialog
silent! unlet menutrans_fileformat_dialog
silent! unlet menutrans_no_file

" vim: set sw=2 :
