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
menutrans &Help			帮助(&H)
menutrans &Overview<Tab><F1>	纵览(&O)<Tab><F1>
menutrans &User\ Manual		用户手册(&U)
menutrans &How-to\ links	How-to\ 指引(&H)
menutrans &Find\.\.\.		查找(&F)\.\.\.
menutrans &Credits		致谢(&C)
menutrans Co&pying		版权(&P)
menutrans &Sponsor/Register	赞助/注册(&S)
menutrans O&rphans		孤儿(&R)
menutrans &Version		版本(&V)
menutrans &About		关于(&A)

" File menu
menutrans &File				文件(&F)
menutrans &Open\.\.\.<Tab>:e		打开(&O)\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	分割并打开(&L)\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	打开标签\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew		新建(&N)<Tab>:enew
menutrans &Close<Tab>:close		关闭(&C)<Tab>:close
menutrans &Save<Tab>:w			保存(&S)<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	另存为(&A)\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	分割比较(Diff)(&D)\.\.\.
menutrans Split\ Patched\ &By\.\.\.	分割打补丁(Patch)(&B)\.\.\.
menutrans &Print			打印(&P)
menutrans Sa&ve-Exit<Tab>:wqa		保存并退出(&V)<Tab>:wqa
menutrans E&xit<Tab>:qa			退出(&X)<Tab>:qa

" Edit menu
menutrans &Edit				编辑(&E)
menutrans &Undo<Tab>u			撤销(&U)<Tab>u
menutrans &Redo<Tab>^R			重做(&R)<Tab>^R
menutrans Rep&eat<Tab>\.		重复上次操作(&E)<Tab>\.
menutrans Cu&t<Tab>"+x			剪切(&T)<Tab>"+x
menutrans &Copy<Tab>"+y			复制(&C)<Tab>"+y
menutrans &Paste<Tab>"+gP		粘贴(&P)<Tab>"+gP
menutrans Put\ &Before<Tab>[p		粘贴到光标前(&B)<Tab>[p
menutrans Put\ &After<Tab>]p		粘贴到光标后(&A)<Tab>]p
menutrans &Delete<Tab>x			删除(&D)<Tab>x
menutrans &Select\ All<Tab>ggVG		全选(&S)<Tab>ggVG
menutrans &Find\.\.\.			查找(&F)\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.	查找和替换(&L)\.\.\.
menutrans &Find<Tab>/			查找(&F)<Tab>/
menutrans Find\ and\ Rep&lace<Tab>:%s	查找和替换(&L)<Tab>:%s
menutrans Settings\ &Window		设定窗口(&W)
menutrans Startup\ &Settings		启动设定(&S)
menutrans &Global\ Settings		全局设定(&G)

" Edit/Global Settings
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	开/关模式高亮(&H)<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		开/关忽略大小写(&I)<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		开/关显示配对(&S)<Tab>:set\ sm!
menutrans &Context\ lines			上下文行数(&C)

menutrans &Virtual\ Edit			虚拟编辑(&V)
menutrans Never					从不
menutrans Block\ Selection			块选择
menutrans Insert\ mode				插入模式
menutrans Block\ and\ Insert			块选择和插入模式
menutrans Always				总是

menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	开/关插入模式(&M)<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!	开/关\ Vi\ 兼容<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.			查找路径(&P)\.\.\.
menutrans Ta&g\ Files\.\.\.			Tag\ 文件(&T)\.\.\.

" GUI options
menutrans Toggle\ &Toolbar			开/关工具栏(&T)
menutrans Toggle\ &Bottom\ Scrollbar		开/关底部滚动条(&B)
menutrans Toggle\ &Left\ Scrollbar		开/关左端滚动条(&L)
menutrans Toggle\ &Right\ Scrollbar		开/关右端滚动条(&R)

" Edit/File Settings
menutrans F&ile\ Settings			文件设定(&I)

" Boolean options
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	开/关显示行号(&N)<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		开/关\ list\ 模式(&L)<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		开/关折行(&W)<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	开/关整词折行(&R)<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		开/关扩展\ tab(&E)<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		开/关自动缩进(&A)<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		开/关\ C\ 缩进(&C)<Tab>:set\ cin!

