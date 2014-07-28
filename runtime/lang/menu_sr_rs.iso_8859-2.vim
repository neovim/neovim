" Menu Translations: Serbian
" Maintainer: Aleksandar Jelenak <ajelenak AT yahoo.com>
" Last Change:	Fri, 30 May 2003 12:04:48 -0400

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding iso8859-2

" Help menu
menutrans &Help		      Pomo&�
menutrans &Overview<Tab><F1>  &Pregled<Tab><F1>
menutrans &User\ Manual       &Uputstvo\ za\ korisnike
menutrans &How-to\ links      &Kako\ da\.\.\.
menutrans &Find		      &Na�i
menutrans &Credits	      &Zasluge
menutrans Co&pying	      P&reuzimanje
menutrans O&rphans	      &Siro�i�i
menutrans &Version	      &Verzija
menutrans &About	      &O\ programu

" File menu
menutrans &File			    &Datoteka
menutrans &Open\.\.\.<Tab>:e	    &Otvori\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp &Podeli-otvori\.\.\.<Tab>:sp
menutrans &New<Tab>:enew	    &Nova<Tab>:enew
menutrans &Close<Tab>:close	    &Zatvori<Tab>:close
menutrans &Save<Tab>:w		    &Sa�uvaj<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav  Sa�uvaj\ &kao\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.  Podeli\ i\ &uporedi\ sa\.\.\.
menutrans Split\ Patched\ &By\.\.\. Po&deli\ i\ prepravi\ sa\.\.\.
menutrans &Print		    �ta&mpaj
menutrans Sa&ve-Exit<Tab>:wqa	    Sa�uvaj\ i\ za&vr�i<Tab>:wqa
menutrans E&xit<Tab>:qa		    K&raj<Tab>:qa

" Edit menu
menutrans &Edit			 &Ure�ivanje
menutrans &Undo<Tab>u		 &Vrati<Tab>u
menutrans &Redo<Tab>^R		 &Povrati<Tab>^R
menutrans Rep&eat<Tab>\.	 P&onovi<Tab>\.
menutrans Cu&t<Tab>"+x		 Ise&ci<Tab>"+x
menutrans &Copy<Tab>"+y		 &Kopiraj<Tab>"+y
menutrans &Paste<Tab>"+gP	 &Ubaci<Tab>"+gP
menutrans &Paste<Tab>"+P	&Ubaci<Tab>"+gP
menutrans Put\ &Before<Tab>[p	 Stavi\ pre&d<Tab>[p
menutrans Put\ &After<Tab>]p	 Stavi\ &iza<Tab>]p
menutrans &Delete<Tab>x		 Iz&bri�i<Tab>x
menutrans &Select\ all<Tab>ggVG  Izaberi\ sv&e<Tab>ggVG
menutrans &Find\.\.\.		 &Na�i\.\.\.
menutrans Find\ and\ Rep&lace\.\.\. Na�i\ i\ &zameni\.\.\.
menutrans Settings\ &Window	 P&rozor\ pode�avanja
menutrans &Global\ Settings	 Op&�ta\ pode�avanja
menutrans F&ile\ Settings	 Pode�avanja\ za\ da&toteke
menutrans &Shiftwidth		 &Pomeraj
menutrans Soft\ &Tabstop	 &Meka\ tabulacija
menutrans Te&xt\ Width\.\.\.	 &�irina\ teksta\.\.\.
menutrans &File\ Format\.\.\.	 &Vrsta\ datoteke\.\.\.
menutrans C&olor\ Scheme	 Bo&je
menutrans &Keymap		 Pres&likavanje\ tastature
menutrans Select\ Fo&nt\.\.\.	 Izbor\ &fonta\.\.\.

" Edit/Global Settings
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls! Naglasi\ &obrazce\ (da/ne)<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic! Zanemari\ \veli�inu\ &slova\ (da/ne)<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm! Proveri\ prate�u\ &zagradu\ (da/ne)<Tab>:set\ sm!
menutrans &Context\ lines  Vidljivi\ &redovi
menutrans &Virtual\ Edit   Virtuelno\ &ure�ivanje
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	Re�im\ u&nosa\ (da/ne)<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!     '&Vi'\ saglasno\ (da/ne)<Tab>:set\ cp!
menutrans Search\ &Path\.\.\. Putanja\ &pretrage\.\.\.
menutrans Ta&g\ Files\.\.\.   &Datoteke\ oznaka\.\.\.
menutrans Toggle\ &Toolbar    Linija\ sa\ &alatkama\ (da/ne)
menutrans Toggle\ &Bottom\ Scrollbar   Donja\ l&inija\ klizanja\ (da/ne)
menutrans Toggle\ &Left\ Scrollbar  &Leva\ linija\ klizanja\ (da/ne)
menutrans Toggle\ &Right\ Scrollbar &Desna\ linija\ klizanja\ (da/ne)

