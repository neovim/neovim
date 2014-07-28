" Menu Translations:	Ukrainian
" Maintainer:		Bohdan Vlasyuk <bohdan@vstu.edu.ua>
" Last Change:		11 Oct 2001

"
" Please, see readme at htpp://www.vstu.edu.ua/~bohdan/vim before any
" complains, and even if you won't complain, read it anyway.
"

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding cp1251

" Help menu
menutrans &Help			&��������
menutrans &Overview<Tab><F1>	&��������\ ����������<Tab><F1>
menutrans &User\ Manual		&����������\ ���\ �����������
menutrans &How-to\ links	&��-�������?
"menutrans &GUI			&GIU
menutrans &Credits		&������
menutrans Co&pying		&��������������
menutrans O&rphans		&��������\ �������
menutrans &Version		&�����
menutrans &About		���\ &��������

" File menu
menutrans &File				&����
menutrans &Open\.\.\.<Tab>:e	    &³������\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp &��������\ ����\.\.\.<Tab>:sp
menutrans &New<Tab>:enew	    &�����<Tab>:enew
menutrans &Close<Tab>:close	    &�������<Tab>:close
menutrans &Save<Tab>:w		    ��&���'�����<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	�����'�����\ &��\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	��&������\ �\.\.\.
menutrans Split\ Patched\ &By\.\.\.	��&������\.\.\.
menutrans &Print					&���������
menutrans Sa&ve-Exit<Tab>:wqa		��������\ �\ ��&���<Tab>:wqa
menutrans E&xit<Tab>:qa			&�����<Tab>:qa

" Edit menu
menutrans &Edit				&����������
menutrans &Undo<Tab>u			&³������<Tab>u
menutrans &Redo<Tab>^R			&���������<Tab>^R
menutrans Rep&eat<Tab>\.		�&��������<Tab>\.
menutrans Cu&t<Tab>"+x			��&�����<Tab>"+x
menutrans &Copy<Tab>"+y			&��������<Tab>"+y
menutrans &Paste<Tab>"+gP		�&�������<Tab>"+gP
menutrans Put\ &Before<Tab>[p		��������\ ����&����<Tab>[p
menutrans Put\ &After<Tab>]p		��������\ �&����<Tab>]p
menutrans &Select\ all<Tab>ggVG		��&�����\ ���<Tab>ggVG
menutrans &Find\.\.\.			&������\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.	��&�����\.\.\.
menutrans Settings\ &Window		³���\ &�����������
menutrans &Global\ Settings		�������\ ��&����������
menutrans F&ile\ Settings		������������\ ���\ &�����
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	&���������\ �����<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		�����\ ��&����������\ �����������<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		�����\ &��������<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	����������\ ���\ &�����<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!			�������������\ ��������\ &���������<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		������������\ &������<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		³������\ ���\ ����\ &C<Tab>:set\ cin!
menutrans &Shiftwidth								&����
menutrans Te&xt\ Width\.\.\.						&������\ ������\.\.\.
menutrans &File\ Format\.\.\.			&������\ �����\.\.\.
menutrans Soft\ &Tabstop				�������\ &���������
menutrans C&olor\ Scheme		&�������
menutrans Select\ Fo&nt\.\.\.		�������\ &�����\.\.\.


menutrans &Keymap			�����\ ���������
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	�������\ &������<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		&���������\ \�����\ ��\ ���\ �����<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		&��������\ �����<Tab>:set\ sm!
menutrans &Context\ lines	ʳ������\ &��������\ �����
menutrans &Virtual\ Edit	������\ &��������\ ���\ ���

menutrans Never			ͳ����
menutrans Block\ Selection	����\ �����
menutrans Insert\ mode		�����\ �������
menutrans Block\ and\ Insert	����\ �\ �������
menutrans Always		������

menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	�����\ &�������<Tab>:set\ im!
menutrans Search\ &Path\.\.\.	&����\ ������\.\.\.
menutrans Ta&g\ Files\.\.\.	�����\ &������\.\.\.


"
" GUI options
menutrans Toggle\ &Toolbar		������\ &�����������
menutrans Toggle\ &Bottom\ Scrollbar	&�����\ �����\ �����
menutrans Toggle\ &Left\ Scrollbar	&˳��\ �����\ �����
menutrans Toggle\ &Right\ Scrollbar	&�����\ �����\ �����

" Programming menu
menutrans &Tools			&�����������
menutrans &Jump\ to\ this\ tag<Tab>g^]	&�������\ ��\ ������<Tab>g^]
menutrans Jump\ &back<Tab>^T		��&���������<Tab>^T
menutrans Build\ &Tags\ File		&��������\ ����\ ������
" Folding
menutrans &Folding				&�������
menutrans &Enable/Disable\ folds<Tab>zi		&���������/����������\ �������<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv			&������\ �����\ �\ ��������<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx			������\ &����\ �����\ �\ ��������<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm				�������\ &�����\ �������<Tab>zm
menutrans &Close\ all\ folds<Tab>zM				�������\ &��\ �������<Tab>zM
menutrans &Open\ all\ folds<Tab>zR				³������\ �&�\ �������<Tab>zR
menutrans O&pen\ more\ folds<Tab>zr				³������\ �&�����\ �������<Tab>zr

menutrans Create\ &Fold<Tab>zf				�&�������\ �������<Tab>zf
menutrans &Delete\ Fold<Tab>zd				&��������\ �������<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD		�������&�\ ��\ �������<Tab>zD
menutrans Fold\ column\ &width				&�������\ �����\ �������
menutrans Fold\ Met&hod		&�����\ ���������
menutrans M&anual			&������
menutrans I&ndent			&³�����
menutrans E&xpression       �&����
menutrans S&yntax			&�����������
menutrans Ma&rker			��&������

" Diff
menutrans &Diff					��&�������
menutrans &Update				&��������
menutrans &Get\ Block			&����������\ ������
menutrans &Put\ Block			&����������\ ������

" Make and stuff...
menutrans &Make<Tab>:make		&��������(make)<Tab>:make
menutrans &List\ Errors<Tab>:cl		&������\ �������<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	��&����\ ����������<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		&��������\ �������<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	&���������\ �������<Tab>:cp
menutrans &Older\ List<Tab>:cold	&�����\ �������<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	&�������\ �������<Tab>:cnew
menutrans Error\ &Window	    &³���\ �������
menutrans &Update<Tab>:cwin			&��������<Tab>:cwin
menutrans &Close<Tab>:cclose		&�������<Tab>:cclose
menutrans &Open<Tab>:copen			&³������<Tab>:copen

menutrans &Set\ Compiler				����������\ &���������
menutrans &Convert\ to\ HEX<Tab>:%!xxd     ���������\ �\ �������������\ ����<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r     ���������\ �\ �������\ �����<Tab>:%!xxd\ -r

" Names for buffer menu.
menutrans &Buffers	&������
menutrans &Refresh\ menu &��������
menutrans Delete	&��������
menutrans &Alternate	&���������
menutrans &Next		&��������
menutrans &Previous	&���������
menutrans [No\ File]	[����\ �����]

" Window menu
menutrans &Window			&³���
menutrans &New<Tab>^Wn			&����<Tab>^Wn
menutrans S&plit<Tab>^Ws		&��������<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	��������\ ���\ &����������\ �����<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	��������\ &�������<Tab>^Wv
"menutrans Split\ &Vertically<Tab>^Wv	&��������\ �������<Tab>^Wv
menutrans Split\ File\ E&xplorer		��������\ ���\ &���������\ �����

menutrans &Close<Tab>^Wc		&�������<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	�������\ ��\ &����<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			&��������<Tab>^Ww
menutrans P&revious<Tab>^WW		&��������<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&��������\ �����<Tab>^W=
menutrans &Max\ Height<Tab>^W_		���&�����\ ������<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		���&�����\ ������<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		����&����\ ������<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		������&��\ ������<Tab>^W1\|
menutrans Move\ &To			&�������
menutrans &Top<Tab>^WK			��&����<Tab>^WK
menutrans &Bottom<Tab>^WJ		��&����<Tab>^WJ
menutrans &Left\ side<Tab>^WH		�&���<Tab>^WH
menutrans &Right\ side<Tab>^WL		�&�����<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		&�������\ ������<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		�&������\ ����<Tab>^Wr

" The popup menu
menutrans &Undo			&³������
menutrans Cu&t			��&�����
menutrans &Copy			&��������
menutrans &Paste		�&�������
menutrans &Delete		��&������
menutrans Select\ &Word		�������\ &�����
menutrans Select\ &Line		�������\ &�����
menutrans Select\ &Block	�������\ &����
menutrans Select\ &All		�������\ &���



" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		³������ ����
    tmenu ToolBar.Save		�����'����� ����
    tmenu ToolBar.SaveAll		�����'����� �� �����
    tmenu ToolBar.Print		���������
    tmenu ToolBar.Undo		³������
    tmenu ToolBar.Redo		���������
    tmenu ToolBar.Cut		�������
    tmenu ToolBar.Copy		��������
    tmenu ToolBar.Paste		��������
    tmenu ToolBar.Find		������...
    tmenu ToolBar.FindNext	������ ���������
    tmenu ToolBar.FindPrev	������ ���������
    tmenu ToolBar.Replace	�������...
    tmenu ToolBar.LoadSesn	����������� ����� �����������
    tmenu ToolBar.SaveSesn	�����'����� ����� �����������
    tmenu ToolBar.RunScript	�������� ���� ������
    tmenu ToolBar.Make		��������� ������
    tmenu ToolBar.Shell		Shell
    tmenu ToolBar.RunCtags	�������� ���� ������
    tmenu ToolBar.TagJump	������� �� ������
    tmenu ToolBar.Help		��������
    tmenu ToolBar.FindHelp	����� � �������
  endfun
endif

" Syntax menu
menutrans &Syntax &���������
menutrans Set\ '&syntax'\ only	�������������\ ����\ '&syntax'
menutrans Set\ '&filetype'\ too	�������������\ '&filetype'\ �����
menutrans &Off			&��������
menutrans &Manual		&������
menutrans A&utomatic		&�����������
menutrans on/off\ for\ &This\ file		����������\ ���\ �����\ &�����
menutrans Co&lor\ test		��������\ &�������
menutrans &Highlight\ test	&��������\ ��������
menutrans &Convert\ to\ HTML	��������\ &HTML

" dialog texts
let menutrans_no_file = "[����\ �����]"
let menutrans_help_dialog = "������ ������� ��� ����� ��� ������:\n\n������� i_ ��� ������ ������ ������� (����. i_CTRL-X)\n������� i_ ��� ���������� ������ (����. �_<Del>)\n������� ' ��� ���������� ����� ����� (����. 'shiftwidth')"
let g:menutrans_path_dialog = "������ ���� ������ �����\n��������� ����� ��������� ������."
let g:menutrans_tags_dialog = "������ ����� ����� ������\n��������� ����� ������."
let g:menutrans_textwidth_dialog = "������ ���� ������ ������ (0 ��� ����� �����������)"
let g:menutrans_fileformat_dialog = "������� ������ �����"

let &cpo = s:keepcpo
unlet s:keepcpo
