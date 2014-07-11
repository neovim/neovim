" Menu Translations:	Afrikaas
" Maintainer:		Danie Roux <droux@tuks.co.za>
" Last Change:		2012 May 01

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

" The translations below are in latin1, but they work for cp1252 and
" iso-8859-15 without conversion as well.
if &enc != "cp1252" && &enc != "iso-8859-15"
  scriptencoding latin1
endif


" Help menu
menutrans &Help			&Hulp
menutrans &Overview<Tab><F1>	&Oorsig<Tab><F1>
menutrans &How-to\ links	&How-to\ Indeks
"menutrans &GUI			&GUI
menutrans &Credits		&Met\ dank\ aan
menutrans Co&pying		&Kopiereg
menutrans &Find\.\.\.		&Soek\.\.\.
menutrans &Version		&Weergawe
menutrans &About		&Inleiding\ skerm

" File menu
menutrans &File				&Lêer
menutrans &Open\.\.\.<Tab>:e		&Open\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Maak\ oop\ in\ nuwe\ &venster\.\.\.<Tab>:sp
menutrans &New<Tab>:enew		&Nuut<Tab>:enew
menutrans &Close<Tab>:close		Maak\ &Toe<Tab>:close
menutrans &Save<Tab>:w			&Skryf<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:w	Skryf\ &as\.\.\.<Tab>:w
menutrans &Print			&Druk
menutrans Sa&ve-Exit<Tab>:wqa		Skryf\ en\ verlaat<Tab>:wqa
menutrans E&xit<Tab>:qa			&Verlaat<Tab>:qa

" Edit menu
menutrans &Edit				&Wysig
menutrans &Undo<Tab>u			Terug<Tab>u
menutrans &Redo<Tab>^R			Voo&ruit<Tab>^R
menutrans Rep&eat<Tab>\.			&Herhaal<Tab>\.
menutrans Cu&t<Tab>"+x			&Knip<Tab>"+x
menutrans &Copy<Tab>"+y			&Kopiëer<Tab>"+y
menutrans &Paste<Tab>"+gP		Plak<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Voeg\ &Voor\ in<Tab>[p
menutrans Put\ &After<Tab>]p		Voeg\ A&gter\ in<Tab>]p
menutrans &Select\ all<Tab>ggVG		Kies\ &Alles<Tab>ggVG
menutrans &Find\.\.\.			&Soek\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.			Soek\ en\ Vervang\.\.\.
menutrans Options\.\.\.			Opsies\.\.\.

" Programming menu
menutrans &Tools			&Gereedskap
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Spring\ na\ Etiket<Tab>g^]
menutrans Jump\ &back<Tab>^T		Spring\ &Terug<Tab>^T
menutrans Build\ &Tags\ File		Genereer\ &Etiket\ Leêr
menutrans &Make<Tab>:make		Voer\ &Make\ uit<Tab>:make
menutrans &List\ Errors<Tab>:cl		&Foutlys<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	&Boodskaplys<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		Volgende\ Fout<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	Vorige\ Fout<Tab>:cp
menutrans &Older\ List<Tab>:cold	&Ouer\ Lys<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	&Nuwer\ Lys<Tab>:cnew
menutrans Error\ &Window<Tab>:cwin	Foute\ Venster<Tab>:cwin
menutrans Convert\ to\ HEX<Tab>:%!xxd	Verwissel\ na\ HEX<Tab>:%!xxd
menutrans Convert\ back<Tab>:%!xxd\ -r	Verwissel\ terug<Tab>:%!xxd\ -r

" Names for buffer menu.
menutrans &Buffers	&Buffers
menutrans Refresh	Verfris
menutrans Delete	Verwyder
menutrans Alternate	Vorige
menutrans [No\ File]	[Geen\ Leêr]

" Window menu
menutrans &Window			&Venster
menutrans &New<Tab>^Wn			&Nuut<Tab>^Wn
menutrans S&plit<Tab>^Ws		Ver&deel<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	Verdeel\ N&a\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv		Verdeel\ Vertikaal<Tab>^Wv
menutrans &Close<Tab>^Wc		&Maak\ toe<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Maak\ &Ander\ Toe<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			Volgende<Tab>^Ww
menutrans P&revious<Tab>^WW		&Vorige<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Gelyke\ hoogte<Tab>^W=
menutrans &Max\ Height<Tab>^W_		&Maksimale\ hoogte<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		Mi&nimale\ hoogte<Tab>^W1_
menutrans Max\ Width<Tab>^W\|		Maksimale\ breedte<Tab>^W\|
menutrans Min\ Width<Tab>^W1\|		Minimale\ breedte<Tab>^W1\|
menutrans Rotate\ &Up<Tab>^WR		Roteer\ na\ &bo<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Roteer\ na\ &onder<Tab>^Wr
menutrans Select\ Fo&nt\.\.\.		Kies\ font\.\.\.

" The popup menu
menutrans &Undo			&Terug
menutrans Cu&t			Knip
menutrans &Copy			&Kopiëer
menutrans &Paste		&Plak
menutrans &Delete		&Verwyder
menutrans Select\ Blockwise	Kies\ per\ Blok
menutrans Select\ &Word		Kies\ een\ &Woord
menutrans Select\ &Line		Kies\ een\ &Reël
menutrans Select\ &Block	Kies\ een\ &Blok
menutrans Select\ &All		Kies\ &Alles

" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		Maak leêr oop
    tmenu ToolBar.Save		Skryf leêr
    tmenu ToolBar.SaveAll	Skryf alle leêrs
    tmenu ToolBar.Print		Druk
    tmenu ToolBar.Undo		Terug
    tmenu ToolBar.Redo		Vooruit
    tmenu ToolBar.Cut		Knip
    tmenu ToolBar.Copy		Kopiëer
    tmenu ToolBar.Paste		Plak
    tmenu ToolBar.Find		Soek...
    tmenu ToolBar.FindNext	Soek volgende
    tmenu ToolBar.FindPrev	Soek vorige
    tmenu ToolBar.Replace	Soek en vervang...
    tmenu ToolBar.LoadSesn	Laai sessie
    tmenu ToolBar.SaveSesn	Stoor sessie
    tmenu ToolBar.RunScript	Voer vim skrip uit
    tmenu ToolBar.Make		Voer make uit
    tmenu ToolBar.Shell		Begin dop
    tmenu ToolBar.RunCtags	Genereer etikette
    tmenu ToolBar.TagJump	Spring na etiket
    tmenu ToolBar.Help		Hulp
    tmenu ToolBar.FindHelp	Soek hulp...
  endfun
endif

" Syntax menu
menutrans &Syntax		&Sintaks
menutrans Set\ 'syntax'\ only		Stel\ slegs\ 'syntax'
menutrans Set\ 'filetype'\ too	Verander\ 'filetype'\ ook
menutrans &Off			&Af
menutrans &Manual		&Met\ die\ hand
menutrans A&utomatic		O&utomaties
menutrans o&n\ (this\ file)		Aa&n\ (die\ leêr)
menutrans o&ff\ (this\ file)	&Af\ (die\ leêr)
menutrans Co&lor\ test		Toets\ die\ &kleure
menutrans &Highlight\ test	Toets\ die\ verligting
menutrans &Convert\ to\ HTML	Verwissel\ na\ HTML

let &cpo = s:keepcpo
unlet s:keepcpo