" Edit/Global Settings/Virtual Edit
menutrans Never		      Nikad
menutrans Block\ Selection    Izbor\ bloka
menutrans Insert\ mode	      Re�im\ unosa
menutrans Block\ and\ Insert  Blok\ i\ unos
menutrans Always	      Uvek

" Edit/File Settings
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!   Redni\ &brojevi\ (da/ne)<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!	   Re�im\ &liste\ (da/ne)<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!	   Obavijanje\ &redova\ (da/ne)<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!   Prelomi\ &na\ re�\ (da/ne)<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!	   Razmaci\ umesto\ &tabulacije\ (da/ne)<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!	Auto-&uvla�enje\ (da/ne)<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!	   &Ce-uvla�enje\ (da/ne)<Tab>:set\ cin!

" Edit/Keymap
menutrans None Nijedan

" Tools menu
menutrans &Tools	&Alatke
menutrans &Jump\ to\ this\ tag<Tab>g^] Sko�i\ na\ &ovu\ oznaku<Tab>g^]
menutrans Jump\ &back<Tab>^T	 Sko�i\ &natrag<Tab>^T
menutrans Build\ &Tags\ File	 Izgradi\ &datoteku\ oznaka
menutrans &Folding	      &Podvijanje
menutrans Create\ &Fold<Tab>zf		  S&tvori\ podvijutak<Tab>zf
menutrans &Delete\ Fold<Tab>zd		  O&bri�i\ podvijutak<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD	  Obri�i\ sve\ po&dvijutke<Tab>zD
menutrans Fold\ column\ &width		  �irina\ &reda\ podvijutka
menutrans &Diff		      &Upore�ivanje
menutrans &Make<Tab>:make     'mak&e'<Tab>:make
menutrans &List\ Errors<Tab>:cl     Spisak\ &gre�aka<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!  Sp&isak\ poruka<Tab>:cl!
menutrans &Next\ Error<Tab>:cn	    S&lede�a\ gre�ka<Tab>:cn
menutrans &Previous\ Error<Tab>:cp  Pre&thodna\ gre�ka<Tab>:cp
menutrans &Older\ List<Tab>:cold    Stari\ spisa&k<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew    No&vi\ spisak<Tab>:cnew
menutrans Error\ &Window	    Prozor\ sa\ g&re�kama
menutrans &Set\ Compiler	    I&zaberi\ prevodioca
menutrans &Convert\ to\ HEX<Tab>:%!xxd	   Pretvori\ u\ &HEKS<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r    Vr&ati\ u\ prvobitan\ oblik<Tab>:%!xxd\ -r

" Tools/Folding
menutrans &Enable/Disable\ folds<Tab>zi   &Omogu�i/prekini\ podvijanje<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv	  &Poka�i\ red\ sa\ kursorom<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx Poka�i\ &samo\ red\ sa\ kursorom<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm   &Zatvori\ vi�e\ podvijutaka<Tab>zm
menutrans &Close\ all\ folds<Tab>zM    Zatvori\ s&ve\ podvijutke<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr    Otvori\ vi�&e\ podvijutaka<Tab>zr
menutrans &Open\ all\ folds<Tab>zR     O&tvori\ sve\ podvijutke<Tab>zR
menutrans Fold\ Met&hod		       &Na�in\ podvijanja

" Tools/Folding/Fold Method
menutrans M&anual	&Ru�no
menutrans I&ndent	&Uvu�enost
menutrans E&xpression	&Izraz
menutrans S&yntax	&Sintaksa
"menutrans &Diff
menutrans Ma&rker	&Oznaka

" Tools/Diff
menutrans &Update	&A�uriraj
menutrans &Get\ Block	&Prihvati\ izmenu
menutrans &Put\ Block	Pre&baci\ izmenu

" Tools/Error Window
menutrans &Update<Tab>:cwin   &A�uriraj<Tab>:cwin
menutrans &Open<Tab>:copen    &Otvori<Tab>:copen
menutrans &Close<Tab>:cclose  &Zatvori<Tab>:cclose

" Bufers menu
menutrans &Buffers	   &Baferi
menutrans &Refresh\ menu   &A�uriraj
menutrans Delete	   &Obri�i
menutrans &Alternate	   A&lternativni
menutrans &Next		   &Slede�i
menutrans &Previous	   &Prethodni
menutrans [No\ File]	   [Nema\ datoteke]

" Window menu
menutrans &Window		    &Prozor
menutrans &New<Tab>^Wn		    &Novi<Tab>^Wn
menutrans S&plit<Tab>^Ws	    &Podeli<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^    Podeli\ sa\ &alternativnim<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv   Podeli\ &uspravno<Tab>^Wv
menutrans Split\ File\ E&xplorer    Podeli\ za\ pregled\ &datoteka
menutrans &Close<Tab>^Wc	    &Zatvori<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo  Zatvori\ &ostale<Tab>^Wo
"menutrans Ne&xt<Tab>^Ww       &Slede�i<Tab>^Ww
"menutrans P&revious<Tab>^WW	  P&rethodni<Tab>^WW
menutrans Move\ &To		    Pre&mesti
menutrans Rotate\ &Up<Tab>^WR	    &Kru�no\ nagore<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr     Kru�no\ nadol&e<Tab>^Wr
menutrans &Equal\ Size<Tab>^W=	    &Iste\ veli�ine<Tab>^W=
menutrans &Max\ Height<Tab>^W_	    Maksimalna\ &visina<Tab>^W_
menutrans M&in\ Height<Tab>^W1_     Minima&lna\ visina<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|	    Maksimalna\ &�irina<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|     Minimalna\ �i&rina<Tab>^W1\|

