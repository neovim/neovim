" Menu Translations:	Simplified Chinese <i18n-translation@lists.linux.net.cn>
" Translated By:	Yuheng Xie <elephant@linux.net.cn>
" Last Change:		Tue Apr 18 22:00:00 2006

" vim: ts=8 sw=8 noet

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding cp936

" Help menu
menutrans &Help			����(&H)
menutrans &Overview<Tab><F1>	����(&O)<Tab><F1>
menutrans &User\ Manual		�û��ֲ�(&U)
menutrans &How-to\ links	How-to\ ָ��(&H)
menutrans &Find\.\.\.		����(&F)\.\.\.
menutrans &Credits		��л(&C)
menutrans Co&pying		��Ȩ(&P)
menutrans &Sponsor/Register	����/ע��(&S)
menutrans O&rphans		�¶�(&R)
menutrans &Version		�汾(&V)
menutrans &About		����(&A)

" File menu
menutrans &File				�ļ�(&F)
menutrans &Open\.\.\.<Tab>:e		��(&O)\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	�ָ��(&L)\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	�򿪱�ǩ\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew		�½�(&N)<Tab>:enew
menutrans &Close<Tab>:close		�ر�(&C)<Tab>:close
menutrans &Save<Tab>:w			����(&S)<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	���Ϊ(&A)\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	�ָ�Ƚ�(Diff)(&D)\.\.\.
menutrans Split\ Patched\ &By\.\.\.	�ָ�򲹶�(Patch)(&B)\.\.\.
menutrans &Print			��ӡ(&P)
menutrans Sa&ve-Exit<Tab>:wqa		���沢�˳�(&V)<Tab>:wqa
menutrans E&xit<Tab>:qa			�˳�(&X)<Tab>:qa

" Edit menu
menutrans &Edit				�༭(&E)
menutrans &Undo<Tab>u			����(&U)<Tab>u
menutrans &Redo<Tab>^R			����(&R)<Tab>^R
menutrans Rep&eat<Tab>\.		�ظ��ϴβ���(&E)<Tab>\.
menutrans Cu&t<Tab>"+x			����(&T)<Tab>"+x
menutrans &Copy<Tab>"+y			����(&C)<Tab>"+y
menutrans &Paste<Tab>"+gP		ճ��(&P)<Tab>"+gP
menutrans Put\ &Before<Tab>[p		ճ�������ǰ(&B)<Tab>[p
menutrans Put\ &After<Tab>]p		ճ��������(&A)<Tab>]p
menutrans &Delete<Tab>x			ɾ��(&D)<Tab>x
menutrans &Select\ All<Tab>ggVG		ȫѡ(&S)<Tab>ggVG
menutrans &Find\.\.\.			����(&F)\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.	���Һ��滻(&L)\.\.\.
menutrans &Find<Tab>/			����(&F)<Tab>/
menutrans Find\ and\ Rep&lace<Tab>:%s	���Һ��滻(&L)<Tab>:%s
menutrans Settings\ &Window		�趨����(&W)
menutrans Startup\ &Settings		�����趨(&S)
menutrans &Global\ Settings		ȫ���趨(&G)

" Edit/Global Settings
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	��/��ģʽ����(&H)<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		��/�غ��Դ�Сд(&I)<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		��/����ʾ���(&S)<Tab>:set\ sm!
menutrans &Context\ lines			����������(&C)

menutrans &Virtual\ Edit			����༭(&V)
menutrans Never					�Ӳ�
menutrans Block\ Selection			��ѡ��
menutrans Insert\ mode				����ģʽ
menutrans Block\ and\ Insert			��ѡ��Ͳ���ģʽ
menutrans Always				����

menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	��/�ز���ģʽ(&M)<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!	��/��\ Vi\ ����<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.			����·��(&P)\.\.\.
menutrans Ta&g\ Files\.\.\.			Tag\ �ļ�(&T)\.\.\.

" GUI options
menutrans Toggle\ &Toolbar			��/�ع�����(&T)
menutrans Toggle\ &Bottom\ Scrollbar		��/�صײ�������(&B)
menutrans Toggle\ &Left\ Scrollbar		��/����˹�����(&L)
menutrans Toggle\ &Right\ Scrollbar		��/���Ҷ˹�����(&R)

" Edit/File Settings
menutrans F&ile\ Settings			�ļ��趨(&I)

" Boolean options
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	��/����ʾ�к�(&N)<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		��/��\ list\ ģʽ(&L)<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		��/������(&W)<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	��/����������(&R)<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		��/����չ\ tab(&E)<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		��/���Զ�����(&A)<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		��/��\ C\ ����(&C)<Tab>:set\ cin!

