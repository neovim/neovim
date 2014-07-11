" Menu translations for Catalan
"
" Maintainer:	Ernest Adrogué <eadrogue@gmx.net>
" Last Change:	6 Jun 2008
"

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

" The translations below are in latin1, but they work for cp1252,
" iso-8859-15 without conversion as well.
if &enc != "cp1252" && &enc != "iso-8859-15"
  scriptencoding latin1
endif

" menú Ajuda
menutrans &Help				&Ajuda
menutrans &Overview<Tab><F1>		&Introducció<Tab><F1>
menutrans &User\ Manual			&Manual\ de\ l'usuari
menutrans &How-to\ links		Com\ &fer\.\.\.?
menutrans &Find\.\.\.			&Cerca\.\.\.
menutrans &Credits			&Autors
menutrans Co&pying			Con&dicions
menutrans &Sponsor/Register	&Patrocini/Registre
menutrans O&rphans			&Orfes
menutrans &Version			&Versió
menutrans &About			&Quant\ a\.\.\.
" text del diàleg Ajuda/Cerca...
let g:menutrans_help_dialog = "Introduïu el terme sobre el qual necessiteu ajuda.\n\nUseu el prefix i_ per ordres d'entrada (p.ex.: i_CTRL-X)\nUseu el prefix c_ per ordres de la línia d'ordres (p.ex.: c_<Del>)\nUseu el prefix ' per noms d'opcions (p.ex.: 'shiftwidth')"

" menú Fitxer
menutrans &File				&Fitxer
menutrans &Open\.\.\.<Tab>:e		&Obre\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Obre\ en\ una\ &finestra\ nova\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	Obre\ pestanya\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew		&Nou<Tab>:enew
menutrans &Close<Tab>:close		&Tanca<Tab>:close
menutrans &Save<Tab>:w			&Desa<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	&Anomena\ i\ desa\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	&Mostra\ les\ diferències\ respecte\.\.\.
menutrans Split\ Patched\ &By\.\.\.	Aplica\ les\ modificacions\ de\.\.\.
menutrans &Print			&Imprimeix
menutrans Sa&ve-Exit<Tab>:wqa		Desa\ i\ s&urt<Tab>:wqa
menutrans E&xit<Tab>:qa			&Surt<Tab>:qa

" menú Edita
menutrans &Edit				&Edita
menutrans &Undo<Tab>u			&Desfés<Tab>u
menutrans &Redo<Tab>^R			&Refés<Tab>^R
menutrans Rep&eat<Tab>\.		Re&peteix<Tab>\.
menutrans Cu&t<Tab>"+x			Re&talla<Tab>"+x
menutrans &Copy<Tab>"+y			&Copia<Tab>"+y
menutrans &Paste<Tab>"+gP		Engan&xa<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Posa\ &abans<Tab>[p
menutrans Put\ &After<Tab>]p		P&osa\ després<Tab>]p
menutrans &Delete<Tab>x			Suprimeix<Tab>x
menutrans &Select\ All<Tab>ggVG		&Selecciona-ho\ tot<Tab>ggVG
menutrans &Find\.\.\.			&Cerca\.\.\.
menutrans &Find<Tab>/			&Cerca<Tab>/
menutrans Find\ and\ Rep&lace		Cerca\ i\ s&ubstitueix
menutrans Find\ and\ Rep&lace\.\.\.	Cerca\ i\ s&ubstitueix\.\.\.
menutrans Find\ and\ Rep&lace<Tab>:%s	Cerca\ i\ s&ubstitueix<Tab>:%s
menutrans Find\ and\ Rep&lace<Tab>:s	Cerca\ i\ s&ubstitueix<Tab>:s
menutrans Settings\ &Window		Fin&estra\ d'opcions
menutrans Startup\ &Settings    Opcions\ i&nicials
menutrans &Global\ Settings		Opcions\ &globals
" submenú Edita/Opcions Globals
  menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Ressalt\ de\ &patrons<Tab>:set\ hls!
  menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		Sensibilitat\ a\ les\ ma&júscules<Tab>:set\ ic!
  menutrans Toggle\ &Showmatch<Tab>:set\ sm!		&Ressalt\ de\ coincidències<Tab>:set\ sm!
  menutrans &Context\ lines				Línies\ de\ co&ntext
  menutrans &Virtual\ Edit				Edició\ &virtual
" submenú Edita/Opcions Globals/Edició virtual
    menutrans Never					&Mai
    menutrans Block\ Selection				&Selecció\ de\ blocs
    menutrans Insert\ mode				Mode\ d'&inserció
    menutrans Block\ and\ Insert			&Blocs i inserció
    menutrans Always					S&empre
  menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		Mode\ d'&inserció<Tab>:set\ im!
  menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!	Co&mpatible\ amb\ Vi<Tab>:set\ cp!
  menutrans Search\ &Path\.\.\.				&Ubicacions\.\.\.
  menutrans Ta&g\ Files\.\.\.				Fitxers\ d'&etiquetes\.\.\.
  menutrans Toggle\ &Toolbar				&Barra\ d'eines
  menutrans Toggle\ &Bottom\ Scrollbar			Barra\ de\ &desplaçament\ inferior
  menutrans Toggle\ &Left\ Scrollbar			Barra\ de\ desplaçament\ e&squerra
  menutrans Toggle\ &Right\ Scrollbar			Barra\ de\ desplaçament\ dre&ta
menutrans F&ile\ Settings				Opcions\ del\ f&itxer
" submenú Edita/Opcions del fitxer
  menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	&Ennumera\ les\ línies<Tab>:set\ nu!
  menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Mode\ &llista<Tab>:set\ list!
  menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		A&justa\ les\ línies\ llargues<Tab>:set\ wrap!
  menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Ajusta\ sense\ partir\ &paraules<Tab>:set\ lbr!
  menutrans Toggle\ &expand-tab<Tab>:set\ et!		Estén\ les\ ta&bulacions<Tab>:set\ et!
  menutrans Toggle\ &auto-indent<Tab>:set\ ai!		&Sagnia\ automàtica<Tab>:set\ ai!
  menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Sagnia\ estil\ &C<Tab>:set\ cin!
  menutrans &Shiftwidth					Sa&gnia
  menutrans Soft\ &Tabstop				Amplada\ de\ &tabulació
  menutrans Te&xt\ Width\.\.\.				&Amplada\ del\ text\.\.\.
  menutrans &File\ Format\.\.\.				&Format\ del\ fitxer\.\.\.
menutrans Select\ Fo&nt\.\.\.		&Fosa\.\.\.
menutrans C&olor\ Scheme		Es&quema\ de\ colors
" submenú Edita/Esquema de colors
  menutrans blue			blau
  menutrans darkblue			blau\ fosc
  menutrans default			normal
  menutrans desert			desert
  menutrans evening			vesprada
  menutrans morning			matinada
  menutrans peachpuff			préssec
  menutrans shine			brillant
menutrans &Keymap			&Mapa\ de\ tecles
" submenú Edita/Mapa de tecles
  menutrans None			Cap
  menutrans accents			Accents
  menutrans arabic			Àrab
  menutrans czech			Txec
  menutrans esperanto			Esperanto
  menutrans greek			Grec
  menutrans hebrew			Hebreu
  menutrans hebrewp			Hebreu\ (fonètic)
  menutrans lithuanian-baltic		Lituà\ (bàltic)
  menutrans pinyin			Mandarí\ (fonètic)
  menutrans russian-jcuken		Rus\ (jcuken)
  menutrans russian-jcukenwin		Rus\ (jcukenwin)
  menutrans russian-yawerty		Rus\ (yawerty)
  menutrans serbian			Serbi
  menutrans serbian-latin		Serbi\ (llatí)
  menutrans slovak			Eslovac
" text del diàleg Edita/Opcions globals/Ubicacions...
let g:menutrans_path_dialog = "Introduïu les ubicacions on cercar fitxers.\nSepareu els noms dels directoris amb una coma."
" text del diàleg Edita/Opcions globals/Fitxers d'etiquetes...
let g:menutrans_tags_dialog = "Introduïu els noms dels fitxers d'etiquetes.\nSepareu els noms amb una coma."
" text del diàleg Edita/Opcions del fitxer/Amplada del text...
let g:menutrans_textwidth_dialog = "Introduïu la nova amplada del text (0 per infinit): "
" text del diàleg Edita/Opcions del fitxer/Format del fitxer...
let g:menutrans_fileformat_dialog = "Seleccioneu el format per escriure el fitxer."


