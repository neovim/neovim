" Menu Translations:	Nederlands
" Maintainer:		Bram Moolenaar
" Last Change:	2012 May 01

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
menutrans &Help			&Help
menutrans &Overview<Tab><F1>	&Overzicht<Tab><F1>
menutrans &User\ Manual		Gebruikershandleiding
menutrans &How-to\ links	&Hoe-doe-ik\ lijst
"menutrans &GUI			&GUI
menutrans &Credits		&Met\ dank\ aan
menutrans Co&pying		&Copyright
menutrans &Sponsor/Register	&Sponsor/Registreer
menutrans O&rphans		&Weeskinderen
menutrans &Version		&Versie
menutrans &About		&Introductiescherm

" File menu
menutrans &File				&Bestand
menutrans &Open\.\.\.<Tab>:e		&Openen\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	In\ nieuw\ &Venster\ openen\.\.\.<Tab>:sp
menutrans &New<Tab>:enew		&Nieuw<Tab>:enew
menutrans &Close<Tab>:close		&Sluiten<Tab>:close
menutrans &Save<Tab>:w			&Bewaren<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Bewaren\ als\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	Toon\ diff\ met\.\.\.
menutrans Split\ Patched\ &By\.\.\.	Toon\ gewijzigd\ door\.\.\.
menutrans &Print			Af&drukken
menutrans Sa&ve-Exit<Tab>:wqa		Bewaren\ en\ Afsluiten<Tab>:wqa
menutrans E&xit<Tab>:qa			&Afsluiten<Tab>:qa

" Edit menu
menutrans &Edit				Be&werken
menutrans &Undo<Tab>u			Terug<Tab>u
menutrans &Redo<Tab>^R			Voo&ruit<Tab>^R
menutrans Rep&eat<Tab>\.		&Herhalen<Tab>\.
menutrans Cu&t<Tab>"+x			&Knippen<Tab>"+x
menutrans &Copy<Tab>"+y			K&opiëeren<Tab>"+y
menutrans &Paste<Tab>"+gP		Plakken<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Ervoor\ invoegen<Tab>[p
menutrans Put\ &After<Tab>]p		Erachter\ invoegen<Tab>]p
menutrans &Select\ all<Tab>ggVG		Alles\ &Markeren<Tab>ggVG
menutrans &Find\.\.\.			&Zoeken\.\.\.
menutrans &Find<Tab>/			&Zoeken<Tab>/
menutrans Find\ and\ Rep&lace\.\.\.	Zoeken\ en\ &Vervangen\.\.\.
menutrans Find\ and\ Rep&lace<Tab>:%s	Zoeken\ en\ &Vervangen<Tab>:%s
menutrans Find\ and\ Rep&lace		Zoeken\ en\ &Vervangen
menutrans Find\ and\ Rep&lace<Tab>:s	Zoeken\ en\ &Vervangen<Tab>:s
menutrans Settings\ &Window		Optievenster
menutrans &Global\ Settings		Globale\ Opties
menutrans F&ile\ Settings		Bestandopties
menutrans C&olor\ Scheme		Kleurenschema
menutrans &Keymap			Toetsenbordindeling

" Edit.Global Settings
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Flip\ Patroonkleuring<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!	Flip\ Negeren\ hoofd/kleine\ letters<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!	Flip\ Showmatch<Tab>:set\ sm!
menutrans &Context\ lines		Contextregels
menutrans &Virtual\ Edit		Virtueel\ positioneren
menutrans Never				Nooit
menutrans Block\ Selection		Bij\ Blokselectie
menutrans Insert\ mode			In\ Invoegmode
menutrans Block\ and\ Insert		Bij\ Blokselectie\ en\ Invoegmode
menutrans Always			Altijd
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	Flip\ Invoegmode<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!	Flip\ Vi\ Compatibiliteit<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.		Zoekpad\.\.\.
menutrans Ta&g\ Files\.\.\.		Tag\ Bestanden\.\.\.
menutrans Toggle\ &Toolbar		Toon/verberg\ Knoppenbalk
menutrans Toggle\ &Bottom\ Scrollbar	Toon/verberg\ onderste\ schuifbalk
menutrans Toggle\ &Left\ Scrollbar	Toon/verberg\ linker\ schuifbalk
menutrans Toggle\ &Right\ Scrollbar	Toon/verberg\ rechter\ schuifbalk
menutrans None				Geen