" other options
menutrans &Shiftwidth			�������(&S)
menutrans Soft\ &Tabstop		Soft\ Tab\ ���(&T)
menutrans Te&xt\ Width\.\.\.		�ı����(&X)\.\.\.
menutrans &File\ Format\.\.\.		�ļ���ʽ(&F)\.\.\.
menutrans C&olor\ Scheme		��ɫ����(&O)
menutrans Select\ Fo&nt\.\.\.		ѡ������(&N)\.\.\.
menutrans &Keymap			����ӳ��(&K)

" Programming menu
menutrans &Tools			����(&T)
menutrans &Jump\ to\ this\ tag<Tab>g^]	��ת�����\ tag(&J)<Tab>g^]
menutrans Jump\ &back<Tab>^T		��ת����(&B)<Tab>^T
menutrans Build\ &Tags\ File		����\ Tags\ �ļ�(&T)

" Tools.Spelling Menu
menutrans &Spelling				ƴд���(&S)
menutrans &Spell\ Check\ On			��ƴд���(&S)
menutrans Spell\ Check\ &Off			�ر�ƴд���(&O)
menutrans To\ &Next\ error<Tab>]s		��һ������(&N)<Tab>]s
menutrans To\ &Previous\ error<Tab>[s		��һ������(&P)<Tab>[s
menutrans Suggest\ &Corrections<Tab>z=		��������(&C)<Tab>z=
menutrans &Repeat\ correction<Tab>:spellrepall	�ظ�����(&R)<Tab>:spellrepall
menutrans Set\ language\ to\ "en"		�趨����Ϊ\ "en"
menutrans Set\ language\ to\ "en_au"		�趨����Ϊ\ "en_au"
menutrans Set\ language\ to\ "en_ca"		�趨����Ϊ\ "en_ca"
menutrans Set\ language\ to\ "en_gb"		�趨����Ϊ\ "en_gb"
menutrans Set\ language\ to\ "en_nz"		�趨����Ϊ\ "en_nz"
menutrans Set\ language\ to\ "en_us"		�趨����Ϊ\ "en_us"
menutrans &Find\ More\ Languages		���Ҹ�������(&F)

" Tools.Fold Menu
" open close folds
menutrans &Folding				�۵�(&F)
menutrans &Enable/Disable\ folds<Tab>zi		����/�����۵�(&E)<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv		�鿴����(&V)<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx	���鿴����(&W)<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm		�رո����۵�(&L)<Tab>zm
menutrans &Close\ all\ folds<Tab>zM		�ر������۵�(&C)<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr		�򿪸����۵�(&P)<Tab>zr
menutrans &Open\ all\ folds<Tab>zR		�������۵�(&O)<Tab>zR
" fold method
menutrans Fold\ Met&hod			�۵�����(&H)
menutrans M&anual			�ֹ�(&A)
menutrans I&ndent			����(&N)
menutrans E&xpression			���ʽ(&X)
menutrans S&yntax			�﷨(&Y)
menutrans &Diff				�Ƚ�(Diff)(&D)
menutrans Ma&rker			���(&R)
" create and delete folds
menutrans Create\ &Fold<Tab>zf		�����۵�(&F)<Tab>zf
menutrans &Delete\ Fold<Tab>zd		ɾ���۵�(&D)<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD	ɾ�������۵�(&A)<Tab>zD
" moving around in folds
menutrans Fold\ column\ &width		�۵������(&W)

" Tools.Diff Menu
menutrans &Diff				�Ƚ�(Diff)(&D)
menutrans &Update			����(&U)
menutrans &Get\ Block			�õ���(&G)
menutrans &Put\ Block			���ÿ�(&P)

menutrans &Make<Tab>:make		Make(&M)<Tab>:make
menutrans &List\ Errors<Tab>:cl		�г�����(&L)<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	�г���Ϣ(&I)<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		��һ������(&N)<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	��һ������(&P)<Tab>:cp
menutrans &Older\ List<Tab>:cold	���ɵĴ����б�(&O)<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	���µĴ����б�(&E)<Tab>:cnew
menutrans Error\ &Window		���󴰿�(&W)
menutrans &Update<Tab>:cwin		����(&U)<Tab>:cwin
menutrans &Open<Tab>:copen		��(&O)<Tab>:copen
menutrans &Close<Tab>:cclose		�ر�(&C)<Tab>:cclose
menutrans &Convert\ to\ HEX<Tab>:%!xxd	ת����ʮ������<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r	ת������<Tab>:%!xxd\ -r
menutrans Se&T\ Compiler		�趨������(&T)

" Names for buffer menu.
menutrans &Buffers		������(&B)
menutrans &Refresh\ menu	���²˵�(&R)
menutrans &Delete		ɾ��(&D)
menutrans &Alternate		����(&A)
menutrans &Next			��һ��(&N)
menutrans &Previous		��һ��(&P)

" Window menu
menutrans &Window			����(&W)
menutrans &New<Tab>^Wn			�½�(&N)<Tab>^Wn
menutrans S&plit<Tab>^Ws		�ָ�(&P)<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	�ָ\ #(&L)<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	��ֱ�ָ�(&V)<Tab>^Wv
menutrans Split\ File\ E&xplorer	�ָ��ļ������(&X)
menutrans &Close<Tab>^Wc		�ر�(&C)<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	�ر���������(&O)<Tab>^Wo
menutrans Move\ &To			�ƶ���(&T)
menutrans &Top<Tab>^WK			����(&T)<Tab>^WK
menutrans &Bottom<Tab>^WJ		�׶�(&B)<Tab>^WJ
menutrans &Left\ side<Tab>^WH		���(&L)<Tab>^WH
menutrans &Right\ side<Tab>^WL		�ұ�(&R)<Tab>^WL
" menutrans Ne&xt<Tab>^Ww		��һ��(&X)<Tab>^Ww
" menutrans P&revious<Tab>^WW		��һ��(&R)<Tab>^WW
menutrans Rotate\ &Up<Tab>^WR		�����ֻ�(&U)<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		�����ֻ�(&D)<Tab>^Wr
menutrans &Equal\ Size<Tab>^W=		�ȴ�(&E)<Tab>^W=
menutrans &Max\ Height<Tab>^W_		���߶�(&M)<Tab>^W
menutrans M&in\ Height<Tab>^W1_		��С�߶�(&I)<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		�����(&W)<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		��С���(&H)<Tab>^W1\|
"
" The popup menu
menutrans &Undo			����(&U)
menutrans Cu&t			����(&T)
menutrans &Copy			����(&C)
menutrans &Paste		ճ��(&P)
menutrans &Delete		ɾ��(&D)
menutrans Select\ Blockwise	ѡ���
menutrans Select\ &Word		ѡ�񵥴�(&W)
menutrans Select\ &Sentence	ѡ�����(&S)
menutrans Select\ Pa&ragraph	ѡ�����(&R)
menutrans Select\ &Line		ѡ����(&L)
menutrans Select\ &Block	ѡ���(&B)
menutrans Select\ &All		ȫѡ(&A)
"
" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		���ļ�
    tmenu ToolBar.Save		���浱ǰ�ļ�
    tmenu ToolBar.SaveAll	����ȫ���ļ�
    tmenu ToolBar.Print		��ӡ
    tmenu ToolBar.Undo		����
    tmenu ToolBar.Redo		����
    tmenu ToolBar.Cut		���е�������
    tmenu ToolBar.Copy		���Ƶ�������
    tmenu ToolBar.Paste		�Ӽ�����ճ��
    tmenu ToolBar.Find		����...
    tmenu ToolBar.FindNext	������һ��
    tmenu ToolBar.FindPrev	������һ��
    tmenu ToolBar.Replace	���Һ��滻...
    tmenu ToolBar.LoadSesn	���ػỰ
    tmenu ToolBar.SaveSesn	���浱ǰ�Ự
    tmenu ToolBar.RunScript	���� Vim �ű�
    tmenu ToolBar.Make		ִ�� Make (:make)
    tmenu ToolBar.RunCtags	�ڵ�ǰĿ¼���� tags (!ctags -R .)
    tmenu ToolBar.TagJump	��ת�����λ�õ� tag
    tmenu ToolBar.Help		Vim ����
    tmenu ToolBar.FindHelp	���� Vim ����
  endfun
endif

" Syntax menu
menutrans &Syntax			�﷨(&S)
menutrans &Show\ filetypes\ in\ menu	�ڲ˵�����ʾ�ļ�����(&S)
menutrans &Off				�ر�(&O)
menutrans &Manual			�ֹ�(&M)
menutrans A&utomatic			�Զ�(&U)
menutrans on/off\ for\ &This\ file	��������ļ���/��(&T)
menutrans Co&lor\ test			ɫ�ʲ���(&L)
menutrans &Highlight\ test		��������(&H)
menutrans &Convert\ to\ HTML		ת����\ HTML(&C)
menutrans Set\ '&syntax'\ only		���趨\ 'syntax'(&S)
menutrans Set\ '&filetype'\ too		Ҳ�趨\ 'filetype'(&F)

let &cpo = s:keepcpo
unlet s:keepcpo