" menú Eines
menutrans &Tools			Ei&nes
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Salta\ a\ aquesta\ etiqueta<Tab>g^]
menutrans Jump\ &back<Tab>^T		Salta\ en&rere<Tab>^T
menutrans Build\ &Tags\ File		Crea\ un\ fitxer\ d'eti&quetes
menutrans &Spelling         &Ortografia
" submenú Eines/Ortografia
  menutrans &Spell\ Check\ On         Activa\ la\ &revisió\ ortogràfica
  menutrans Spell\ Check\ &Off        &Desactiva\ la\ revisió\ ortogràfica
  menutrans To\ &Next\ error<Tab>]s       Error\ &següent<tab>]s
  menutrans To\ &Previous\ error<Tab>[s   Error\ &anterior<tab>[s
  menutrans Suggest\ &Corrections<Tab>z=  Su&ggeriments<Tab>z=
  menutrans &Repeat\ correction<Tab>:spellrepall  Re&peteix\ la\ correcció<Tab>:spellrepall
  menutrans Set\ language\ to\ "en"       Selecciona\ l'idioma\ "en"
  menutrans Set\ language\ to\ "en_au"    Selecciona\ l'idioma\ "en_au"
  menutrans Set\ language\ to\ "en_ca"    Selecciona\ l'idioma\ "en_ca"
  menutrans Set\ language\ to\ "en_gb"    Selecciona\ l'idioma\ "en_gb"
  menutrans Set\ language\ to\ "en_nz"    Selecciona\ l'idioma\ "en_nz"
  menutrans Set\ language\ to\ "en_us"    Selecciona\ l'idioma\ "en_us"
  menutrans Set\ language\ to\ "ca"       Selecciona\ l'idioma\ "ca"
  menutrans Set\ language\ to\ "es"       Selecciona\ l'idioma\ "es"
  menutrans Set\ language\ to\ "fr"       Selecciona\ l'idioma\ "fr"
  menutrans Set\ language\ to\ "it"       Selecciona\ l'idioma\ "it"
  menutrans &Find\ More\ Languages        &Cerca\ altres\ idiomes
menutrans &Folding			&Plecs
" submenú Eines/Plecs
  menutrans &Enable/Disable\ folds<Tab>zi  &Habilita/Deshabilita\ els\ plecs<Tab>zi
  menutrans &View\ Cursor\ Line<Tab>zv	&Línia\ del\ cursor\ visible<Tab>zv
  menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx  &Només\ visible\ la\ línia\ del\ cursor<Tab>zMzx
  menutrans C&lose\ more\ folds<Tab>zm	&Tanca\ més\ plecs<Tab>zm
  menutrans &Close\ all\ folds<Tab>zM	Tanca\ t&ots\ els\ plecs<Tab>zM
  menutrans O&pen\ more\ folds<Tab>zr	Obre\ &més\ plecs<Tab>zr
  menutrans &Open\ all\ folds<Tab>zR	O&bre\ tots\ els\ plecs<Tab>zR
  menutrans Fold\ Met&hod		Mèto&de
" submenú Eines/Plècs/Mètode
    menutrans M&anual			M&anual
    menutrans I&ndent			&Sagnia
    menutrans E&xpression		E&xpressió
    menutrans S&yntax			S&intaxi
    menutrans &Diff			&Diferències
    menutrans Ma&rker			&Marques
  menutrans Create\ &Fold<Tab>zf	&Crea\ un\ plec<Tab>zf
  menutrans &Delete\ Fold<Tab>zd	&Elimina\ un\ plec<Tab>zd
  menutrans Delete\ &All\ Folds<Tab>zD	Elimina\ tot&s\ els\ plecs<Tab>zD
  menutrans Fold\ col&umn\ width	&Amplada\ de\ la\ columna\ de\ plecs
menutrans &Diff				&Diferències
" submenú Eines/Diferències
    menutrans &Update			&Actualitza
    menutrans &Get\ Block		&Obtingues\ un\ bloc
    menutrans &Put\ Block		&Posa\ un\ bloc
menutrans &Make<Tab>:make		Crida\ a\ &make<Tab>:make
menutrans &List\ Errors<Tab>:cl		Llista\ d'&errors<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	&Llista\ de\ missatges<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		Error\ se&güent<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	Error\ an&terior<Tab>:cp
menutrans &Older\ List<Tab>:cold	Llista\ &antiga<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	Llista\ no&va<Tab>:cnew
menutrans Error\ &Window		F&inestra\ d'errors
" submenú Eines/Finestra d'errors
  menutrans &Update<Tab>:cwin		&Actualitza<Tab>:cwin
  menutrans &Open<Tab>:copen		&Obre<Tab>:copen
  menutrans &Close<Tab>:cclose		&Tanca<Tab>:cclose
menutrans &Set\ Compiler		&Compilador
menutrans &SeT\ Compiler        &Compilador
menutrans &Convert\ to\ HEX<Tab>:%!xxd	Converteix\ a\ &HEX<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r	Torna\ al\ format\ &original<Tab>:%!xxd\ -r


" menú Buffers
menutrans &Buffers			&Buffers
menutrans &Refresh\ menu		&Refresca\ el\ menú
menutrans &Delete			&Elimina
menutrans &Alternate			&Alterna
menutrans &Next				&Següent
menutrans &Previous			A&nterior
let g:menutrans_no_file = "[Cap fitxer]"


" menú Finestra
menutrans &Window			F&inestra
menutrans &New<Tab>^Wn			&Nova<Tab>^Wn
menutrans S&plit<Tab>^Ws		&Divideix<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	Divideix\ &en\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Divideix\ &verticalment<Tab>^Wv
menutrans Split\ File\ E&xplorer	E&xplorador\ de\ fitxers
menutrans &Close<Tab>^Wc		&Tanca<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Tanca\ les\ altre&s<Tab>^Wo
menutrans Move\ &To			M&ou\ a
" submenú Finestra/Mou
  menutrans &Top<Tab>^WK		&Dalt\ de\ tot<Tab>^WK
  menutrans &Bottom<Tab>^WJ		&Baix\ de\ tot<Tab>^WJ
  menutrans &Left\ side<Tab>^WH		Costat\ &esquerra<Tab>^WH
  menutrans &Right\ side<Tab>^WL	Costat\ d&ret<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		Alterna\ cap\ am&unt<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Alte&rna\ cap\ avall<Tab>^Wr
menutrans &Equal\ Size<Tab>^W=		&Iguala<Tab>^W=
menutrans &Max\ Height<Tab>^W_		Màxima\ &alçada<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		Mínima\ a&lçada<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		Màxima\ a&mplada<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Mínima\ am&plada<Tab>^W1\|


" menú emergent
menutrans &Undo				&Desfés
menutrans Cu&t				&Retalla
menutrans &Copy				&Copia
menutrans &Paste			&Enganxa
menutrans &Delete			&Suprimeix
menutrans Select\ Blockwise		Se&lecció
menutrans Select\ &Word			Selecció\ de\ &paraules
menutrans Select\ &Line			Selecció\ de\ &línies
menutrans Select\ &Block		Selecció\ de\ bl&ocs
menutrans Select\ &All			Selecciona-ho\ &tot


" barra d'eines
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		Obre un fitxer
    tmenu ToolBar.Save		Desa el fitxer
    tmenu ToolBar.SaveAll	Desa tots els fitxers
    tmenu ToolBar.Print		Imprimeix
    tmenu ToolBar.Undo		Desfés
    tmenu ToolBar.Redo		Refés
    tmenu ToolBar.Cut		Retalla
    tmenu ToolBar.Copy		Copia
    tmenu ToolBar.Paste		Enganxa
    tmenu ToolBar.Find		Cerca
    tmenu ToolBar.FindNext	Cerca el següent
    tmenu ToolBar.FindPrev	Cerca l'anterior
    tmenu ToolBar.Replace	Cerca i substitueix
    if 0	" disabled; These are in the Windows menu
      tmenu ToolBar.New		Finestra nova
      tmenu ToolBar.WinSplit	Divideix la finestra
      tmenu ToolBar.WinMax	Alçada màxima
      tmenu ToolBar.WinMin	Alçada mínima
      tmenu ToolBar.WinVSplit	Divideix la finestra verticalment
      tmenu ToolBar.WinMaxWidth	Amplada màxima
      tmenu ToolBar.WinMinWidth	Amplada mínima
      tmenu ToolBar.WinClose	Tanca la finestra
    endif
    tmenu ToolBar.LoadSesn	Carrega una sessió
    tmenu ToolBar.SaveSesn	Desa la sessió
    tmenu ToolBar.RunScript	Executa un script
    tmenu ToolBar.Make		Crida a make
    tmenu ToolBar.Shell		Obre l'intèrpret d'ordres
    tmenu ToolBar.RunCtags	Crea un fitxer d'etiquetes
    tmenu ToolBar.TagJump	Salta a una etiqueta
    tmenu ToolBar.Help		Ajuda
    tmenu ToolBar.FindHelp	Cerca a l'ajuda
  endfun
endif


" menú Sintaxi
menutrans &Syntax			&Sintaxi
menutrans &Manual			&Manual
menutrans A&utomatic			A&utomàtica
menutrans on/off\ for\ &This\ file	Activa/Desactiva\ en\ &aquest\ fitxer
menutrans &Show\ filetypes\ in\ menu	Mostra\ tots\ els\ &tipus\ al\ menú
menutrans &Off				&Desactiva
menutrans Co&lor\ test			Prova\ dels\ &colors
menutrans &Highlight\ test		Prova\ del\ &ressalt
menutrans &Convert\ to\ HTML		Converteix\ a\ &HTML
menutrans Assembly			Ensamblador
menutrans Config			Configuració
menutrans Set\ '&syntax'\ only		Només\ el\ ressalt\ de\ sintaxi
menutrans Set\ '&filetype'\ too		Carrega\ també\ els\ plugins

let &cpo = s:keepcpo
unlet s:keepcpo
