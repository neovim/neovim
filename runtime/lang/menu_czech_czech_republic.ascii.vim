" Menu Translations:    Czech (latin1 - w/o diacritics)
" Maintainer:           Jiri Sedlak <jiri_sedlak@users.sourceforge.net>
" Previous maintainer:  Jiri Brezina
" Based on:             menu.vim (2012-10-21)

" Quit when menu translations have already been done.
if exists("did_menu_trans")
   finish
endif

let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding latin1

" {{{ File menu
menutrans &File				&Soubor
menutrans &Open\.\.\.<Tab>:e		&Otevrit\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Otevrit\ v\ no&vem\ okne\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	Otevrit\ tab\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew		&Novy<Tab>:enew
menutrans &Close<Tab>:close		&Zavrit<Tab>:close
menutrans &Save<Tab>:w			&Ulozit<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Ulozit\ &jako\.\.\.<Tab>:sav
if has("printer") || has("unix")
   menutrans &Print			&Tisk
endif
menutrans Sa&ve-Exit<Tab>:wqa		U&lozit\ a\ ukoncit<Tab>:wqa
menutrans E&xit<Tab>:qa			&Ukoncit<Tab>:qa

if has("diff")
   menutrans Split\ &Diff\ with\.\.\.	Rozdelit\ okno\ -\ &Diff\.\.\.
   menutrans Split\ Patched\ &By\.\.\.	Rozdelit\ okno\ -\ &Patch\.\.\.
endif
" }}}

" {{{ Edit menu
menutrans &Edit				Upr&avy
menutrans &Undo<Tab>u			&Zpet<Tab>u
menutrans &Redo<Tab>^R			Z&rusit\ vraceni<Tab>^R
menutrans Rep&eat<Tab>\.		&Opakovat<Tab>\.
menutrans Cu&t<Tab>"+x			&Vyriznout<Tab>"+x
menutrans &Copy<Tab>"+y			&Kopirovat<Tab>"+y
menutrans &Paste<Tab>"+gP		V&lozit<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Vlozit\ &pred<Tab>[p
menutrans Put\ &After<Tab>]p		Vlozi&t\ za<Tab>]p
if has("win32") || has("win16")
   menutrans &Delete<Tab>x			&Smazat<Tab>x
endif
menutrans &Select\ All<Tab>ggVG		Vy&brat\ vse<Tab>ggVG
if has("win32")  || has("win16") || has("gui_gtk") || has("gui_kde") || has("gui_motif")
   menutrans &Find\.\.\.			&Hledat\.\.\.
   menutrans Find\ and\ Rep&lace\.\.\.	&Nahradit\.\.\.
else
   menutrans Find<Tab>/ &Hledat<Tab>/
   menutrans Find\ and\ Rep&lace<Tab>:%s  &Nahradit<Tab>:%s
   menutrans Find\ and\ Rep&lace<Tab>:s   &Nahradit<Tab>:s
