" Menu Translations:	Hungarian (Magyar)
" Original Translation:	Zoltán Árpádffy
" Maintained By:	Kontra Gergely <kgergely@mcl.hu>
" Last Change:		2012 May 01
"
" This file was converted from menu_hu_hu.iso_8859-2.vim.  See there for
" remarks.

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding utf-8

" Help menu
menutrans &Help			&Súgó
menutrans &Overview<Tab><F1>	Á&ttekintés<Tab><F1>
menutrans &How-to\ links	&HOGYAN\ linkek
menutrans &User\ Manual		&Kézikönyv
menutrans &Credits		&Szerzők,\ köszönetek
menutrans Co&pying		&Védjegy
menutrans O&rphans		Árvá&k
menutrans &Find\.\.\.		Ke&resés\.\.\.
menutrans &Version		&Verzió
menutrans &About		&Névjegy
" File menu
menutrans &File				&Fájl
menutrans &Open\.\.\.<Tab>:e		Meg&nyitás\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Megnyitás\ új\ a&blakba\.\.\.<Tab>:sp
menutrans &New<Tab>:enew		Új\ dok&umentum<Tab>:enew
menutrans &Close<Tab>:close		Be&zárás<Tab>:close
menutrans &Save<Tab>:w			&Mentés<Tab>:w
menutrans Split\ &Diff\ with\.\.\.	Össze&hasonlítás\.\.\.
menutrans Split\ Patched\ &By\.\.\.	Összehasonlítás\ &patch\ -el\.\.\.
menutrans Save\ &As\.\.\.<Tab>:sav	Menté&s\ másként\.\.\.<Tab>:w
menutrans &Print			Nyomt&atás
menutrans Sa&ve-Exit<Tab>:wqa		Mentés\ és\ k&ilépés<Tab>:wqa
menutrans E&xit<Tab>:qa			&Kilépés<Tab>:qa

" Edit menu
menutrans &Edit				S&zerkesztés
menutrans &Undo<Tab>u			&Visszavonás<Tab>u
menutrans &Redo<Tab>^R			Mé&gis<Tab>^R
menutrans Rep&eat<Tab>\.		&Ismét<Tab>\.
menutrans Cu&t<Tab>"+x			&Kivágás<Tab>"+x
menutrans &Copy<Tab>"+y			&Másolás<Tab>"+y
menutrans &Paste<Tab>"+gP		&Beillesztés<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Berakás\ e&lé<Tab>[p
menutrans Put\ &After<Tab>]p		Berakás\ &mögé<Tab>]p
menutrans &Delete<Tab>x			&Törlés<Tab>x
menutrans &Select\ all<Tab>ggVG		A&z\ összes kijelölése<Tab>ggvG
menutrans &Find\.\.\.			Ke&resés\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.	Keresés\ és\ c&sere\.\.\.
menutrans Find\ and\ Rep&lace<Tab>:%s	Keresés\ és\ c&sere<Tab>:%s
menutrans Find\ and\ Rep&lace		Keresés\ és\ c&sere
menutrans Find\ and\ Rep&lace<Tab>:s	Keresés\ és\ c&sere<Tab>:s
menutrans Settings\ &Window		&Ablak\ beállításai
menutrans &Global\ Settings		Ál&talános\ beállítások
menutrans F&ile\ Settings		&Fájl\ beállítások
menutrans C&olor\ Scheme		&Színek
menutrans &Keymap			Billent&yűzetkiosztás

" Edit.Global Settings
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	&Minta\ kiemelés\ BE/KI<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!	&Kis/nagybetű\ azonos/különböző<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!	&Zárójelpár\ mutatása\ BE/KI<Tab>:set\ sm!
menutrans &Context\ lines		&Kurzor\ ablak\ szélétől
menutrans &Virtual\ Edit		&Virtuális\ szerkesztés
menutrans Never				&Soha
menutrans Block\ Selection		&Blokk\ kijelölésekor
menutrans Insert\ mode			S&zöveg\ bevitelekor
menutrans Block\ and\ Insert		Bl&okk\ kijelölésekor\ és\ szöveg\ bevitelekor
menutrans Always			&Mindig
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	&Szövegbeviteli\ mód\ BE/KI<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!	&Vi\ kompatíbilis\ mód\ BE/Ki<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.		Ke&resési\ útvonal\.\.\.
menutrans Ta&g\ Files\.\.\.		&Tag\ fájl\.\.\.
menutrans Toggle\ &Toolbar		&Eszköztár\ BE/KI
menutrans Toggle\ &Bottom\ Scrollbar	&Vízszintes\ Görgetősáv\ BE/KI
menutrans Toggle\ &Left\ Scrollbar	&Bal\ görgetősáv\ BE/KI
menutrans Toggle\ &Right\ Scrollbar	&Jobb\ görgetősáv\ BE/KI
menutrans None				Nincs

" Edit.File Settings
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	Sorszá&mozás\ BE/KI<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		&Lista\ mód\ BE/KI<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Sor&törés\ BE/KI<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Sortörés\ s&zóvégeknél\ BE/KI<tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		&Tab\ kifejtés\ BE/KI<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		&Automatikus\ behúzás\ BE/KI<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		&C-behúzás\ BE/KI<Tab>:set\ cin!
menutrans &Shiftwidth					&Behúzás\ mértéke\ ('sw')
menutrans Soft\ &Tabstop				T&abulálás\ mértéke\ ('sts')
menutrans Te&xt\ Width\.\.\.				&Szöveg\ szélessége\.\.\.
menutrans &File\ Format\.\.\.				&Fájlformátum\.\.\.

" Tools menu
menutrans &Tools			&Eszközök
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Ugrás\ a\ taghoz<Tab>g^]
menutrans Jump\ &back<Tab>^T		Ugrás\ &vissza<Tab>^T
menutrans Build\ &Tags\ File		&Tag\ fájl\ készítése
menutrans &Folding			&Behajtások
menutrans &Make<Tab>:make		&Fordítás<Tab>:make
menutrans &List\ Errors<Tab>:cl		&Hibák\ listája<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	Ü&zenetek\ listája<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		&Következő\ &hiba<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	&Előző\ hiba<Tab>:cp
menutrans &Older\ List<Tab>:cold	&Régebbi\ lista<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	&Újabb\ lista<Tab>:cnew
menutrans Error\ &Window		Hibaablak
menutrans &Update<Tab>:cwin		&Frissítés<Tab>:cwin
menutrans &Open<Tab>:copen		M&egnyitás<Tab>:copen
menutrans &Close<Tab>:cclose		Be&zárás<Tab>:cclose
menutrans &Convert\ to\ HEX<Tab>:%!xxd	Normál->HEX\ nézet<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r	HEX->Normál\ nézet<Tab>:%!xxd\ -r
menutrans &Set\ Compiler		Fordító\ &megadása

" Tools.Folding
menutrans &Enable/Disable\ folds<Tab>zi	Behajtások\ BE&/KI<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv	&Aktuális\ sor\ látszik<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx	&Csak\ aktuális\ sor\ látszik<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm	Következő\ szint\ be&zárása<Tab>zm
menutrans &Close\ all\ folds<Tab>zM	Összes\ hajtás\ &bezárása<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr	Következő\ szint\ ki&nyitása<Tab>zr
menutrans &Open\ all\ folds<Tab>zR	Összes\ hajtás\ &kinyitása<Tab>zR
menutrans Fold\ Met&hod			Behajtások\ &létrehozása
menutrans M&anual			&Kézi
menutrans I&ndent			Be&húzás
menutrans E&xpression			Ki&fejezés
menutrans S&yntax			&Szintaxis
menutrans &Diff				&Diff-különbség
menutrans Ma&rker			&Jelölés
menutrans Create\ &Fold<Tab>zf		Ú&j\ behajtás<Tab>zf
menutrans &Delete\ Fold<Tab>zd		Behajtás\ &törlése<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD	Öss&zes\ behajtás\ törlése<Tab>zD
menutrans Fold\ col&umn\ width		Behajtások\ a\ &margón\ x\ oszlopban

" Tools.Diff
menutrans &Update		&Frissítés
menutrans &Get\ Block		Block\ &BE
menutrans &Put\ Block		Block\ &KI



" Names for buffer menu.
menutrans &Buffers		&Pufferok
menutrans &Refresh\ menu	&Frissítés
menutrans Delete		&Törlés
menutrans &Alternate		&Csere
menutrans &Next			&Következő
menutrans &Previous		&Előző

" Window menu
menutrans &Window			&Ablak
menutrans &New<Tab>^Wn			Ú&j<Tab>^Wn
menutrans S&plit<Tab>^Ws		&Felosztás<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	Felosztás\ &#-val<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Felosztás\ Fü&ggőlegesen<Tab>^Wv
menutrans Split\ File\ E&xplorer	Új\ &intéző
menutrans &Close<Tab>^Wc		Be&zárás<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	&Többi\ bezárása<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			&Következő<Tab>^Ww
menutrans P&revious<Tab>^WW		&Előző<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Azonos\ magasság<Tab>^W=
menutrans &Max\ Height<Tab>^W_		Ma&x\ magasság<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		&Min\ magasság<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		Max\ &szélesség<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Mi&n\ szélesség<Tab>^W1\|
menutrans Move\ &To			&Elmozdítás
menutrans &Top<Tab>^WK			&Fel<Tab>^WK
menutrans &Bottom<Tab>^WJ		&Le<Tab>^WJ
menutrans &Left\ side<Tab>^WH		&Balra<Tab>^WH
menutrans &Right\ side<Tab>^WL		&Jobbra<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		Gördítés\ &felfelé<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Gördítés\ &lefelé<Tab>^Wr
menutrans Select\ Fo&nt\.\.\.		&Betűtípus\.\.\.

" The popup menu
menutrans &Undo			&Visszavonás
menutrans Cu&t			&Kivágás
menutrans &Copy			&Másolás
menutrans &Paste		&Beillesztés
menutrans &Delete		&Törlés
menutrans Select\ Blockwise	Kijelölés\ blo&kként
menutrans Select\ &Word		S&zó\ kijelölése
menutrans Select\ &Line		&Sor\ kijelölése
menutrans Select\ &Block	B&lokk\ kijelölése
menutrans Select\ &All		A&z\ összes\ kijelölése

" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		Megnyitás
    tmenu ToolBar.Save		Mentés
    tmenu ToolBar.SaveAll	Mindet menti
    tmenu ToolBar.Print		Nyomtatás
    tmenu ToolBar.Undo		Visszavonás
    tmenu ToolBar.Redo		Mégis
    tmenu ToolBar.Cut		Kivágás
    tmenu ToolBar.Copy		Másolás
    tmenu ToolBar.Paste		Beillesztés
    tmenu ToolBar.Find		Keresés
    tmenu ToolBar.FindNext	Tovább keresés
    tmenu ToolBar.FindPrev	Keresés visszafelé
    tmenu ToolBar.Replace	Keresés/csere
    tmenu ToolBar.LoadSesn	Munkamenet beolvasás
    tmenu ToolBar.SaveSesn	Munkamenet mentés
    tmenu ToolBar.RunScript	Vim program indítás
    tmenu ToolBar.Make		Projekt építés
    tmenu ToolBar.Shell		Shell indítás
    tmenu ToolBar.RunCtags	Tag építés
    tmenu ToolBar.TagJump	Ugrás a kurzor alatti tagra
    tmenu ToolBar.Help		Vim súgó
    tmenu ToolBar.FindHelp	Keresés a Vim súgóban
  endfun
endif

" Syntax menu
menutrans &Syntax			Sz&intaxis
menutrans &Show\ filetypes\ in\ menu	Fájl&típusok\ menü
menutrans Set\ '&syntax'\ only		Csak\ '&syntax'
menutrans Set\ '&filetype'\ too		'&filetype'\ is
menutrans &Off				&Ki
menutrans &Manual			Ké&zi
menutrans A&utomatic			A&utomatikus
menutrans on/off\ for\ &This\ file	&BE/KI\ ennél\ a\ fájlnál
menutrans Co&lor\ test			&Színteszt
menutrans &Highlight\ test		Kiemelés\ &teszt
menutrans &Convert\ to\ HTML		&HTML\ oldal\ készítése

" dialog texts
let menutrans_no_file = "[Nincs file]"
let menutrans_help_dialog = "Írd be a kívánt szót vagy parancsot:\n\n A szövegbeviteli parancsok elé írj i_-t (pl.: i_CTRL-X)\nA sorszerkesző parancsok elé c_-t (pl.: c_<Del>)\nA változókat a ' jellel vedd körül (pl.: 'shiftwidth')"
let g:menutrans_path_dialog = "Írd be a keresett fájl lehetséges elérési útjait, vesszővel elválasztva"
let g:menutrans_tags_dialog = "Írd be a tag fájl lehetséges elérési útjait, vesszővel elválasztva"
let g:menutrans_textwidth_dialog = "Írd be a szöveg szélességét (0 = formázás kikapcsolva)"
let g:menutrans_fileformat_dialog = "Válaszd ki a fájl formátumát"

let &cpo = s:keepcpo
unlet s:keepcpo
