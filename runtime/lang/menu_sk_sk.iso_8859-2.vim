" Menu Translations:	Slovak
" Translated By:	Martin Lacko <lacko@host.sk>
" Last Change:		2012 May 01

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding iso-8859-2

" Help menu
menutrans &Help			&Pomocník
menutrans &Overview<Tab><F1>	&Prehµad<Tab><F1>
menutrans &User\ Manual		Po&u¾ívateµský\ manuál
menutrans &How-to\ links	&Tipy
menutrans &Find\.\.\.		&Nájs»\.\.\.
menutrans &Credits		Poï&akovanie
menutrans O&rphans		Si&roty
menutrans Co&pying		&Licencia
menutrans &Version		&Verzia
menutrans &About		&O\ programe

" File menu
menutrans &File				&Súbor
menutrans &Open\.\.\.<Tab>:e		&Otvori»\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Ot&vori»\ v\ novom\ okne\.\.\.<Tab>:sp
menutrans &New<Tab>:enew		&Nový<Tab>:enew
menutrans &Close<Tab>:close		&Zatvori»<Tab>:close
menutrans &Save<Tab>:w			&Ulo¾i»<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Ulo¾i»\ &ako\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	Otvor&i»\ porovnanie\ v\ novom\ okne\ s\.\.\.
menutrans Split\ Patched\ &By\.\.\.	Otvo&ri»\ aktualizované\ s\.\.\.
menutrans &Print			&Tlaè
menutrans Sa&ve-Exit<Tab>:wqa		U&lo¾i»-Koniec<Tab>:wqa
menutrans E&xit<Tab>:qa			&Koniec<Tab>:qa

" Edit menu
menutrans &Edit				&Úpravy
menutrans &Undo<Tab>u			&Spä»<Tab>u
menutrans &Redo<Tab>^R			Z&ru¹i»\ spä»<Tab>^R
menutrans Rep&eat<Tab>\.		&Opakova»<Tab>\.
menutrans Cu&t<Tab>"+x			&Vystrihnú»<Tab>"+x
menutrans &Copy<Tab>"+y			&Kopírova»<Tab>"+y
menutrans &Paste<Tab>"+gP		V&lo¾i»<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Vlo¾i»\ &pred<Tab>[p
menutrans Put\ &After<Tab>]p		Vlo¾i»\ za<Tab>]p
menutrans &Select\ all<Tab>ggVG		Vy&bra»\ v¹etko<Tab>ggVG
menutrans &Delete<Tab>x			Vy&maza»<Tab>x
menutrans &Find\.\.\.			&Nájs»\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.	N&ahradi»\.\.\.
menutrans Settings\ &Window		Mo&¾nosti
menutrans &Global\ Settings		&Globálne mo¾nosti
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Prepnú»\ paletu\ zvýrazòovania<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!	Prepnú»\ &ignorovanie veµkosti<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!	Prepnú»\ &ukáza»\ zhodu<Tab>:set\ sm!
menutrans &Context\ lines		&Kontextové\ riadky
menutrans &Virtual\ Edit		&Virtuálne úpravy
menutrans Never				Nikdy
menutrans Block\ Selection		Blokový\ výber
menutrans Insert\ mode			Re¾im\ vkladania
menutrans Block\ and\ Insert		Blok\ a\ vkladanie
menutrans Always			V¾dy
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	Prepnú»\ re¾i&m\ vkladania<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!	Prepnú»\ vi\ kompatibilitu<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.		Cesta\ &hµadania\.\.\.
menutrans Ta&g\ Files\.\.\.		Ta&gové súbory\.\.\.
menutrans Toggle\ &Toolbar		Prepnú»\ &panel
menutrans Toggle\ &Bottom\ Scrollbar	Prepnú»\ spodný\ posuvník
menutrans Toggle\ &Left\ Scrollbar	Prepnú»\ µavý\ posuvník
menutrans Toggle\ &Right\ Scrollbar	Prepnú»\ pravý\ posuvník
menutrans F&ile\ Settings		Nastavenia\ súboru
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	Prepnú»\ èíslova&nie\ riadkov<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Prepnú»\ re¾im\ &zoznamu<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Prepnú»\ z&alamovanie\ riadkov<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Prepnú»\ za&lamovanie\ slov<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		Prepnú»\ roz¹ír&ené\ tabulátory<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Prepnú»\ automatické\ &odsadzovanie<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Prepnú»\ &C-odsadzovanie<Tab>:set\ cin!
menutrans &Shiftwidth			&©írka\ ¹iftu
menutrans Soft\ &Tabstop		&Softvérový\ tabulátor
menutrans Te&xt\ Width\.\.\.		©írka\ te&xtu\.\.\.
menutrans &File\ Format\.\.\.		&Formát\ súboru\.\.\.
menutrans C&olor\ Scheme		Far&ebná\ schéma

" Programming menu
menutrans &Tools			&Nástroje
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Skoèi»\ na\ znaèku<Tab>g^]
menutrans Jump\ &back<Tab>^T		Sk&oèi»\ spä»<Tab>^T
menutrans Build\ &Tags\ File		&Vytvori»\ súbor\ znaèiek
menutrans &Folding			&Vnáranie
menutrans &Enable/Disable\ folds<Tab>zi	Zapnú»/Vypnú»\ vnárani&e<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv	Zobrazi»\ kurzoro&vý\ riadok<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx	Zobrazi»\ iba\ kurzorový\ riadok<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm	Zatvori»\ viac \vnorení<Tab>zm
menutrans &Close\ all\ folds<Tab>zM	Zatvor&i»\ v¹etky\ vnorenia<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr	O&tvori»\ viac\ vnorení<Tab>zr
menutrans &Open\ all\ folds<Tab>zR	&Otvori»\ v¹etky\ vnorenia<Tab>zR
menutrans Fold\ Met&hod			Metó&da\ vnárania
menutrans M&anual			M&anuálne
menutrans I&ndent			Odsade&nie
menutrans E&xpression			&Výraz
menutrans S&yntax			S&yntax
menutrans &Diff				Roz&diel
menutrans Ma&rker			Zna&èkovaè
menutrans Create\ &Fold<Tab>zf		Vyt&vori»\ vnorenie<Tab>zf
menutrans &Delete\ Fold<Tab>zd		V&ymaza»\ vnorenie<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD	Vymaza»\ v¹etky\ vnorenia<Tab>zD
menutrans Fold\ column\ &width		©írka\ &vkladaného\ ståpca
menutrans &Diff				&Rozdiely
menutrans &Update			Akt&ualizova»
menutrans &Get\ Block			Zob&ra»\ blok
menutrans &Put\ Block			&Vlo¾i»\ blok
menutrans Error\ &Window		Chybové\ &okno
menutrans &Update<Tab>:cwin		Akt&ualizova»<Tab>:cwin
menutrans &Open<Tab>:copen		&Otvori»<Tab>:copen
menutrans &Close<Tab>:cclose		&Zatvori»<Tab>:cclose
menutrans &Convert\ to\ HEX<Tab>:%!xxd	&Konvertova»\ do\ HEX<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r	Konve&rtova»\ spä»<Tab>:%!xxd\ -r
menutrans &Make<Tab>:make		&Make<Tab>:make
menutrans &List\ Errors<Tab>:cl		Výpis\ &chýb<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	Výp&is\ správ<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		Ïa&l¹ia\ chyba<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	&Predchádzajúca\ chyba<Tab>:cp
menutrans &Older\ List<Tab>:cold	Sta&r¹í\ zoznam<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	Nov¹í\ &zoznam<Tab>:cnew
menutrans Error\ &Window<Tab>:cwin	Chybové\ o&kno<Tab>:cwin
menutrans &Set\ Compiler		Vyberte\ k&ompilátor
menutrans Convert\ to\ HEX<Tab>:%!xxd	Prvies»\ do\ ¹es&tnástkového\ formátu<Tab>:%!xxd
menutrans Convert\ back<Tab>:%!xxd\ -r	Pr&evies»\ spä»<Tab>:%!xxd\ -r

" Names for buffer menu.
menutrans &Buffers		&Vyrovnávacia\ pamä»
menutrans &Refresh\ menu	Obnovi»
menutrans &Delete		Vymaza»
menutrans &Alternate		Zmeni»
menutrans &Next			Ï&al¹ia
menutrans &Previous		&Predchádzajúca
menutrans [No File]		[®iadny\ súbor]

" Window menu
menutrans &Window			&Okná
menutrans &New<Tab>^Wn			&Nové<Tab>^Wn
menutrans S&plit<Tab>^Ws		&Rozdeli»<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	Ro&zdeli»\ na\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Rozdeli»\ &vertikálne<Tab>^Wv
menutrans Split\ File\ E&xplorer	Otvori»\ pri&eskumníka
menutrans &Close<Tab>^Wc		Zatvor&i»<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Zatvori»\ i&né<Tab>^Wo
menutrans Move\ &To			Presunú&»
menutrans &Top<Tab>^WK			Na&hor<Tab>^WK
menutrans &Bottom<Tab>^WJ		Nado&l<Tab>^WJ
menutrans &Left\ side<Tab>^WH		V&µavo<Tab>^WJ
menutrans &Right\ side<Tab>^WL		Vprav&o<Tab>^WL
menutrans Ne&xt<Tab>^Ww			Ï&al¹ie<Tab>^Ww
menutrans P&revious<Tab>^WW		&Predchádzajúce<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		Rovnaká\ vý¹&ka<Tab>^W=
menutrans &Max\ Height<Tab>^W_		&Maximálna\ vý¹ka<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		Minimálna\ vý&¹ka<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		Maximálna\ ¹írka<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Minimálna ¹irka<Tab>^W1\|
menutrans Rotate\ &Up<Tab>^WR		Rotova&»\ nahor<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Rotova»\ na&dol<Tab>^Wr
menutrans Select\ Fo&nt\.\.\.		Vy&bra»\ písmo\.\.\.

" The popup menu
menutrans &Undo			&Spä»
menutrans Cu&t			&Vystrihnú»
menutrans &Copy			&Kopírova»
menutrans &Paste		V&lo¾i»
menutrans &Delete		V&ymaza»
menutrans Select\ Blockwise	Vybra»\ blokovo
menutrans Select\ &Word		Vybra»\ sl&ovo
menutrans Select\ &Line		Vybra»\ &riadok
menutrans Select\ &Block	Vybra»\ &blok
menutrans Select\ &All		Vybra»\ v¹&etko

" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		Otvori» súbor
    tmenu ToolBar.Save		Ulo¾i» súbor
    tmenu ToolBar.SaveAll	Ulo¾i» v¹etky
    tmenu ToolBar.Print		Tlaè
    tmenu ToolBar.Undo		Spä»
    tmenu ToolBar.Redo		Opakova»
    tmenu ToolBar.Cut		Vystrihnú»
    tmenu ToolBar.Copy		Kopírova»
    tmenu ToolBar.Paste		Vlo¾i»
    tmenu ToolBar.Find		Nájs»...
    tmenu ToolBar.FindNext	Nájs» ïal¹ie
    tmenu ToolBar.FindPrev	Nájs» predchádzajúce
    tmenu ToolBar.Replace	Nahradi»...
    if 0	" disabled; These are in the Windows menu
      tmenu ToolBar.New		Nové okno
      tmenu ToolBar.WinSplit	Rozdeli» okno
      tmenu ToolBar.WinMax	Maximalizova» okno
      tmenu ToolBar.WinMin	Minimalizova» okno
      tmenu ToolBar.WinVSplit	Rozdeli» okno vertikálne
      tmenu ToolBar.WinMaxWidth	Maximalizova» ¹írku okna
      tmenu ToolBar.WinMinWidth	Minimalizova» ¹írku okna
      tmenu ToolBar.WinClose	Zatvori» okno
    endif
    tmenu ToolBar.LoadSesn	Naèíta» sedenie
    tmenu ToolBar.SaveSesn	Ulo¾i» sedenie
    tmenu ToolBar.RunScript	Spusti» skript
    tmenu ToolBar.Make		Spusti» make
    tmenu ToolBar.Shell		Spusti» ¹el
    tmenu ToolBar.RunCtags	Spusti» ctags
    tmenu ToolBar.TagJump	Skoèi» na tag pod kurzorom
    tmenu ToolBar.Help		Pomocník
    tmenu ToolBar.FindHelp	Nájs» pomocníka k...
  endfun
endif

" Syntax menu
menutrans &Syntax		&Syntax
menutrans Set\ '&syntax'\ only	Nastavi»\ iba\ 'syntax'
menutrans Set\ '&filetype'\ too	Nastavi»\ aj\ 'filetype'
menutrans &Off			&Vypnú»
menutrans &Manual		&Ruène
menutrans A&utomatic		A&utomaticky
" menutrans o&n\ (this\ file)	&Zapnú»\ (pre\ tento\ súbor)
" menutrans o&ff\ (this\ file)	Vyp&nú»\ (pre\ tento\ súbor )
menutrans on/off\ for\ &This\ file	Zapnú»/vypnú»\ pre\ &tento\ súbor
menutrans Co&lor\ test		Test\ &farieb
menutrans &Highlight\ test	&Test\ zvýrazòovania
menutrans &Convert\ to\ HTML	&Previes»\ do\ HTML

let &cpo = s:keepcpo
unlet s:keepcpo