endif
menutrans Settings\ &Window		Nastav&eni\ okna
" {{{2 Edit -1
menutrans Startup\ &Settings  Pocatecni\ &nastaveni
menutrans &Global\ Settings				&Globalni\ nastaveni
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	&Prepnout\ zvyrazneni\ vzoru<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		Prepnout\ ignorovani\ &VERZALEK<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		Prepnout\ &Showmatch\ \{\(\[\])\}<Tab>:set\ sm!
menutrans &Context\ lines				Zobrazit\ konte&xt\ kurzoru
menutrans &Virtual\ Edit				Virtualni\ p&ozice\ kurzoru
menutrans Never						Nikdy
menutrans Block\ Selection				Vyber\ Bloku
menutrans Insert\ mode					Insert\ mod
menutrans Block\ and\ Insert				Blok\ a\ Insert
menutrans Always					Vzdycky
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		Prepnout\ Insert\ mo&d<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!		Prepnout\ kompatibilni\ rezim\ s\ 'vi'<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.				Nastavit\ &cestu\ k\ prohledavani\.\.\.
menutrans Ta&g\ Files\.\.\.				Ta&g\ soubory\.\.\.
menutrans Toggle\ &Toolbar				Prepnout\ &Toolbar
menutrans Toggle\ &Bottom\ Scrollbar			Pr&epnout\ dolni\ rolovaci\ listu
menutrans Toggle\ &Left\ Scrollbar			Prepnout\ &levou\ rolovaci\ listu
menutrans Toggle\ &Right\ Scrollbar			Prepnout\ p&ravou\ rolovaci\ listu
" {{{2 Edit -2
menutrans F&ile\ Settings				Nastaveni\ so&uboru
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	Prepnout\ cislovani\ ra&dku<Tab>:set\ nu!
menutrans Toggle\ relati&ve\ Line\ Numbering<Tab>:set\ rnu! Prepnout\ relativni\ cislovani\ ra&dku<Tab>:set\ rnu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Prepnout\ &List\ mod<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Prepnout\ zala&movani\ radku<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Prepnout\ zl&om\ ve\ slove<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		Prepnout\ &expand-tab<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Prepnout\ &auto-indent<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Prepnout\ &C-indenting<Tab>:set\ cin!
menutrans &Shiftwidth					Nastav&it\ sirku\ od&sazeni
menutrans Soft\ &Tabstop				Nastavit\ Soft\ &Tabstop
menutrans Te&xt\ Width\.\.\.				Sirka\ te&xtu\.\.\.
menutrans &File\ Format\.\.\.				&Format\ souboru\.\.\.
" {{{2 Edit -3
menutrans C&olor\ Scheme		Barevne\ s&chema
menutrans &Keymap			Klavesova\ m&apa
if has("win32") || has("win16") || has("gui_motif") || has("gui_gtk") || has("gui_kde") || has("gui_photon") || has("gui_mac")
   menutrans Select\ Fo&nt\.\.\.		Vybrat\ pis&mo\.\.\.
endif
" }}}1

" {{{ Programming menu
menutrans &Tools			Nast&roje
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Skocit\ na\ tag<Tab>g^]
menutrans Jump\ &back<Tab>^T		Skocit\ &zpet<Tab>^T
menutrans Build\ &Tags\ File		&Vytvorit\ soubor\ tagu

if has("spell")
   menutrans &Spelling			&Kontrola\ pravopisu
   menutrans &Spell\ Check\ On		&Zapnout\ kontrolu\ pravopisu
   menutrans Spell\ Check\ &Off		&Vypnout \kontrolu\ pravopisu
   menutrans To\ &Next\ error<Tab>]s	&Dalsi\ chyba<Tab>]s
   menutrans To\ &Previous\ error<Tab>[s	&Predchozi\ chyba<Tab>[s
   menutrans Suggest\ &Corrections<Tab>z=	&Navrhnout\ opravy<Tab>z=
   menutrans &Repeat\ correction<Tab>:spellrepall	Zopakovat\ &opravu<Tab>:spellrepall
   menutrans Set\ language\ to\ "en"	Nastavit\ jazyk\ na\ "en"
   menutrans Set\ language\ to\ "en_au"	Nastavit\ jazyk\ na\ "en_au"
   menutrans Set\ language\ to\ "en_ca"	Nastavit\ jazyk\ na\ "en_ca"
   menutrans Set\ language\ to\ "en_gb"	Nastavit\ jazyk\ na\ "en_gb"
   menutrans Set\ language\ to\ "en_nz"	Nastavit\ jazyk\ na\ "en_nz"
   menutrans Set\ language\ to\ "en_us"	Nastavit\ jazyk\ na\ "en_us"
   menutrans &Find\ More\ Languages	Nalezt\ dalsi\ &jazyky
   let g:menutrans_set_lang_to = "Nastavit jazyk na"
endif

if has("Folding")   
   menutrans &Folding			&Skladani
   menutrans &Enable/Disable\ folds<Tab>zi &Ano/Ne<Tab>zi
   menutrans &View\ Cursor\ Line<Tab>zv	Zobrazit\ radek\ &kurzoru<Tab>zv
   menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx		Zobrazit\ &pouze\ radek\ kurzoru\ <Tab>zMzx
   menutrans C&lose\ more\ folds<Tab>zm	Slozit\ &jednu\ uroven\ skladu<Tab>zm
   menutrans &Close\ all\ folds<Tab>zM	Slozit\ vsechny\ sklady<Tab>zM
   menutrans O&pen\ more\ folds<Tab>zr	Pridat\ jednu\ uroven\ skladu<Tab>zr
   menutrans &Open\ all\ folds<Tab>zR	&Otevrit\ vsechny\ sklady<Tab>zR
   menutrans Fold\ Met&hod			&Metoda\ skladani
   menutrans M&anual			&Rucne
   menutrans I&ndent			&Odsazeni
   menutrans E&xpression	&Vyraz
   menutrans S&yntax			&Syntaxe
   menutrans &Diff			&Rozdily
   menutrans Ma&rker			&Znacky
   menutrans Create\ &Fold<Tab>zf		Vytvorit\ &sklad<Tab>zf
   menutrans &Delete\ Fold<Tab>zd		Vymazat\ skla&d<Tab>zd
   menutrans Delete\ &All\ Folds<Tab>zD	Vymazat\ vsechny\ sklady<Tab>zD
   menutrans Fold\ col&umn\ width		Sloupec\ zob&razeni\ skladu
endif

if has("diff")
   menutrans &Update			&Obnovit
   menutrans &Get\ Block			&Sejmout\ Blok
   menutrans &Put\ Block			&Vlozit\ Blok
endif

menutrans &Make<Tab>:make		&Make<Tab>:make
menutrans &List\ Errors<Tab>:cl		Vypis\ &chyb<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	Vyp&is\ zprav<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		Dalsi\ ch&yba<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	&Predchozi\ chyba<Tab>:cp
menutrans &Older\ List<Tab>:cold	Sta&rsi\ seznam<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	N&ovejsi\ seznam<Tab>:cnew
menutrans Error\ &Window		Chybove\ o&kno
menutrans SeT\ Compiler			Nas&taveni\ kompilatoru
menutrans &Update<Tab>:cwin		O&bnovit<Tab>:cwin
menutrans &Open<Tab>:copen		&Otevrit<Tab>:copen
menutrans &Close<Tab>:cclose		&Zavrit<Tab>:cclose
menutrans Se&T\ Compiler		N&astavit\ kompilator

menutrans &Convert\ to\ HEX<Tab>:%!xxd	Prevest\ do\ sestnactkoveho\ format&u<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r Pr&evest\ zpet<Tab>:%!xxd\ -r
" }}}

" {{{ Syntax menu
menutrans &Syntax		Synta&xe
menutrans Set\ '&syntax'\ only	Nastavit\ pouze\ 'synta&x'
menutrans Set\ '&filetype'\ too	Nastavit\ take\ '&filetype'
menutrans &Off			&Vypnout
menutrans &Manual		&Rucne
menutrans A&utomatic		A&utomaticky
menutrans on/off\ for\ &This\ file	&Prepnout\ (pro\ tento\ soubor)
menutrans o&ff\ (this\ file)	vyp&nout\ (pro\ tento\ soubor)
menutrans Co&lor\ test		Test\ &barev
menutrans &Highlight\ test	&Test\ zvyraznovani
menutrans &Convert\ to\ HTML	Prevest\ &do\ HTML
menutrans &Show\ filetypes\ in\ menu	&Zobrazit\ vyber\ moznosti
" }}}

" {{{ Menu Buffers
menutrans &Buffers		&Buffery
menutrans &Refresh\ menu	&Obnovit\ menu
menutrans &Delete		Z&rusit
menutrans &Alternate		&Zmenit
menutrans &Next			&Dalsi
menutrans &Previous		&Predchozi
" }}}

" {{{ Menu Window
menutrans &Window			&Okna
menutrans &New<Tab>^Wn			&Nove<Tab>^Wn
menutrans S&plit<Tab>^Ws		&Rozdelit<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	Ro&zdelit\ na\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Rozdelit\ &vertikalne<Tab>^Wv
menutrans Split\ File\ E&xplorer	Rozdelit\ -\ File\ E&xplorer
menutrans Move\ &To			&Presun
menutrans &Top<Tab>^WK			&Nahoru<Tab>^WK
menutrans &Bottom<Tab>^WJ		&Dolu<Tab>^WJ
menutrans &Left\ side<Tab>^WH		&Vlevo<Tab>^WH
menutrans &Right\ side<Tab>^WL		Vp&ravo<Tab>^WL

menutrans &Close<Tab>^Wc		Zavri&t<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Zavrit\ &ostatni<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			&Dalsi<Tab>^Ww
menutrans P&revious<Tab>^WW		&Predchozi<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Stejna\ vyska<Tab>^W=
menutrans &Max\ Height<Tab>^W_		Maximalni\ vys&ka<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		M&inimalni\ vyska<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		&Maximalni\ sirka<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Minimalni\ sirk&a<Tab>^W1\|
menutrans Rotate\ &Up<Tab>^WR		Rotovat\ na&horu<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Rotovat\ &dolu<Tab>^Wr

" {{{ Help menu
menutrans &Help			&Napoveda
menutrans &Overview<Tab><F1>	&Prehled<Tab><F1>
menutrans &User\ Manual		&Uzivatelsky\ Manual
menutrans &How-to\ links	Ho&wto
menutrans &GUI			&Graficke\ rozhrani
menutrans &Credits		&Autori
menutrans Co&pying		&Licencni\ politika
menutrans &Sponsor/Register	Sponzorovani/&Registrace
menutrans &Find\.\.\.		&Hledat\.\.\.
menutrans O&rphans		O&sirele\ deti
menutrans &Version		&Verze
menutrans &About		&O\ aplikaci
" }}}

" {{{ The popup menu
menutrans &Undo			&Zpet
menutrans Cu&t			&Vyriznout
menutrans &Copy			&Kopirovat
menutrans &Paste		&Vlozit
menutrans &Delete		&Smazat
menutrans Select\ Blockwise	Vybrat\ blokove
menutrans Select\ &Word		Vybrat\ &slovo
menutrans Select\ Pa&ragraph Vybrat\ &odstavec
menutrans Select\ &Sentence   Vybrat\ ve&tu
menutrans Select\ &Line		Vybrat\ &radek
menutrans Select\ &Block	Vybrat\ &blok
menutrans Select\ &All		Vybrat\ &vse
" }}}

" {{{ The GUI toolbar
if has("toolbar")
   if exists("*Do_toolbar_tmenu")
      delfun Do_toolbar_tmenu
   endif
   fun Do_toolbar_tmenu()
      tmenu ToolBar.Open		Otevrit soubor
      tmenu ToolBar.Save		Ulozit soubor
      tmenu ToolBar.SaveAll		Ulozit vsechny soubory
      if has("printer") || has("unix")
         tmenu ToolBar.Print		Tisk
      endif
      tmenu ToolBar.Undo		Zpet
      tmenu ToolBar.Redo		Zrusit vraceni
      tmenu ToolBar.Cut		Vyriznout
      tmenu ToolBar.Copy		Kopirovat
      tmenu ToolBar.Paste		Vlozit
      tmenu ToolBar.Find		Hledat...
      tmenu ToolBar.FindNext	Hledat dalsi
      tmenu ToolBar.FindPrev	Hledat predchozi
      tmenu ToolBar.Replace		Nahradit...
      if 0	" disabled; These are in the Windows menu
         tmenu ToolBar.New		Nove okno
         tmenu ToolBar.WinSplit	Rozdelit okno
         tmenu ToolBar.WinMax		Maximalizovat okno
         tmenu ToolBar.WinMin		Minimalizovat okno
         tmenu ToolBar.WinClose	Zavrit okno
      endif
      tmenu ToolBar.LoadSesn	Nacist sezeni
      tmenu ToolBar.SaveSesn	Ulozit sezeni
      tmenu ToolBar.RunScript	Spustit skript
      tmenu ToolBar.Make		Spustit make
      tmenu ToolBar.Shell		Spustit shell
      tmenu ToolBar.RunCtags	Spustit ctags
      tmenu ToolBar.TagJump		Skocit na tag pod kurzorem
      tmenu ToolBar.Help		Napoveda
      tmenu ToolBar.FindHelp	Hledat napovedu k...
   endfun
endif
" }}}

" {{{ DIALOG TEXTS
let g:menutrans_no_file = "[Zadny soubor]"
let g:menutrans_help_dialog = "Zadejte hledany prikaz nebo slovo:\n\n\tPridejte i_ pro prikazy vkladaciho rezimu (napr. i_CTRL-X)\n\tPridejte c_ pro prikazy prikazove radky (napr. c_<Del>)\n\tPridejte ' pro jmeno volby (napr. 'shiftwidth')"
let g:menutrans_path_dialog = "Zadejte cesty pro vyhledavani souboru. Jednotlive cesty oddelte carkou"
let g:menutrans_tags_dialog = "Zadejte jmena souboru s tagy. Jmena oddelte carkami."
let g:menutrans_textwidth_dialog = "Zadejte delku radku (0 pro zakazani formatovani):"
let g:menutrans_fileformat_dialog = "Vyberte typ konce radku"
" }}}" 

let &cpo = s:keepcpo
unlet s:keepcpo



" vim:set foldmethod=marker expandtab tabstop=3 shiftwidth=3:
