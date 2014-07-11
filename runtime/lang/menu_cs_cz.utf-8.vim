" Menu Translations:    Czech (UTF-8)
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

scriptencoding utf-8

" {{{ File menu
menutrans &File				&Soubor
menutrans &Open\.\.\.<Tab>:e		&Otevřít\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Otevřít\ v\ no&vém\ okně\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	Otevřít\ tab\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew		&Nový<Tab>:enew
menutrans &Close<Tab>:close		&Zavřít<Tab>:close
menutrans &Save<Tab>:w			&Uložit<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Uložit\ &jako\.\.\.<Tab>:sav
if has("printer") || has("unix")
   menutrans &Print			&Tisk
endif
menutrans Sa&ve-Exit<Tab>:wqa		U&ložit\ a\ ukončit<Tab>:wqa
menutrans E&xit<Tab>:qa			&Ukončit<Tab>:qa

if has("diff")
   menutrans Split\ &Diff\ with\.\.\.	Rozdělit\ okno\ -\ &Diff\.\.\.
   menutrans Split\ Patched\ &By\.\.\.	Rozdělit\ okno\ -\ &Patch\.\.\.
endif
" }}}

" {{{ Edit menu
menutrans &Edit				Úpr&avy
menutrans &Undo<Tab>u			&Zpět<Tab>u
menutrans &Redo<Tab>^R			Z&rušit\ vrácení<Tab>^R
menutrans Rep&eat<Tab>\.		&Opakovat<Tab>\.
menutrans Cu&t<Tab>"+x			&Vyříznout<Tab>"+x
menutrans &Copy<Tab>"+y			&Kopírovat<Tab>"+y
menutrans &Paste<Tab>"+gP		V&ložit<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Vložit\ &před<Tab>[p
menutrans Put\ &After<Tab>]p		Vloži&t\ za<Tab>]p
if has("win32") || has("win16")
   menutrans &Delete<Tab>x			&Smazat<Tab>x
endif
menutrans &Select\ All<Tab>ggVG		Vy&brat\ vše<Tab>ggVG
if has("win32")  || has("win16") || has("gui_gtk") || has("gui_kde") || has("gui_motif")
   menutrans &Find\.\.\.			&Hledat\.\.\.
   menutrans Find\ and\ Rep&lace\.\.\.	&Nahradit\.\.\.
else
   menutrans Find<Tab>/ &Hledat<Tab>/
   menutrans Find\ and\ Rep&lace<Tab>:%s  &Nahradit<Tab>:%s
   menutrans Find\ and\ Rep&lace<Tab>:s   &Nahradit<Tab>:s
endif
menutrans Settings\ &Window		Nastav&ení\ okna
" {{{2 Edit -1
menutrans Startup\ &Settings  Počáteční\ &nastavení
menutrans &Global\ Settings				&Globální\ nastavení
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	&Přepnout\ zvýraznění\ vzoru<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		Přepnout\ ignorování\ &VERZÁLEK<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		Přepnout\ &Showmatch\ \{\(\[\])\}<Tab>:set\ sm!
menutrans &Context\ lines				Zobrazit\ konte&xt\ kurzoru
menutrans &Virtual\ Edit				Virtuální\ p&ozice\ kurzoru
menutrans Never						Nikdy
menutrans Block\ Selection				Výběr\ Bloku
menutrans Insert\ mode					Insert\ mód
menutrans Block\ and\ Insert				Blok\ a\ Insert
menutrans Always					Vždycky
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		Přepnout\ Insert\ mó&d<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!		Přepnout\ kompatibilní\ režim\ s\ 'vi'<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.				Nastavit\ &cestu\ k\ prohledávání\.\.\.
menutrans Ta&g\ Files\.\.\.				Ta&g\ soubory\.\.\.
menutrans Toggle\ &Toolbar				Přepnout\ &Toolbar
menutrans Toggle\ &Bottom\ Scrollbar			Př&epnout\ dolní\ rolovací\ lištu
menutrans Toggle\ &Left\ Scrollbar			Přepnout\ &levou\ rolovací\ lištu
menutrans Toggle\ &Right\ Scrollbar			Přepnout\ p&ravou\ rolovací\ lištu
" {{{2 Edit -2
menutrans F&ile\ Settings				Nastavení\ so&uboru
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	Přepnout\ číslování\ řá&dků<Tab>:set\ nu!
menutrans Toggle\ relati&ve\ Line\ Numbering<Tab>:set\ rnu! Přepnout\ relativní\ číslování\ řá&dků<Tab>:set\ rnu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Přepnout\ &List\ mód<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Přepnout\ zala&mování\ řádků<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Přepnout\ zl&om\ ve\ slově<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		Přepnout\ &expand-tab<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Přepnout\ &auto-indent<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Přepnout\ &C-indenting<Tab>:set\ cin!
menutrans &Shiftwidth					Nastav&it\ šířku\ od&sazení
menutrans Soft\ &Tabstop				Nastavit\ Soft\ &Tabstop
menutrans Te&xt\ Width\.\.\.				Šířka\ te&xtu\.\.\.
menutrans &File\ Format\.\.\.				&Formát\ souboru\.\.\.
" {{{2 Edit -3
menutrans C&olor\ Scheme		Barevné\ s&chéma
menutrans &Keymap			Klávesová\ m&apa
if has("win32") || has("win16") || has("gui_motif") || has("gui_gtk") || has("gui_kde") || has("gui_photon") || has("gui_mac")
   menutrans Select\ Fo&nt\.\.\.		Vybrat\ pís&mo\.\.\.
