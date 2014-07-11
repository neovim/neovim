" Menu Translations: Serbian
" Maintainer: Aleksandar Jelenak <ajelenak AT yahoo.com>
" Last Change:	Fri, 30 May 2003 12:02:07 -0400

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding iso8859-5

" Help menu
menutrans &Help		      Помо&ћ
menutrans &Overview<Tab><F1>  &Преглед<Tab><F1>
menutrans &User\ Manual       &Упутство\ за\ кориснике
menutrans &How-to\ links      &Како\ да\.\.\.
menutrans &Find		      &Нађи
menutrans &Credits	      &Заслуге
menutrans Co&pying	      П&реузимање
menutrans O&rphans	      &Сирочићи
menutrans &Version	      &Верзија
menutrans &About	      &О\ програму

" File menu
menutrans &File			    &Датотека
menutrans &Open\.\.\.<Tab>:e	    &Отвори\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp &Подели-отвори\.\.\.<Tab>:sp
menutrans &New<Tab>:enew	    &Нова<Tab>:enew
menutrans &Close<Tab>:close	    &Затвори<Tab>:close
menutrans &Save<Tab>:w		    &Сачувај<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav  Сачувај\ &као\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.  Подели\ и\ &упореди\ са\.\.\.
menutrans Split\ Patched\ &By\.\.\. По&дели\ и\ преправи\ са\.\.\.
menutrans &Print		    Шта&мпај
menutrans Sa&ve-Exit<Tab>:wqa	    Сачувај\ и\ за&врши<Tab>:wqa
menutrans E&xit<Tab>:qa		    К&рај<Tab>:qa

" Edit menu
menutrans &Edit			 &Уређивање
menutrans &Undo<Tab>u		 &Врати<Tab>u
menutrans &Redo<Tab>^R		 &Поврати<Tab>^R
menutrans Rep&eat<Tab>\.	 П&онови<Tab>\.
menutrans Cu&t<Tab>"+x		 Исе&ци<Tab>"+x
menutrans &Copy<Tab>"+y		 &Копирај<Tab>"+y
menutrans &Paste<Tab>"+gP	 &Убаци<Tab>"+gP
menutrans &Paste<Tab>"+P	&Убаци<Tab>"+gP
menutrans Put\ &Before<Tab>[p	 Стави\ пре&д<Tab>[p
menutrans Put\ &After<Tab>]p	 Стави\ &иза<Tab>]p
menutrans &Delete<Tab>x		 Из&бриши<Tab>x
menutrans &Select\ all<Tab>ggVG  Изабери\ св&е<Tab>ggVG
menutrans &Find\.\.\.		 &Нађи\.\.\.
menutrans Find\ and\ Rep&lace\.\.\. Нађи\ и\ &замени\.\.\.
menutrans Settings\ &Window	 П&розор\ подешавања
menutrans &Global\ Settings	 Оп&шта\ подешавања
menutrans F&ile\ Settings	 Подешавања\ за\ да&тотеке
menutrans &Shiftwidth		 &Померај
menutrans Soft\ &Tabstop	 &Мека\ табулација
menutrans Te&xt\ Width\.\.\.	 &Ширина\ текста\.\.\.
menutrans &File\ Format\.\.\.	 &Врста\ датотеке\.\.\.
menutrans C&olor\ Scheme	 Бо&је
menutrans &Keymap		 Прес&ликавање\ тастатуре
menutrans Select\ Fo&nt\.\.\.	 Избор\ &фонта\.\.\.

" Edit/Global Settings
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls! Нагласи\ &образце\ (да/не)<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic! Занемари\ \величину\ &слова\ (да/не)<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm! Провери\ пратећу\ &заграду\ (да/не)<Tab>:set\ sm!
menutrans &Context\ lines  Видљиви\ &редови
menutrans &Virtual\ Edit   Виртуелно\ &уређивање
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	Режим\ у&носа\ (да/не)<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!     '&Vi'\ сагласно\ (да/не)<Tab>:set\ cp!
menutrans Search\ &Path\.\.\. Путања\ &претраге\.\.\.
menutrans Ta&g\ Files\.\.\.   &Датотеке\ ознака\.\.\.
menutrans Toggle\ &Toolbar    Линија\ са\ &алаткама\ (да/не)
menutrans Toggle\ &Bottom\ Scrollbar   Доња\ л&инија\ клизања\ (да/не)
menutrans Toggle\ &Left\ Scrollbar  &Лева\ линија\ клизања\ (да/не)
menutrans Toggle\ &Right\ Scrollbar &Десна\ линија\ клизања\ (да/не)

" Edit/Global Settings/Virtual Edit
menutrans Never		      Никад
menutrans Block\ Selection    Избор\ блока
menutrans Insert\ mode	      Режим\ уноса
menutrans Block\ and\ Insert  Блок\ и\ унос
menutrans Always	      Увек

" Edit/File Settings
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!   Редни\ &бројеви\ (да/не)<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!	   Режим\ &листе\ (да/не)<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!	   Обавијање\ &редова\ (да/не)<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!   Преломи\ &на\ реч\ (да/не)<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!	   Размаци\ уместо\ &табулације\ (да/не)<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!	Ауто-&увлачење\ (да/не)<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!	   &Це-увлачење\ (да/не)<Tab>:set\ cin!

" Edit/Keymap
menutrans None Ниједан

" Tools menu
menutrans &Tools	&Алатке
menutrans &Jump\ to\ this\ tag<Tab>g^] Скочи\ на\ &ову\ ознаку<Tab>g^]
menutrans Jump\ &back<Tab>^T	 Скочи\ &натраг<Tab>^T
menutrans Build\ &Tags\ File	 Изгради\ &датотеку\ ознака
menutrans &Folding	      &Подвијање
menutrans Create\ &Fold<Tab>zf		  С&твори\ подвијутак<Tab>zf
menutrans &Delete\ Fold<Tab>zd		  О&бриши\ подвијутак<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD	  Обриши\ све\ по&двијутке<Tab>zD
menutrans Fold\ column\ &width		  Ширина\ &реда\ подвијутка
menutrans &Diff		      &Упоређивање
menutrans &Make<Tab>:make     'mak&е'<Tab>:make
menutrans &List\ Errors<Tab>:cl     Списак\ &грешака<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!  Сп&исак\ порука<Tab>:cl!
menutrans &Next\ Error<Tab>:cn	    С&ледећа\ грешка<Tab>:cn
menutrans &Previous\ Error<Tab>:cp  Пре&тходна\ грешка<Tab>:cp
menutrans &Older\ List<Tab>:cold    Стари\ списа&к<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew    Но&ви\ списак<Tab>:cnew
menutrans Error\ &Window	    Прозор\ са\ г&решкама
menutrans &Set\ Compiler	    И&забери\ преводиоца
menutrans &Convert\ to\ HEX<Tab>:%!xxd	   Претвори\ у\ &ХЕКС<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r    Вр&ати\ у\ првобитан\ облик<Tab>:%!xxd\ -r

" Tools/Folding
menutrans &Enable/Disable\ folds<Tab>zi   &Омогући/прекини\ подвијање<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv	  &Покажи\ ред\ са\ курсором<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx Покажи\ &само\ ред\ са\ курсором<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm   &Затвори\ више\ подвијутака<Tab>zm
menutrans &Close\ all\ folds<Tab>zM    Затвори\ с&ве\ подвијутке<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr    Отвори\ виш&е\ подвијутака<Tab>zr
menutrans &Open\ all\ folds<Tab>zR     О&твори\ све\ подвијутке<Tab>zR
menutrans Fold\ Met&hod		       &Начин\ подвијања

" Tools/Folding/Fold Method
menutrans M&anual	&Ручно
menutrans I&ndent	&Увученост
menutrans E&xpression	&Израз
menutrans S&yntax	&Синтакса
"menutrans &Diff
menutrans Ma&rker	&Ознака

" Tools/Diff
menutrans &Update	&Ажурирај
menutrans &Get\ Block	&Прихвати\ измену
menutrans &Put\ Block	Пре&баци\ измену

" Tools/Error Window
menutrans &Update<Tab>:cwin   &Ажурирај<Tab>:cwin
menutrans &Open<Tab>:copen    &Отвори<Tab>:copen
menutrans &Close<Tab>:cclose  &Затвори<Tab>:cclose

" Bufers menu
menutrans &Buffers	   &Бафери
menutrans &Refresh\ menu   &Ажурирај
menutrans Delete	   &Обриши
menutrans &Alternate	   А&лтернативни
menutrans &Next		   &Следећи
menutrans &Previous	   &Претходни
menutrans [No\ File]	   [Нема\ датотеке]

" Window menu
menutrans &Window		    &Прозор
menutrans &New<Tab>^Wn		    &Нови<Tab>^Wn
menutrans S&plit<Tab>^Ws	    &Подели<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^    Подели\ са\ &алтернативним<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv   Подели\ &усправно<Tab>^Wv
menutrans Split\ File\ E&xplorer    Подели\ за\ преглед\ &датотека
menutrans &Close<Tab>^Wc	    &Затвори<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo  Затвори\ &остале<Tab>^Wo
"menutrans Ne&xt<Tab>^Ww       &Следећи<Tab>^Ww
"menutrans P&revious<Tab>^WW	  П&ретходни<Tab>^WW
menutrans Move\ &To		    Пре&мести
menutrans Rotate\ &Up<Tab>^WR	    &Кружно\ нагоре<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr     Кружно\ надол&е<Tab>^Wr
menutrans &Equal\ Size<Tab>^W=	    &Исте\ величине<Tab>^W=
menutrans &Max\ Height<Tab>^W_	    Максимална\ &висина<Tab>^W_
menutrans M&in\ Height<Tab>^W1_     Минима&лна\ висина<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|	    Максимална\ &ширина<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|     Минимална\ ши&рина<Tab>^W1\|