" Window/Move To
menutrans &Top<Tab>^WK		 &Vrh<Tab>^WK
menutrans &Bottom<Tab>^WJ	 &Podno�je<Tab>^WJ
menutrans &Left\ side<Tab>^WH	 U&levo<Tab>^WH
menutrans &Right\ side<Tab>^WL	 U&desno<Tab>^WL

" The popup menu
menutrans &Undo		      &Vrati
menutrans Cu&t		      &Iseci
menutrans &Copy		      &Kopiraj
menutrans &Paste	      &Ubaci
menutrans &Delete	      I&zbri�i
menutrans Select\ Blockwise   Biraj\ &pravougaono
menutrans Select\ &Word       Izaberi\ &re�
menutrans Select\ &Line       Izaberi\ r&ed
menutrans Select\ &Block      Izaberi\ &blok
menutrans Select\ &All	      Izaberi\ &sve

" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open	   U�itaj
    tmenu ToolBar.Save	   Sa�uvaj
    tmenu ToolBar.SaveAll  Sa�uvaj sve
    tmenu ToolBar.Print    �tampaj
    tmenu ToolBar.Undo	   Vrati
    tmenu ToolBar.Redo	   Povrati
    tmenu ToolBar.Cut	   Iseci
    tmenu ToolBar.Copy	   Kopiraj
    tmenu ToolBar.Paste    Ubaci
    tmenu ToolBar.Find	   Na�i
    tmenu ToolBar.FindNext Na�i slede�i
    tmenu ToolBar.FindPrev Na�i prethodni
    tmenu ToolBar.Replace  Zameni
    tmenu ToolBar.New	   Novi
    tmenu ToolBar.WinSplit Podeli prozor
    tmenu ToolBar.WinMax   Maksimalna visina
    tmenu ToolBar.WinMin   Minimalna visina
    tmenu ToolBar.WinVSplit   Podeli uspravno
    tmenu ToolBar.WinMaxWidth Maksimalna �irina
    tmenu ToolBar.WinMinWidth Minimalna �irina
    tmenu ToolBar.WinClose Zatvori prozor
    tmenu ToolBar.LoadSesn U�itaj seansu
    tmenu ToolBar.SaveSesn Sa�uvaj seansu
    tmenu ToolBar.RunScript   Izvr�i spis
    tmenu ToolBar.Make	   'make'
    tmenu ToolBar.Shell    Operativno okru�enje
    tmenu ToolBar.RunCtags Napravi oznake
    tmenu ToolBar.TagJump  Idi na oznaku
    tmenu ToolBar.Help	   Pomo�
    tmenu ToolBar.FindHelp Na�i obja�njenje
  endfun
endif

" Syntax menu
menutrans &Syntax &Sintaksa
menutrans &Show\ filetypes\ in\ menu  Izbor\ 'filetype'\ iz\ &menija
menutrans Set\ '&syntax'\ only	 Pode&si\ 'syntax'\ samo
menutrans Set\ '&filetype'\ too  Podesi\ 'filetype'\ &tako�e
menutrans &Off	     &Isklju�eno
menutrans &Manual    &Ru�no
menutrans A&utomatic	&Automatski
menutrans on/off\ for\ &This\ file     Da/ne\ za\ ovu\ &datoteku
menutrans Co&lor\ test	   Provera\ &boja
menutrans &Highlight\ test Provera\ isti&canja
menutrans &Convert\ to\ HTML  Pretvori\ &u\ HTML

" dialog texts
let menutrans_help_dialog = "Unesite naredbu ili re� �ije poja�njenje tra�ite:\n\nDodajte i_ za naredbe unosa (npr. i_CTRL-X)\nDodajte c_ za naredbe komandnog re�ima (npr. s_<Del>)\nDodajte ' za imena opcija (npr. 'shiftwidth')"

let g:menutrans_path_dialog = "Unesite put pretrage za datoteke\nRazdvojite zarezima imena direktorijuma."

let g:menutrans_tags_dialog = "Unesite imena datoteka sa oznakama\nRazdvojite zarezima imena."

let g:menutrans_textwidth_dialog = "Unesite novu �irinu teksta (0 spre�ava prelom)"

let g:menutrans_fileformat_dialog = "Izaberite vrstu datoteke"

let menutrans_no_file = "[Nema datoteke]"

let &cpo = s:keepcpo
unlet s:keepcpo
