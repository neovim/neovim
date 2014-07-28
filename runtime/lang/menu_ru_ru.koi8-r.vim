" Menu Translations:	Russian
" Maintainer:		Sergey Alyoshin <alyoshin.s@gmail.com>
" Previous Maintainer:	vassily ragosin <vrr[at]users.sourceforge.net>
" Last Change:		29 May 2013
" URL:			cvs://cvs.sf.net:/cvsroot/ruvim/extras/menu/menu_ru_ru.vim
"
" $Id: menu_ru_ru.vim,v 1.1 2004/06/13 16:09:10 vimboss Exp $
"
" Adopted for RuVim project by Vassily Ragosin.
" First translation: Tim Alexeevsky <realtim [at] mail.ru>,
" based on ukrainian translation by Bohdan Vlasyuk <bohdan@vstu.edu.ua>
"
"
" Quit when menu translations have already been done.
"
if exists("did_menu_trans")
   finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding koi8-r

" Top
menutrans &File				&����
menutrans &Edit				�&�����
menutrans &Tools			&�����������
menutrans &Syntax			&���������
menutrans &Buffers			&������
menutrans &Window			&����
menutrans &Help				�&������
"
"
"
" Help menu
menutrans &Overview<Tab><F1>		&�����<Tab><F1>
menutrans &User\ Manual			������&�����\ ������������
menutrans &How-to\ links		&���\ ���\ �������\.\.\.
menutrans &Find\.\.\.			&�����
"--------------------
menutrans &Credits			&�������������
menutrans Co&pying			&���������������
menutrans &Sponsor/Register		����&��/�����������
menutrans O&rphans			&������
"--------------------
menutrans &Version			&����������\ �\ ���������
menutrans &About			&��������
"
"
" File menu
menutrans &Open\.\.\.<Tab>:e		&�������\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	��&������\ ����\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	�������\ �&������\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew		&�����<Tab>:enew
menutrans &Close<Tab>:close		&�������<Tab>:close
"--------------------
menutrans &Save<Tab>:w			&���������<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	���������\ &���\.\.\.<Tab>:sav
"--------------------
menutrans Split\ &Diff\ with\.\.\.	��&������\ �\.\.\.
menutrans Split\ Patched\ &By\.\.\.	��������\ �\ �����������\ ���&�����\.\.\.
"--------------------
menutrans &Print			��&��������
menutrans Sa&ve-Exit<Tab>:wqa		��&���\ �\ �����������<Tab>:wqa
menutrans E&xit<Tab>:qa			&�����<Tab>:qa
"
"
" Edit menu
menutrans &Undo<Tab>u			�&�������<Tab>u
menutrans &Redo<Tab>^R			�&������<Tab>^R
menutrans Rep&eat<Tab>\.		��������&�<Tab>\.
"--------------------
menutrans Cu&t<Tab>"+x			&��������<Tab>"+x
menutrans &Copy<Tab>"+y			&����������<Tab>"+y
menutrans &Paste<Tab>"+gP		��&�����<Tab>"+gP
menutrans Put\ &Before<Tab>[p		�������\ ����&�<Tab>[p
menutrans Put\ &After<Tab>]p		�������\ ��&���<Tab>]p
menutrans &Delete<Tab>x			&�������<Tab>x
menutrans &Select\ All<Tab>ggVG		�&�������\ �ӣ<Tab>ggVG
"--------------------
" Athena GUI only
menutrans &Find<Tab>/			&�����<Tab>/
menutrans Find\ and\ Rep&lace<Tab>:%s	�����\ �\ &������<Tab>:%s
" End Athena GUI only
menutrans &Find\.\.\.<Tab>/		&�����\.\.\.<Tab>/
menutrans Find\ and\ Rep&lace\.\.\.	�����\ �\ &������\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.<Tab>:%s	�����\ �\ &������\.\.\.<Tab>:%s
menutrans Find\ and\ Rep&lace\.\.\.<Tab>:s	�����\ �\ &������\.\.\.<Tab>:s
"--------------------
menutrans Settings\ &Window		����\ ���������\ &�����
menutrans Startup\ &Settings		���������\ �����&��
menutrans &Global\ Settings		&����������\ ���������
menutrans F&ile\ Settings		���������\ &������
menutrans C&olor\ Scheme		&��������\ �����
menutrans &Keymap			���������\ ��&��������
menutrans Select\ Fo&nt\.\.\.		�����\ &������\.\.\.
">>>----------------- Edit/Global settings
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	���������\ &���������\ ������������<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		&�������������������\ �����<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		����������\ ������\ &��������<Tab>:set\ sm!
menutrans &Context\ lines				���&��\ ������\ �������
menutrans &Virtual\ Edit				���&��������\ ��������������
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		�����\ &�������<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!		&�������������\ �\ Vi<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.				&����\ ���\ ������\ ������\.\.\.
menutrans Ta&g\ Files\.\.\.				�����\ &�����\.\.\.
"
menutrans Toggle\ &Toolbar				&����������������\ ������
menutrans Toggle\ &Bottom\ Scrollbar			������\ ���������\ ���&��
menutrans Toggle\ &Left\ Scrollbar			������\ ���������\ �&����
menutrans Toggle\ &Right\ Scrollbar			������\ ���������\ ���&���
">>>->>>------------- Edit/Global settings/Virtual edit
menutrans Never						���������
menutrans Block\ Selection				���\ ���������\ �����
menutrans Insert\ mode					�\ ������\ �������
menutrans Block\ and\ Insert				���\ ���������\ �����\ �\ �\ ������\ �������
menutrans Always					��������\ ������
">>>----------------- Edit/File settings
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	&���������\ �����<Tab>:set\ nu!
menutrans Toggle\ relati&ve\ Line\ Numbering<Tab>:set\ rnu!	��������&�����\ ���������\ �����<Tab>:set\ nru!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		������&�����\ ���������\ ��������<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		&�������\ �������\ �����<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	�������\ &�����\ ����<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		���&����\ ������\ ���������<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		��������������\ ��������������\ &��������<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		��������������\ ��������\ �\ &�����\ C<Tab>:set\ cin!
">>>---
menutrans &Shiftwidth					����&����\ �������
menutrans Soft\ &Tabstop				������\ &���������
menutrans Te&xt\ Width\.\.\.				&������\ ������\.\.\.
menutrans &File\ Format\.\.\.				&������\ �����\.\.\.
"
"
"
" Tools menu
menutrans &Jump\ to\ this\ tag<Tab>g^]			&�������\ �\ �����<Tab>g^]
menutrans Jump\ &back<Tab>^T				&���������\ �����<Tab>^T
menutrans Build\ &Tags\ File				�������\ &����\ �����
"-------------------
menutrans &Folding					������\ ��\ &���������
menutrans &Spelling					��&����������
menutrans &Diff						&�������\ (diff)
"-------------------
menutrans &Make<Tab>:make				��&��������<Tab>:make
menutrans &List\ Errors<Tab>:cl				������\ �&�����<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!			������\ ���&�\ ������\ �\ ��������������<Tab>:cl!
menutrans &Next\ Error<Tab>:cn				�����&����\ ������<Tab>:cn
menutrans &Previous\ Error<Tab>:cp			�&���������\ ������<Tab>:cp
menutrans &Older\ List<Tab>:cold			�����\ ����&��\ ������\ ������<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew			�����\ ���&���\ ������\ ������<Tab>:cnew
menutrans Error\ &Window				��&��\ ������
menutrans Se&T\ Compiler				�����\ &�����������
"-------------------
menutrans &Convert\ to\ HEX<Tab>:%!xxd			�&��������\ �\ HEX<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r			���������\ �&�\ HEX<Tab>:%!xxd\ -r
">>>---------------- Tools/Spelling
menutrans &Spell\ Check\ On				&���\ ��������\ ������������
menutrans Spell\ Check\ &Off				��&��\ ��������\ ������������
menutrans To\ &Next\ error<Tab>]s			&���������\ ������
menutrans To\ &Previous\ error<Tab>[s			&����������\ ������
menutrans Suggest\ &Corrections<Tab>z=			����������\ ���&��������
menutrans &Repeat\ correction<Tab>:spellrepall		���&������\ �����������\ ���\ ����
"-------------------
menutrans Set\ language\ to\ "en"			����������\ ����\ "en"
menutrans Set\ language\ to\ "en_au"			����������\ ����\ "en_au"
menutrans Set\ language\ to\ "en_ca"			����������\ ����\ "en_ca"
menutrans Set\ language\ to\ "en_gb"			����������\ ����\ "en_gb"
menutrans Set\ language\ to\ "en_nz"			����������\ ����\ "en_nz"
menutrans Set\ language\ to\ "en_us"			����������\ ����\ "en_us"
menutrans &Find\ More\ Languages			&�����\ ������\ ������
let g:menutrans_set_lang_to =				'���������� ����'
">>>---------------- Folds
menutrans &Enable/Disable\ folds<Tab>zi			���/����\ &�������<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv			�������\ ������\ �\ &��������<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx		�������\ &������\ ������\ �\ ��������<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm			�������\ &������\ �������<Tab>zm
menutrans &Close\ all\ folds<Tab>zM			�������\ &���\ �������<Tab>zM
menutrans &Open\ all\ folds<Tab>zR			����&���\ ���\ �������<Tab>zR
menutrans O&pen\ more\ folds<Tab>zr			���&����\ ������\ �������<Tab>zr
menutrans Fold\ Met&hod					&�����\ �������
menutrans Create\ &Fold<Tab>zf				��&�����\ �������<Tab>zf
menutrans &Delete\ Fold<Tab>zd				�&������\ �������<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD			�������\ ��&�\ �������<Tab>zD
menutrans Fold\ col&umn\ width				&������\ �������\ �������
">>>->>>----------- Tools/Folds/Fold Method
menutrans M&anual					���&����
menutrans I&ndent					�&�����
menutrans E&xpression					&���������
menutrans S&yntax					&���������
menutrans Ma&rker					&�������
">>>--------------- Tools/Diff
menutrans &Update					�&�������
menutrans &Get\ Block					��������\ &����\ �����
menutrans &Put\ Block					��������\ &������\ �����
">>>--------------- Tools/Diff/Error window
menutrans &Update<Tab>:cwin				�&�������<Tab>:cwin
menutrans &Close<Tab>:cclose				&�������<Tab>:cclose
menutrans &Open<Tab>:copen				&�������<Tab>:copen
"
"
" Syntax menu
"
menutrans &Show\ filetypes\ in\ menu			��������\ ����\ ���\ ������\ ����\ &�����
menutrans Set\ '&syntax'\ only				&��������\ ������\ ��������\ 'syntax'
menutrans Set\ '&filetype'\ too				��������\ &�����\ ��������\ 'filetype'
menutrans &Off						&���������
menutrans &Manual					���&����
menutrans A&utomatic					&�������������
menutrans on/off\ for\ &This\ file			���/����\ ���\ &�����\ �����
menutrans Co&lor\ test					��������\ &������
menutrans &Highlight\ test				��������\ ���&������
menutrans &Convert\ to\ HTML				�&������\ HTML\ �\ ����������
"
"
" Buffers menu
"
menutrans &Refresh\ menu				�&�������\ ����
menutrans Delete					�&������
menutrans &Alternate					&��������
menutrans &Next						�&��������
menutrans &Previous					&����������
menutrans [No\ File]					[���\ �����]
"
"
" Window menu
"
menutrans &New<Tab>^Wn					&�����\ ����<Tab>^Wn
menutrans S&plit<Tab>^Ws				&���������\ ����<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^			�������\ &��������\ ����\ �\ �����\ ����<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv			���������\ ��\ &���������<Tab>^Wv
menutrans Split\ File\ E&xplorer			�������\ ���������\ ��\ &��������\ �������
"
menutrans &Close<Tab>^Wc				&�������\ ���\ ����<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo			�������\ &���������\ ����<Tab>^Wo
"
menutrans Move\ &To					&�����������
menutrans Rotate\ &Up<Tab>^WR				��������\ ����&�<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr				��������\ �&���<Tab>^Wr
"
menutrans &Equal\ Size<Tab>^W=				�&���������\ ������<Tab>^W=
menutrans &Max\ Height<Tab>^W_				������������\ �&�����<Tab>^W_
menutrans M&in\ Height<Tab>^W1_				�����������\ ����&��<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|				������������\ &������<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|				�������&����\ ������<Tab>^W1\|
">>>----------------- Window/Move To
menutrans &Top<Tab>^WK					�&����<Tab>^WK
menutrans &Bottom<Tab>^WJ				�&���<Tab>^WJ
menutrans &Left\ side<Tab>^WH				�&����<Tab>^WH
menutrans &Right\ side<Tab>^WL				�&�����<Tab>^WL
"
"
" The popup menu
"
"
menutrans &Undo						�&�������
menutrans Cu&t						&��������
menutrans &Copy						&����������
menutrans &Paste					��&�����
menutrans &Delete					&�������
menutrans Select\ Blockwise				��������\ ���������
menutrans Select\ &Word					��������\ &�����
menutrans Select\ &Line					��������\ ��&����
menutrans Select\ &Block				��������\ &����
menutrans Select\ &All					�&�������\ &�ӣ
"
" The GUI toolbar
"
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open					������� ����
    tmenu ToolBar.Save					��������� ����
    tmenu ToolBar.SaveAll				��������� ��� �����
    tmenu ToolBar.Print					����������
    tmenu ToolBar.Undo					��������
    tmenu ToolBar.Redo					�������
    tmenu ToolBar.Cut					��������
    tmenu ToolBar.Copy					����������
    tmenu ToolBar.Paste					�������
    tmenu ToolBar.Find					�����...
    tmenu ToolBar.FindNext				����� ���������� ������������
    tmenu ToolBar.FindPrev				����� ����������� ������������
    tmenu ToolBar.Replace				��������...
    tmenu ToolBar.LoadSesn				��������� ����� ��������������
    tmenu ToolBar.SaveSesn				��������� ����� ��������������
    tmenu ToolBar.RunScript				��������� �������� Vim
    tmenu ToolBar.Make					����������
    tmenu ToolBar.Shell					��������
    tmenu ToolBar.RunCtags				������� ���� �����
    tmenu ToolBar.TagJump				������� � �����
    tmenu ToolBar.Help					�������
    tmenu ToolBar.FindHelp				����� �������
  endfun
endif
"
"
" Dialog texts
"
" Find in help dialog
"
let g:menutrans_help_dialog = "������� ������� ��� ����� ��� ������:\n\n�������� i_ ��� ������ ������ ������ ������� (��������, i_CTRL-X)\n�������� c_ ��� ������ ������ �������� ������ (��������, �_<Del>)\n�������� ' ��� ������ ������� �� ����� (��������, 'shiftwidth')"
"
" Searh path dialog
"
let g:menutrans_path_dialog = "������� ���� ��� ������ ������.\n����� ��������� ����������� ��������."
"
" Tag files dialog
"
let g:menutrans_tags_dialog = "������� ����� ������ ����� (����� �������).\n"
"
" Text width dialog
"
let g:menutrans_textwidth_dialog = "������� ������ ������ ��� ��������������.\n��� ������ �������������� ������� 0."
"
" File format dialog
"
let g:menutrans_fileformat_dialog = "�������� ������ �����."
let g:menutrans_fileformat_choices = "&Unix\n&Dos\n&Mac\n�&�����"
"
let menutrans_no_file = "[��� �����]"

let &cpo = s:keepcpo
unlet s:keepcpo