" Edit.File Settings
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	Flip\ regelnummers<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Flip\ list\ mode<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Flip\ regelafbreken<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Flip\ afbreken\ op\ woordgrens<tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		Flip\ tabexpansie<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Flip\ automatisch\ indenteren<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Flip\ C-indenteren<Tab>:set\ cin!
menutrans Te&xt\ Width\.\.\.				Tekstbreedte\.\.\.
menutrans &File\ Format\.\.\.				Bestandsformaat\.\.\.

" Tools menu
menutrans &Tools			&Gereedschap
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Spring\ naar\ Tag<Tab>g^]
menutrans Jump\ &back<Tab>^T		Spring\ &Terug<Tab>^T
menutrans Build\ &Tags\ File		Genereer\ &Tagsbestand
menutrans &Make<Tab>:make		&Make\ uitvoeren<Tab>:make
menutrans &List\ Errors<Tab>:cl		&Foutenlijst<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	&Berichtenlijst<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		Volgende\ Fout<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	Vorige\ Fout<Tab>:cp
menutrans &Older\ List<Tab>:cold	&Oudere\ Lijst<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	&Nieuwere\ Lijst<Tab>:cnew
menutrans Error\ &Window		Foutenvenster
menutrans &Update<Tab>:cwin		&Aanpassen<Tab>:cwin
menutrans &Open<Tab>:copen		&Openen<Tab>:copen
menutrans &Close<Tab>:cclose		&Sluiten<Tab>:cclose
menutrans &Convert\ to\ HEX<Tab>:%!xxd	Converteer\ naar\ HEX<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r	Converteer\ terug<Tab>:%!xxd\ -r
menutrans &Set\ Compiler		Kies\ Compiler

" Tools.Folding
menutrans &Enable/Disable\ folds<Tab>zi	Flip\ tonen\ folds<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv	Toon\ cursorregel<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx	Toon\ alleen\ cursorregel<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm	Sluit\ meer\ folds<Tab>zm
menutrans &Close\ all\ folds<Tab>zM	Sluit\ alle\ folds<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr	Open\ meer\ folds<Tab>zr
menutrans &Open\ all\ folds<Tab>zR	Open\ alle\ folds<Tab>zR
menutrans Fold\ Met&hod			Foldwijze
menutrans M&anual			Handmatig
menutrans I&ndent			Inspringing
menutrans E&xpression			Expressie
menutrans S&yntax			Syntax
menutrans &Diff				Verschillen
menutrans Ma&rker			Markeringen
menutrans Create\ &Fold<Tab>zf		maak\ Fold<Tab>zf
menutrans &Delete\ Fold<Tab>zd		verwijder\ Fold<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD	verwijder\ alle\ Folds<Tab>zD
menutrans Fold\ column\ &width		Fold\ kolom\ breedte

" Tools.Diff
menutrans &Update		Verversen
menutrans &Get\ Block		Blok\ ophalen\ van\ ander\ venster
menutrans &Put\ Block		Blok\ naar\ ander\ venster

" Names for buffer menu.
menutrans &Buffers		&Buffer
menutrans &Refresh\ menu	Ververs\ menu
menutrans &Delete		Wissen
menutrans &Alternate		Vorige
menutrans &Next			Vooruit
menutrans &Previous		Achteruit

" Window menu
menutrans &Window			&Venster
menutrans &New<Tab>^Wn			&Nieuw<Tab>^Wn
menutrans S&plit<Tab>^Ws		Splitsen<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	Splits\ naar\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Splits\ &Vertikaal<Tab>^Wv
menutrans Split\ File\ E&xplorer	Splits\ Bestandverkenner
menutrans &Close<Tab>^Wc		&Sluiten<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	&Sluit\ alle\ andere<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			Volgende<Tab>^Ww
menutrans P&revious<Tab>^WW		&Vorige<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Gelijke\ afmetingen<Tab>^W=
menutrans &Max\ Height<Tab>^W_		&Maximale\ hoogte<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		Mi&nimale\ hoogte<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		Maximale\ breedte<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Minimale\ breedte<Tab>^W1\|
menutrans Move\ &To			Verplaats\ naar
menutrans &Top<Tab>^WK			Bovenkant<Tab>^WK
menutrans &Bottom<Tab>^WJ		Onderkant<Tab>^WJ
menutrans &Left\ side<Tab>^WH		Linkerkant<Tab>^WH
menutrans &Right\ side<Tab>^WL		Rechterkant<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		Roteren\ naar\ &boven<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Roteren\ naar\ &onder<Tab>^Wr
menutrans Select\ Fo&nt\.\.\.		Selecteer\ font\.\.\.

" The popup menu
menutrans &Undo			&Terug
menutrans Cu&t			Knip
menutrans &Copy			&Kopiëer
menutrans &Paste		&Plak
menutrans &Delete		&Wissen
menutrans Select\ Blockwise	Selecteer\ per\ Rechthoek
menutrans Select\ &Word		Selecteer\ een\ &Woord
menutrans Select\ &Line		Selecteer\ een\ &Regel
menutrans Select\ &Block	Selecteer\ een\ Recht&hoek
menutrans Select\ &All		Selecteer\ &Alles

" The GUI toolbar (for Win32 or GTK)
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		Bestand openen
    tmenu ToolBar.Save		Bestand opslaan
    tmenu ToolBar.SaveAll	Alle bestanden opslaan
    tmenu ToolBar.Print		afdrukken
    tmenu ToolBar.Undo		terug
    tmenu ToolBar.Redo		vooruit
    tmenu ToolBar.Cut		knippen
    tmenu ToolBar.Copy		Kopiëren
    tmenu ToolBar.Paste		Plakken
    tmenu ToolBar.Find		Zoeken...
    tmenu ToolBar.FindNext	Zoek volgende
    tmenu ToolBar.FindPrev	Zoek vorige
    tmenu ToolBar.Replace	Zoek en vervang...
    tmenu ToolBar.LoadSesn	Sessie Laden
    tmenu ToolBar.SaveSesn	Sessie opslaan
    tmenu ToolBar.RunScript	Vim script uitvoeren
    tmenu ToolBar.Make		Make uitvoeren
    tmenu ToolBar.Shell		Shell starten
    tmenu ToolBar.RunCtags	Tags bestand genereren
    tmenu ToolBar.TagJump	Spring naar tag
    tmenu ToolBar.Help		Help!
    tmenu ToolBar.FindHelp	Help vinden...
  endfun
endif

" Syntax menu
menutrans &Syntax		&Syntax
menutrans &Show\ filetypes\ in\ menu  Toon\ filetypes\ in\ menu
menutrans Set\ '&syntax'\ only	Alleen\ 'syntax'\ wijzigen
menutrans Set\ '&filetype'\ too	Ook\ 'filetype'\ wijzigen
menutrans &Off			&Uit
menutrans &Manual		&Handmatig
menutrans A&utomatic		A&utomatisch
menutrans on/off\ for\ &This\ file	Aan/Uit\ voor\ dit\ Bestand
menutrans Co&lor\ test		Test\ de\ &Kleuren
menutrans &Highlight\ test	Test\ de\ Markeringen
menutrans &Convert\ to\ HTML	Converteren\ naar\ &HTML
menutrans &Show\ individual\ choices	Toon\ elke\ keuze

" dialog texts
let menutrans_no_file = "[Geen Bestand]"
let menutrans_help_dialog = "Typ een commando of woord om help voor te vinden:\n\nVoeg i_ in voor Input mode commandos (bijv. i_CTRL-X)\nVoeg c_ in voor een commando-regel edit commando (bijv. c_<Del>)\nVoeg ' in \voor een optie naam (bijv. 'shiftwidth')"
let g:menutrans_path_dialog = "Typ het zoekpad voor bestanden.\nGebruik commas tussen de padnamen."
let g:menutrans_tags_dialog = "Typ namen van tag bestanden.\nGebruik commas tussen de namen."
let g:menutrans_textwidth_dialog = "Typ de nieuwe tekst breedte (0 om formatteren uit the schakelen): "
let g:menutrans_fileformat_dialog = "Selecteer formaat voor het schrijven van het bestand"

let &cpo = s:keepcpo
unlet s:keepcpo