" Window/Move To
menutrans &Top<Tab>^WK		 &Врх<Tab>^WK
menutrans &Bottom<Tab>^WJ	 &Подножје<Tab>^WJ
menutrans &Left\ side<Tab>^WH	 У&лево<Tab>^WH
menutrans &Right\ side<Tab>^WL	 У&десно<Tab>^WL

" The popup menu
menutrans &Undo		      &Врати
menutrans Cu&t		      &Исеци
menutrans &Copy		      &Копирај
menutrans &Paste	      &Убаци
menutrans &Delete	      И&збриши
menutrans Select\ Blockwise   Бирај\ &правоугаоно
menutrans Select\ &Word       Изабери\ &реч
menutrans Select\ &Line       Изабери\ р&ед
menutrans Select\ &Block      Изабери\ &блок
menutrans Select\ &All	      Изабери\ &све

" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open	   Учитај
    tmenu ToolBar.Save	   Сачувај
    tmenu ToolBar.SaveAll  Сачувај све
    tmenu ToolBar.Print    Штампај
    tmenu ToolBar.Undo	   Врати
    tmenu ToolBar.Redo	   Поврати
    tmenu ToolBar.Cut	   Исеци
    tmenu ToolBar.Copy	   Копирај
    tmenu ToolBar.Paste    Убаци
    tmenu ToolBar.Find	   Нађи
    tmenu ToolBar.FindNext Нађи следећи
    tmenu ToolBar.FindPrev Нађи претходни
    tmenu ToolBar.Replace  Замени
    tmenu ToolBar.New	   Нови
    tmenu ToolBar.WinSplit Подели прозор
    tmenu ToolBar.WinMax   Максимална висина
    tmenu ToolBar.WinMin   Минимална висина
    tmenu ToolBar.WinVSplit   Подели усправно
    tmenu ToolBar.WinMaxWidth Максимална ширина
    tmenu ToolBar.WinMinWidth Минимална ширина
    tmenu ToolBar.WinClose Затвори прозор
    tmenu ToolBar.LoadSesn Учитај сеансу
    tmenu ToolBar.SaveSesn Сачувај сеансу
    tmenu ToolBar.RunScript   Изврши спис
    tmenu ToolBar.Make	   'make'
    tmenu ToolBar.Shell    Оперативно окружење
    tmenu ToolBar.RunCtags Направи ознаке
    tmenu ToolBar.TagJump  Иди на ознаку
    tmenu ToolBar.Help	   Помоћ
    tmenu ToolBar.FindHelp Нађи објашњење
  endfun
endif

" Syntax menu
menutrans &Syntax &Синтакса
menutrans &Show\ filetypes\ in\ menu  Избор\ 'filetype'\ из\ &менија
menutrans Set\ '&syntax'\ only	 Поде&си\ 'syntax'\ само
menutrans Set\ '&filetype'\ too  Подеси\ 'filetype'\ &такође
menutrans &Off	     &Искључено
menutrans &Manual    &Ручно
menutrans A&utomatic	&Аутоматски
menutrans on/off\ for\ &This\ file     Да/не\ за\ ову\ &датотеку
menutrans Co&lor\ test	   Провера\ &боја
menutrans &Highlight\ test Провера\ исти&цања
menutrans &Convert\ to\ HTML  Претвори\ &у\ HTML

" dialog texts
let menutrans_help_dialog = "Унесите наредбу или реч чије појашњење тражите:\n\nДодајте i_ за наредбе уноса (нпр. i_CTRL-X)\nДодајте c_ за наредбе командног режима (нпр. с_<Del>)\nДодајте ' за имена опција (нпр. 'shiftwidth')"

let g:menutrans_path_dialog = "Унесите пут претраге за датотеке\nРаздвојите зарезима имена директоријума."

let g:menutrans_tags_dialog = "Унесите имена датотека са ознакама\nРаздвојите зарезима имена."

let g:menutrans_textwidth_dialog = "Унесите нову ширину текста (0 спречава прелом)"

let g:menutrans_fileformat_dialog = "Изаберите врсту датотеке"

let menutrans_no_file = "[Нема датотеке]"

let &cpo = s:keepcpo
unlet s:keepcpo