endif
" }}}1

" {{{ Programming menu
menutrans &Tools			Nást&roje
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Skočit\ na\ tag<Tab>g^]
menutrans Jump\ &back<Tab>^T		Skočit\ &zpět<Tab>^T
menutrans Build\ &Tags\ File		&Vytvořit\ soubor\ tagů

if has("spell")
   menutrans &Spelling			&Kontrola\ pravopisu
   menutrans &Spell\ Check\ On		&Zapnout\ kontrolu\ pravopisu
   menutrans Spell\ Check\ &Off		&Vypnout \kontrolu\ pravopisu
   menutrans To\ &Next\ error<Tab>]s	&Další\ chyba<Tab>]s
   menutrans To\ &Previous\ error<Tab>[s	&Předchozí\ chyba<Tab>[s
   menutrans Suggest\ &Corrections<Tab>z=	&Navrhnout\ opravy<Tab>z=
   menutrans &Repeat\ correction<Tab>:spellrepall	Zopakovat\ &opravu<Tab>:spellrepall
   menutrans Set\ language\ to\ "en"	Nastavit\ jazyk\ na\ "en"
   menutrans Set\ language\ to\ "en_au"	Nastavit\ jazyk\ na\ "en_au"
   menutrans Set\ language\ to\ "en_ca"	Nastavit\ jazyk\ na\ "en_ca"
   menutrans Set\ language\ to\ "en_gb"	Nastavit\ jazyk\ na\ "en_gb"
   menutrans Set\ language\ to\ "en_nz"	Nastavit\ jazyk\ na\ "en_nz"
   menutrans Set\ language\ to\ "en_us"	Nastavit\ jazyk\ na\ "en_us"
   menutrans &Find\ More\ Languages	Nalézt\ další\ &jazyky
   let g:menutrans_set_lang_to = "Nastavit jazyk na"
endif

if has("Folding")   
   menutrans &Folding			&Skládání
   menutrans &Enable/Disable\ folds<Tab>zi &Ano/Ne<Tab>zi
   menutrans &View\ Cursor\ Line<Tab>zv	Zobrazit\ řádek\ &kurzoru<Tab>zv
   menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx		Zobrazit\ &pouze\ řádek\ kurzoru\ <Tab>zMzx
   menutrans C&lose\ more\ folds<Tab>zm	Složit\ &jednu\ úroveň\ skladů<Tab>zm
   menutrans &Close\ all\ folds<Tab>zM	Složit\ všechny\ sklady<Tab>zM
   menutrans O&pen\ more\ folds<Tab>zr	Přidat\ jednu\ úroveň\ skladů<Tab>zr
   menutrans &Open\ all\ folds<Tab>zR	&Otevřít\ všechny\ sklady<Tab>zR
   menutrans Fold\ Met&hod			&Metoda\ skládání
   menutrans M&anual			&Ručně
   menutrans I&ndent			&Odsazení
   menutrans E&xpression	&Výraz
   menutrans S&yntax			&Syntaxe
   menutrans &Diff			&Rozdíly
   menutrans Ma&rker			&Značky
   menutrans Create\ &Fold<Tab>zf		Vytvořit\ &sklad<Tab>zf
   menutrans &Delete\ Fold<Tab>zd		Vymazat\ skla&d<Tab>zd
   menutrans Delete\ &All\ Folds<Tab>zD	Vymazat\ všechny\ sklady<Tab>zD
   menutrans Fold\ col&umn\ width		Sloupec\ zob&razení\ skladů
endif

if has("diff")
   menutrans &Update			&Obnovit
   menutrans &Get\ Block			&Sejmout\ Blok
   menutrans &Put\ Block			&Vložit\ Blok
endif

menutrans &Make<Tab>:make		&Make<Tab>:make
menutrans &List\ Errors<Tab>:cl		Výpis\ &chyb<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	Výp&is\ zpráv<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		Další\ ch&yba<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	&Předchozí\ chyba<Tab>:cp
menutrans &Older\ List<Tab>:cold	Sta&rší\ seznam<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	N&ovější\ seznam<Tab>:cnew
menutrans Error\ &Window		Chybové\ o&kno
menutrans SeT\ Compiler			Nas&tavení\ kompilátoru
menutrans &Update<Tab>:cwin		O&bnovit<Tab>:cwin
menutrans &Open<Tab>:copen		&Otevřít<Tab>:copen
menutrans &Close<Tab>:cclose		&Zavřít<Tab>:cclose
menutrans Se&T\ Compiler		N&astavit\ kompilátor

menutrans &Convert\ to\ HEX<Tab>:%!xxd	Převést\ do\ šestnáctkového\ formát&u<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r Př&evést\ zpět<Tab>:%!xxd\ -r
" }}}

" {{{ Syntax menu
menutrans &Syntax		Synta&xe
menutrans Set\ '&syntax'\ only	Nastavit\ pouze\ 'synta&x'
menutrans Set\ '&filetype'\ too	Nastavit\ také\ '&filetype'
menutrans &Off			&Vypnout
menutrans &Manual		&Ručně
menutrans A&utomatic		A&utomaticky
menutrans on/off\ for\ &This\ file	&Přepnout\ (pro\ tento\ soubor)
menutrans o&ff\ (this\ file)	vyp&nout\ (pro\ tento\ soubor)
menutrans Co&lor\ test		Test\ &barev
menutrans &Highlight\ test	&Test\ zvýrazňování
menutrans &Convert\ to\ HTML	Převést\ &do\ HTML
menutrans &Show\ filetypes\ in\ menu	&Zobrazit\ výběr\ možností
" }}}

" {{{ Menu Buffers
menutrans &Buffers		&Buffery
menutrans &Refresh\ menu	&Obnovit\ menu
menutrans &Delete		Z&rušit
menutrans &Alternate		&Změnit
menutrans &Next			&Další
menutrans &Previous		&Předchozí
" }}}

" {{{ Menu Window
menutrans &Window			&Okna
menutrans &New<Tab>^Wn			&Nové<Tab>^Wn
menutrans S&plit<Tab>^Ws		&Rozdělit<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	Ro&zdělit\ na\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Rozdělit\ &vertikálně<Tab>^Wv
menutrans Split\ File\ E&xplorer	Rozdělit\ -\ File\ E&xplorer
menutrans Move\ &To			&Přesun
menutrans &Top<Tab>^WK			&Nahoru<Tab>^WK
menutrans &Bottom<Tab>^WJ		&Dolu<Tab>^WJ
menutrans &Left\ side<Tab>^WH		&Vlevo<Tab>^WH
menutrans &Right\ side<Tab>^WL		Vp&ravo<Tab>^WL

menutrans &Close<Tab>^Wc		Zavří&t<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Zavřít\ &ostatní<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			&Další<Tab>^Ww
menutrans P&revious<Tab>^WW		&Předchozí<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Stejná\ výška<Tab>^W=
menutrans &Max\ Height<Tab>^W_		Maximální\ výš&ka<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		M&inimální\ výška<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		&Maximální\ šířka<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Minimální\ šířk&a<Tab>^W1\|
menutrans Rotate\ &Up<Tab>^WR		Rotovat\ na&horu<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Rotovat\ &dolů<Tab>^Wr

" {{{ Help menu
menutrans &Help			&Nápověda
menutrans &Overview<Tab><F1>	&Přehled<Tab><F1>
menutrans &User\ Manual		&Uživatelský\ Manuál
menutrans &How-to\ links	Ho&wto
menutrans &GUI			&Grafické\ rozhraní
menutrans &Credits		&Autoři
menutrans Co&pying		&Licenční\ politika
menutrans &Sponsor/Register	Sponzorování/&Registrace
menutrans &Find\.\.\.		&Hledat\.\.\.
menutrans O&rphans		O&siřelé\ děti
menutrans &Version		&Verze
menutrans &About		&O\ aplikaci
" }}}

" {{{ The popup menu
menutrans &Undo			&Zpět
menutrans Cu&t			&Vyříznout
menutrans &Copy			&Kopírovat
menutrans &Paste		&Vložit
menutrans &Delete		&Smazat
menutrans Select\ Blockwise	Vybrat\ blokově
menutrans Select\ &Word		Vybrat\ &slovo
menutrans Select\ Pa&ragraph Vybrat\ &odstavec
menutrans Select\ &Sentence   Vybrat\ vě&tu
menutrans Select\ &Line		Vybrat\ &řádek
menutrans Select\ &Block	Vybrat\ &blok
menutrans Select\ &All		Vybrat\ &vše
" }}}

" {{{ The GUI toolbar
if has("toolbar")
   if exists("*Do_toolbar_tmenu")
      delfun Do_toolbar_tmenu
   endif
   fun Do_toolbar_tmenu()
      tmenu ToolBar.Open		Otevřít soubor
      tmenu ToolBar.Save		Uložit soubor
      tmenu ToolBar.SaveAll		Uložit všechny soubory
      if has("printer") || has("unix")
         tmenu ToolBar.Print		Tisk
      endif
      tmenu ToolBar.Undo		Zpět
      tmenu ToolBar.Redo		Zrušit vrácení
      tmenu ToolBar.Cut		Vyříznout
      tmenu ToolBar.Copy		Kopírovat
      tmenu ToolBar.Paste		Vložit
      tmenu ToolBar.Find		Hledat...
      tmenu ToolBar.FindNext	Hledat další
      tmenu ToolBar.FindPrev	Hledat předchozí
      tmenu ToolBar.Replace		Nahradit...
      if 0	" disabled; These are in the Windows menu
         tmenu ToolBar.New		Nové okno
         tmenu ToolBar.WinSplit	Rozdělit okno
         tmenu ToolBar.WinMax		Maximalizovat okno
         tmenu ToolBar.WinMin		Minimalizovat okno
         tmenu ToolBar.WinClose	Zavřít okno
      endif
      tmenu ToolBar.LoadSesn	Načíst sezení
      tmenu ToolBar.SaveSesn	Uložit sezení
      tmenu ToolBar.RunScript	Spustit skript
      tmenu ToolBar.Make		Spustit make
      tmenu ToolBar.Shell		Spustit shell
      tmenu ToolBar.RunCtags	Spustit ctags
      tmenu ToolBar.TagJump		Skočit na tag pod kurzorem
      tmenu ToolBar.Help		Nápověda
      tmenu ToolBar.FindHelp	Hledat nápovědu k...
   endfun
endif
" }}}

" {{{ DIALOG TEXTS
let g:menutrans_no_file = "[Žádný soubor]"
let g:menutrans_help_dialog = "Zadejte hledaný příkaz nebo slovo:\n\n\tPřidejte i_ pro příkazy vkládacího režimu (např. i_CTRL-X)\n\tPřidejte c_ pro příkazy příkazové řádky (např. c_<Del>)\n\tPřidejte ' pro jméno volby (např. 'shiftwidth')"
let g:menutrans_path_dialog = "Zadejte cesty pro vyhledávání souborů. Jednotlivé cesty oddělte čárkou"
let g:menutrans_tags_dialog = "Zadejte jména souborů s tagy. Jména oddělte čárkami."
let g:menutrans_textwidth_dialog = "Zadejte délku řádku (0 pro zakázání formátování):"
let g:menutrans_fileformat_dialog = "Vyberte typ konce řádků"
" }}}" 

let &cpo = s:keepcpo
unlet s:keepcpo



" vim:set foldmethod=marker expandtab tabstop=3 shiftwidth=3:
