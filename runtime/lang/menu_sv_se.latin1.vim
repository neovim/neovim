" Menu Translations:    Swedish
" Maintainer:		Johan Svedberg <johan@svedberg.com>
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
menutrans &Help			&Hjälp
menutrans &Overview<Tab><F1>	&Översikt<Tab><F1>
menutrans &User\ Manual		&Användarmanual
menutrans &How-to\ links	&Hur-göra-länkar
menutrans &Find\.\.\.		&Sök\.\.\.
menutrans &Credits		&Tack
menutrans Co&pying		&Kopieringsrättigheter
menutrans &Sponsor/Register	&Sponsra/Registrera
menutrans O&rphans		&Föräldralösa
menutrans &Version		&Version
menutrans &About		&Om

" File menu
menutrans &File				&Arkiv
menutrans &Open\.\.\.<Tab>:e		&Öppna\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Öppna\ i\ splitt-vy\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	Öppna\ flik\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew		&Ny<Tab>:enew
menutrans &Close<Tab>:close		S&täng<Tab>:close
menutrans &Save<Tab>:w			&Spara<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Spara\ som\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	Dela\ diff\ med\.\.\.
menutrans Split\ Patched\ &By\.\.\.	Dela\ lappad\ med\.\.\.
menutrans &Print			Skriv\ &ut
menutrans Sa&ve-Exit<Tab>:wqa		Spara\ &och\ avsluta<Tab>:wqa
menutrans E&xit<Tab>:qa			&Avsluta<Tab>:qa

" Edit menu
menutrans &Edit				&Redigera
menutrans &Undo<Tab>u			&Ångra<Tab>u
menutrans &Redo<Tab>^R			&Gör\ om<Tab>^R
menutrans Rep&eat<Tab>\.		&Repetera<Tab>\.
menutrans Cu&t<Tab>"+x			Klipp\ &ut<Tab>"+x
menutrans &Copy<Tab>"+y			&Kopiera<Tab>"+y
menutrans &Paste<Tab>"+gP		Klistra &in<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Sätt\ in\ &före<Tab>[p
menutrans Put\ &After<Tab>]p		Sätt\ in\ &efter<Tab>]p
menutrans &Select\ All<Tab>ggVG		&Markera\ allt<Tab>ggVG
menutrans &Find\.\.\.			&Sök\.\.\.
menutrans &Find<Tab>/			&Sök<Tab>/
menutrans Find\ and\ Rep&lace\.\.\.	Sök\ och\ ersätt\.\.\.
menutrans Find\ and\ Rep&lace<Tab>:%s	Sök\ och\ ersätt<Tab>:%s
menutrans Find\ and\ Rep&lace		Sök\ och\ ersätt
menutrans Find\ and\ Rep&lace<Tab>:s	Sök\ och\ ersätt<Tab>:s
menutrans Settings\ &Window		In&ställningar
menutrans &Global\ Settings		Gl&obala\ inställningar
menutrans F&ile\ Settings		Fi&linställningar
menutrans C&olor\ Scheme		F&ärgschema
menutrans &Keymap			&Tangentbordsuppsättning

" Edit.Global Settings
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Växla\ mönsterframhävning<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		Växla\ ignorering\ av\ storlek<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		Växla\ matchningsvisning<Tab>:set\ sm!
menutrans &Context\ lines				Sammanhangsrader
menutrans &Virtual\ Edit				Virtuell\ redigering
menutrans Never						Aldrig
menutrans Block\ Selection				Blockval
menutrans Insert\ mode					Infogningsläge
menutrans Block\ and\ Insert				Block\ och\ infogning
menutrans Always					Alltid
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		Växla\ infogningsläge<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!		Växla\ Vi-kompabilitet<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.				Sökväg\.\.\.
menutrans Ta&g\ Files\.\.\.				Taggfiler\.\.\.
menutrans Toggle\ &Toolbar				Växla\ verktygsrad
menutrans Toggle\ &Bottom\ Scrollbar			Växla\ rullningslista\ i\ botten
menutrans Toggle\ &Left\ Scrollbar			Växla\ vänster\ rullningslista
menutrans Toggle\ &Right\ Scrollbar			Växla\ höger\ rullningslista
menutrans None						Ingen

" Edit.File Settings
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	Växla\ radnumrering<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Växla\ listläge<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Växla\ radbrytning<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Växla\ radbrytning\ vid\ ord<tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		Växla\ tab-expandering<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Växla\ auto-indentering<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Växla\ C-indentering<Tab>:set\ cin!
menutrans &Shiftwidth					Shiftbredd
menutrans Soft\ &Tabstop				Mjuk\ tab-stopp
menutrans Te&xt\ Width\.\.\.				Textbredd\.\.\.
menutrans &File\ Format\.\.\.				Filformat\.\.\.

" Tools menu
menutrans &Tools			&Verktyg
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Hoppa\ till\ den\ här\ taggen<Tab>g^]
menutrans Jump\ &back<Tab>^T		Hoppa\ tillbaka<Tab>^T
menutrans Build\ &Tags\ File		Bygg\ taggfil
menutrans &Make<Tab>:make		&Bygg<Tab>:make
menutrans &List\ Errors<Tab>:cl		Listfel<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	Listmeddelande<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		Nästa\ fel<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	Tidigare\ fel<Tab>:cp
menutrans &Older\ List<Tab>:cold	&Äldre\ lista<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	&Nyare\ lista<Tab>:cnew
menutrans Error\ &Window		Felfönster
menutrans &Update<Tab>:cwin		&Uppdatera<Tab>:cwin
menutrans &Open<Tab>:copen		&Öppna<Tab>:copen
menutrans &Close<Tab>:cclose		&Stäng<Tab>:cclose
menutrans &Convert\ to\ HEX<Tab>:%!xxd	Konvertera\ till\ HEX<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r	Konvertera\ tillbaka<Tab>:%!xxd\ -r
menutrans Se&T\ Compiler		Sätt\ &kompilerare

" Tools.Spelling
menutrans &Spelling				&Stavning
menutrans &Spell\ Check\ On			&Stavningskontroll\ på
menutrans &Spell\ Check\ Off			Stavningskontroll\ &av
menutrans To\ &Next\ error<Tab>]s		Till\ &nästa\ fel
menutrans To\ &Previous\ error<Tab>[s		Till\ &föregående\ fel
menutrans Suggest\ &Corrections<Tab>z=		Föreslå\ &korrigeringar
menutrans &Repeat\ correction<Tab>:spellrepall	&Upprepa\ korrigering

" Tools.Folding
menutrans &Enable/Disable\ folds<Tab>zi	Växla\ veck<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv	Visa\ markörrad<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx	Visa\ bara\ markörrad<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm	Stäng\ mer\ veck<Tab>zm
menutrans &Close\ all\ folds<Tab>zM	Stäng\ alla\ veck<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr	Öppna\ mer\ veck<Tab>zr
menutrans &Open\ all\ folds<Tab>zR	Öppna\ mer\ veck<Tab>zR
menutrans Fold\ Met&hod			Veckmetod
menutrans M&anual			Manual
menutrans I&ndent			Indentering
menutrans E&xpression			Uttryck
menutrans S&yntax			Syntax
menutrans &Folding			Vikning
menutrans &Diff				Differans
menutrans Ma&rker			Markering
menutrans Create\ &Fold<Tab>zf		Skapa\ veck<Tab>zf
menutrans &Delete\ Fold<Tab>zd		Ta\ bort\ veck<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD	Ta\ bort\ alla\ veck<Tab>zD
menutrans Fold\ col&umn\ width		Veckcolumnsbredd

" Tools.Diff
menutrans &Update		Uppdatera
menutrans &Get\ Block		Hämta\ block
menutrans &Put\ Block		Lämna\ block

" Names for buffer menu.
menutrans &Buffers		&Buffertar
menutrans &Refresh\ menu	Uppdatera\ meny
menutrans &Delete		Ta\ bort
menutrans &Alternate		Alternativ
menutrans &Next			&Nästa
menutrans &Previous		&Tidigare

" Window menu
menutrans &Window			&Fönster
menutrans &New<Tab>^Wn			&Nytt<Tab>^Wn
menutrans S&plit<Tab>^Ws		Dela<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	Dela\ till\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Dela\ &vertikalt<Tab>^Wv
menutrans Split\ File\ E&xplorer	Dela\ filhanterare
menutrans &Close<Tab>^Wc		&Stäng<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	&Stäng\ alla\ andra<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			Nästa<Tab>^Ww
menutrans P&revious<Tab>^WW		&Tidigare<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Samma\ storlek<Tab>^W=
menutrans &Max\ Height<Tab>^W_		&Maximal\ storlek<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		M&inimal\ storlek<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		Maximal\ bredd<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Minimal\ bredd<Tab>^W1\|
menutrans Move\ &To			Flytta\ till
menutrans &Top<Tab>^WK			Toppen<Tab>^WK
menutrans &Bottom<Tab>^WJ		Botten<Tab>^WJ
menutrans &Left\ side<Tab>^WH		&Vänstra\ sidan<Tab>^WH
menutrans &Right\ side<Tab>^WL		&Högra\ sidan<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		Rotera\ upp<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Rotera\ ned<Tab>^Wr
menutrans Select\ Fo&nt\.\.\.		Välj\ typsnitt\.\.\.

" The popup menu
menutrans &Undo			&Ångra
menutrans Cu&t			Klipp\ ut
menutrans &Copy			&Kopiera
menutrans &Paste		&Klistra\ in
menutrans &Delete		&Ta\ bort
menutrans Select\ Blockwise	Markera\ blockvis
menutrans Select\ &Word		Markera\ ord
menutrans Select\ &Line		Markera\ rad
menutrans Select\ &Block	Markera\ block
menutrans Select\ &All		Markera\ allt

" The GUI toolbar (for Win32 or GTK)
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		Öppna fil
    tmenu ToolBar.Save		Spara aktuell fil
    tmenu ToolBar.SaveAll	Spara alla filer
    tmenu ToolBar.Print		Skriv ut
    tmenu ToolBar.Undo		Ångra
    tmenu ToolBar.Redo		Gör om
    tmenu ToolBar.Cut		Klipp ut
    tmenu ToolBar.Copy		Kopiera
    tmenu ToolBar.Paste		Klistra in
    tmenu ToolBar.Find		Sök...
    tmenu ToolBar.FindNext	Sök nästa
    tmenu ToolBar.FindPrev	Sök tidigare
    tmenu ToolBar.Replace	Sök och ersätt...
    tmenu ToolBar.LoadSesn	Ladda session
    tmenu ToolBar.SaveSesn	Spara session
    tmenu ToolBar.RunScript	Kör ett Vim-skript
    tmenu ToolBar.Make		Bygg aktuellt projekt
    tmenu ToolBar.Shell		Öppna ett kommandoskal
    tmenu ToolBar.RunCtags	Kör Ctags
    tmenu ToolBar.TagJump	Hoppa till tagg under markör
    tmenu ToolBar.Help		Hjälp
    tmenu ToolBar.FindHelp	Sök i hjälp
  endfun
endif

" Syntax menu
menutrans &Syntax			&Syntax
menutrans &Show\ filetypes\ in\ menu	&Visa\ filtyper\ i\ meny
menutrans &Off				&Av
menutrans &Manual			&Manuellt
menutrans A&utomatic			Automatiskt
menutrans on/off\ for\ &This\ file	Av/På\ för\ aktuell\ fil
menutrans Co&lor\ test			Färgtest
menutrans &Highlight\ test		Framhävningstest
menutrans &Convert\ to\ HTML		Konvertera\ till\ &HTML

" dialog texts
let menutrans_no_file = "[Ingen fil]"
let menutrans_help_dialog = "Skriv in ett kommando eller ord som du vill söka hjälp på:\n\nBörja med i_ för infogninglägeskommandon (t.ex. i_CTRL-X)\nBörja med c_ för kommandoradredigeringskommandon (t.ex. c_<Del>)\nBörja med ' för ett inställningsnamn (t.ex. 'shiftwidth')"
let g:menutrans_path_dialog = "Skriv in sökväg för filer.\nSeparera katalognamn med komma"
let g:menutrans_tags_dialog = "Skriv in namn på taggfiler.\nSeparera namn med komma."
let g:menutrans_textwidth_dialog = "Välj ny textbredd (0 för att förhindra formatering): "
let g:menutrans_fileformat_dialog = "Välj filformat som filen ska sparas med"

let &cpo = s:keepcpo
unlet s:keepcpo