" other options
menutrans &Shiftwidth			缩进宽度(&S)
menutrans Soft\ &Tabstop		Soft\ Tab\ 宽度(&T)
menutrans Te&xt\ Width\.\.\.		文本宽度(&X)\.\.\.
menutrans &File\ Format\.\.\.		文件格式(&F)\.\.\.
menutrans C&olor\ Scheme		配色方案(&O)
menutrans Select\ Fo&nt\.\.\.		选择字体(&N)\.\.\.
menutrans &Keymap			键盘映射(&K)

" Programming menu
menutrans &Tools			工具(&T)
menutrans &Jump\ to\ this\ tag<Tab>g^]	跳转到这个\ tag(&J)<Tab>g^]
menutrans Jump\ &back<Tab>^T		跳转返回(&B)<Tab>^T
menutrans Build\ &Tags\ File		建立\ Tags\ 文件(&T)

" Tools.Spelling Menu
menutrans &Spelling				拼写检查(&S)
menutrans &Spell\ Check\ On			打开拼写检查(&S)
menutrans Spell\ Check\ &Off			关闭拼写检查(&O)
menutrans To\ &Next\ error<Tab>]s		上一个错误(&N)<Tab>]s
menutrans To\ &Previous\ error<Tab>[s		下一个错误(&P)<Tab>[s
menutrans Suggest\ &Corrections<Tab>z=		修正建议(&C)<Tab>z=
menutrans &Repeat\ correction<Tab>:spellrepall	重复修正(&R)<Tab>:spellrepall
menutrans Set\ language\ to\ "en"		设定语言为\ "en"
menutrans Set\ language\ to\ "en_au"		设定语言为\ "en_au"
menutrans Set\ language\ to\ "en_ca"		设定语言为\ "en_ca"
menutrans Set\ language\ to\ "en_gb"		设定语言为\ "en_gb"
menutrans Set\ language\ to\ "en_nz"		设定语言为\ "en_nz"
menutrans Set\ language\ to\ "en_us"		设定语言为\ "en_us"
menutrans &Find\ More\ Languages		查找更多语言(&F)

" Tools.Fold Menu
" open close folds
menutrans &Folding				折叠(&F)
menutrans &Enable/Disable\ folds<Tab>zi		启用/禁用折叠(&E)<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv		查看此行(&V)<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx	仅查看此行(&W)<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm		关闭更多折叠(&L)<Tab>zm
menutrans &Close\ all\ folds<Tab>zM		关闭所有折叠(&C)<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr		打开更多折叠(&P)<Tab>zr
menutrans &Open\ all\ folds<Tab>zR		打开所有折叠(&O)<Tab>zR
" fold method
menutrans Fold\ Met&hod			折叠方法(&H)
menutrans M&anual			手工(&A)
menutrans I&ndent			缩进(&N)
menutrans E&xpression			表达式(&X)
menutrans S&yntax			语法(&Y)
menutrans &Diff				比较(Diff)(&D)
menutrans Ma&rker			标记(&R)
" create and delete folds
menutrans Create\ &Fold<Tab>zf		创建折叠(&F)<Tab>zf
menutrans &Delete\ Fold<Tab>zd		删除折叠(&D)<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD	删除所有折叠(&A)<Tab>zD
" moving around in folds
menutrans Fold\ column\ &width		折叠栏宽度(&W)

" Tools.Diff Menu
menutrans &Diff				比较(Diff)(&D)
menutrans &Update			更新(&U)
menutrans &Get\ Block			得到块(&G)
menutrans &Put\ Block			放置块(&P)

menutrans &Make<Tab>:make		Make(&M)<Tab>:make
menutrans &List\ Errors<Tab>:cl		列出错误(&L)<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	列出消息(&I)<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		下一个错误(&N)<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	上一个错误(&P)<Tab>:cp
menutrans &Older\ List<Tab>:cold	更旧的错误列表(&O)<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	更新的错误列表(&E)<Tab>:cnew
menutrans Error\ &Window		错误窗口(&W)
menutrans &Update<Tab>:cwin		更新(&U)<Tab>:cwin
menutrans &Open<Tab>:copen		打开(&O)<Tab>:copen
menutrans &Close<Tab>:cclose		关闭(&C)<Tab>:cclose
menutrans &Convert\ to\ HEX<Tab>:%!xxd	转换成十六进制<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r	转换返回<Tab>:%!xxd\ -r
menutrans Se&T\ Compiler		设定编译器(&T)

" Names for buffer menu.
menutrans &Buffers		缓冲区(&B)
menutrans &Refresh\ menu	更新菜单(&R)
menutrans &Delete		删除(&D)
menutrans &Alternate		交替(&A)
menutrans &Next			下一个(&N)
menutrans &Previous		上一个(&P)

" Window menu
menutrans &Window			窗口(&W)
menutrans &New<Tab>^Wn			新建(&N)<Tab>^Wn
menutrans S&plit<Tab>^Ws		分割(&P)<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	分割到\ #(&L)<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	垂直分割(&V)<Tab>^Wv
menutrans Split\ File\ E&xplorer	分割文件浏览器(&X)
menutrans &Close<Tab>^Wc		关闭(&C)<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	关闭其它窗口(&O)<Tab>^Wo
menutrans Move\ &To			移动到(&T)
menutrans &Top<Tab>^WK			顶端(&T)<Tab>^WK
menutrans &Bottom<Tab>^WJ		底端(&B)<Tab>^WJ
menutrans &Left\ side<Tab>^WH		左边(&L)<Tab>^WH
menutrans &Right\ side<Tab>^WL		右边(&R)<Tab>^WL
" menutrans Ne&xt<Tab>^Ww		下一个(&X)<Tab>^Ww
" menutrans P&revious<Tab>^WW		上一个(&R)<Tab>^WW
menutrans Rotate\ &Up<Tab>^WR		向上轮换(&U)<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		向下轮换(&D)<Tab>^Wr
menutrans &Equal\ Size<Tab>^W=		等大(&E)<Tab>^W=
menutrans &Max\ Height<Tab>^W_		最大高度(&M)<Tab>^W
menutrans M&in\ Height<Tab>^W1_		最小高度(&I)<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		最大宽度(&W)<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		最小宽度(&H)<Tab>^W1\|
"
" The popup menu
menutrans &Undo			撤销(&U)
menutrans Cu&t			剪切(&T)
menutrans &Copy			复制(&C)
menutrans &Paste		粘贴(&P)
menutrans &Delete		删除(&D)
menutrans Select\ Blockwise	选择块
menutrans Select\ &Word		选择单词(&W)
menutrans Select\ &Sentence	选择句子(&S)
menutrans Select\ Pa&ragraph	选择段落(&R)
menutrans Select\ &Line		选择行(&L)
menutrans Select\ &Block	选择块(&B)
menutrans Select\ &All		全选(&A)
"
" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		打开文件
    tmenu ToolBar.Save		保存当前文件
    tmenu ToolBar.SaveAll	保存全部文件
    tmenu ToolBar.Print		打印
    tmenu ToolBar.Undo		撤销
    tmenu ToolBar.Redo		重做
    tmenu ToolBar.Cut		剪切到剪贴板
    tmenu ToolBar.Copy		复制到剪贴板
    tmenu ToolBar.Paste		从剪贴板粘贴
    tmenu ToolBar.Find		查找...
    tmenu ToolBar.FindNext	查找下一个
    tmenu ToolBar.FindPrev	查找上一个
    tmenu ToolBar.Replace	查找和替换...
    tmenu ToolBar.LoadSesn	加载会话
    tmenu ToolBar.SaveSesn	保存当前会话
    tmenu ToolBar.RunScript	运行 Vim 脚本
    tmenu ToolBar.Make		执行 Make (:make)
    tmenu ToolBar.RunCtags	在当前目录建立 tags (!ctags -R .)
    tmenu ToolBar.TagJump	跳转到光标位置的 tag
    tmenu ToolBar.Help		Vim 帮助
    tmenu ToolBar.FindHelp	查找 Vim 帮助
  endfun
endif

" Syntax menu
menutrans &Syntax			语法(&S)
menutrans &Show\ filetypes\ in\ menu	在菜单中显示文件类型(&S)
menutrans &Off				关闭(&O)
menutrans &Manual			手工(&M)
menutrans A&utomatic			自动(&U)
menutrans on/off\ for\ &This\ file	仅对这个文件开/关(&T)
menutrans Co&lor\ test			色彩测试(&L)
menutrans &Highlight\ test		高亮测试(&H)
menutrans &Convert\ to\ HTML		转换成\ HTML(&C)
menutrans Set\ '&syntax'\ only		仅设定\ 'syntax'(&S)
menutrans Set\ '&filetype'\ too		也设定\ 'filetype'(&F)

let &cpo = s:keepcpo
unlet s:keepcpo
