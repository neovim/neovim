" Menu Translations:	Ukrainian
" Maintainer:		Bohdan Vlasyuk <bohdan@vstu.edu.ua>
" Last Change:		11 Oct 2001

"
" Please, see readme at htpp://www.vstu.edu.ua/~bohdan/vim before any
" complains, and even if you won't complain, read it anyway.
"

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding koi8-u

" Help menu
menutrans &Help			&Допомога
menutrans &Overview<Tab><F1>	&Загальна\ ╤нформац╕я<Tab><F1>
menutrans &User\ Manual		&Кер╕вництво\ для\ користувача
menutrans &How-to\ links	&Як-Зробити?
"menutrans &GUI			&GIU
menutrans &Credits		&Подяки
menutrans Co&pying		&Розповсюдження
menutrans O&rphans		&Допомога\ сиротам
menutrans &Version		&Верс╕я
menutrans &About		Про\ &програму

" File menu
menutrans &File				&Файл
menutrans &Open\.\.\.<Tab>:e	    &В╕дкрити\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp &Розд╕лити\ в╕кно\.\.\.<Tab>:sp
menutrans &New<Tab>:enew	    &Новий<Tab>:enew
menutrans &Close<Tab>:close	    &Закрити<Tab>:close
menutrans &Save<Tab>:w		    За&пам'ятати<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Запам'ятати\ &як\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	По&р╕вняти\ з\.\.\.
menutrans Split\ Patched\ &By\.\.\.	За&латати\.\.\.
menutrans &Print					&Друкувати
menutrans Sa&ve-Exit<Tab>:wqa		Записати\ ╕\ ви&йти<Tab>:wqa
menutrans E&xit<Tab>:qa			&Вих╕д<Tab>:qa

" Edit menu
menutrans &Edit				&Редагувати
menutrans &Undo<Tab>u			&В╕дм╕нити<Tab>u
menutrans &Redo<Tab>^R			&Повернути<Tab>^R
menutrans Rep&eat<Tab>\.		П&овторити<Tab>\.
menutrans Cu&t<Tab>"+x			Ви&р╕зати<Tab>"+x
menutrans &Copy<Tab>"+y			&Коп╕ювати<Tab>"+y
menutrans &Paste<Tab>"+gP		В&ставити<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Вставити\ попе&реду<Tab>[p
menutrans Put\ &After<Tab>]p		Вставити\ п&╕сля<Tab>]p
menutrans &Select\ all<Tab>ggVG		Ви&брати\ усе<Tab>ggVG
menutrans &Find\.\.\.			&Знайти\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.	За&м╕нити\.\.\.
menutrans Settings\ &Window		В╕кно\ &налаштувань
menutrans &Global\ Settings		Загальн╕\ на&лаштування
menutrans F&ile\ Settings		Налаштування\ для\ &файлу
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	&Нумерац╕я\ рядк╕в<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Режим\ на&длишкового\ в╕дображення<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Режим\ &переносу<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Переносити\ усе\ &слово<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!			Користуватися\ символом\ &табуляц╕╖<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Автоматичний\ &в╕дступ<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		В╕дступи\ для\ мови\ &C<Tab>:set\ cin!
menutrans &Shiftwidth								&Зсув
menutrans Te&xt\ Width\.\.\.						&Ширина\ тексту\.\.\.
menutrans &File\ Format\.\.\.			&Формат\ файлу\.\.\.
menutrans Soft\ &Tabstop				Позиц╕я\ &табуляц╕╖
menutrans C&olor\ Scheme		&Кольори
menutrans Select\ Fo&nt\.\.\.		Вибрати\ &шрифт\.\.\.


menutrans &Keymap			Режим\ клав╕атури
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Вид╕ляти\ &зразок<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		&Розр╕зняти\ \велик╕\ та\ мал╕\ л╕тери<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		&Негайний\ пошук<Tab>:set\ sm!
menutrans &Context\ lines	К╕льк╕сть\ &важливих\ рядк╕в
menutrans &Virtual\ Edit	Курсор\ &руха╓ться\ без\ меж

menutrans Never			Н╕коли
menutrans Block\ Selection	Виб╕р\ Блоку
menutrans Insert\ mode		Режим\ вставки
menutrans Block\ and\ Insert	Виб╕р\ ╕\ вставка
menutrans Always		Завжди

menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	Режим\ &вставки<Tab>:set\ im!
menutrans Search\ &Path\.\.\.	&Шлях\ пошуку\.\.\.
menutrans Ta&g\ Files\.\.\.	Файли\ &пом╕ток\.\.\.


"
" GUI options
menutrans Toggle\ &Toolbar		Панель\ &╕нструмент╕в
menutrans Toggle\ &Bottom\ Scrollbar	&Нижня\ л╕н╕йка\ зсуву
menutrans Toggle\ &Left\ Scrollbar	&Л╕ва\ л╕н╕йка\ зсуву
menutrans Toggle\ &Right\ Scrollbar	&Права\ л╕н╕йка\ зсуву

" Programming menu
menutrans &Tools			&╤нструменти
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Перейти\ до\ пом╕тки<Tab>g^]
menutrans Jump\ &back<Tab>^T		По&вернутися<Tab>^T
menutrans Build\ &Tags\ File		&Створити\ файл\ пом╕ток
" Folding
menutrans &Folding				&Згортки
menutrans &Enable/Disable\ folds<Tab>zi		&Дозволити/заборонити\ згортки<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv			&Бачити\ рядок\ з\ курсором<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx			Бачити\ &лише\ рядок\ з\ курсором<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm				Закрити\ &б╕льше\ згортк╕в<Tab>zm
menutrans &Close\ all\ folds<Tab>zM				Закрити\ &ус╕\ згортки<Tab>zM
menutrans &Open\ all\ folds<Tab>zR				В╕дкрити\ у&с╕\ згортки<Tab>zR
menutrans O&pen\ more\ folds<Tab>zr				В╕дкрити\ б&╕льше\ згортк╕в<Tab>zr

menutrans Create\ &Fold<Tab>zf				С&творити\ згорток<Tab>zf
menutrans &Delete\ Fold<Tab>zd				&Видалити\ згорток<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD		Видалит&и\ ус╕\ згортки<Tab>zD
menutrans Fold\ column\ &width				&Товщина\ рядка\ згортк╕в
menutrans Fold\ Met&hod		&Метод\ згортання
menutrans M&anual			&Ручний
menutrans I&ndent			&В╕дступ
menutrans E&xpression       В&ираз
menutrans S&yntax			&Синтаксично
menutrans Ma&rker			По&значки

" Diff
menutrans &Diff					По&р╕вняння
menutrans &Update				&Поновити
menutrans &Get\ Block			&Запозичити\ р╕зницю
menutrans &Put\ Block			&Впровадити\ р╕зницю

" Make and stuff...
menutrans &Make<Tab>:make		&Будувати(make)<Tab>:make
menutrans &List\ Errors<Tab>:cl		&Список\ помилок<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	Сп&исок\ пов╕домлень<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		&Наступна\ помилка<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	&Попередня\ помилка<Tab>:cp
menutrans &Older\ List<Tab>:cold	&Бувш╕\ помилки<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	&Майбутн╕\ помилки<Tab>:cnew
menutrans Error\ &Window	    &В╕кно\ помилок
menutrans &Update<Tab>:cwin			&Поновити<Tab>:cwin
menutrans &Close<Tab>:cclose		&Закрити<Tab>:cclose
menutrans &Open<Tab>:copen			&В╕дкрити<Tab>:copen

menutrans &Set\ Compiler				Встановити\ &комп╕лятор
menutrans &Convert\ to\ HEX<Tab>:%!xxd     Перевести\ в\ ш╕стнадцятков╕\ коди<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r     Повернути\ в\ дв╕йкову\ форму<Tab>:%!xxd\ -r

" Names for buffer menu.
menutrans &Buffers	&Буфери
menutrans &Refresh\ menu &Поновити
menutrans Delete	&Видалити
menutrans &Alternate	&Вторинний
menutrans &Next		&Сл╕дуючий
menutrans &Previous	&Попередн╕й
menutrans [No\ File]	[Нема╓\ Файла]

" Window menu
menutrans &Window			&В╕кно
menutrans &New<Tab>^Wn			&Нове<Tab>^Wn
menutrans S&plit<Tab>^Ws		&Розд╕лити<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	Розд╕лити\ для\ &вторинного\ файлу<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Розд╕лити\ &поперек<Tab>^Wv
"menutrans Split\ &Vertically<Tab>^Wv	&Розд╕лити\ поперек<Tab>^Wv
menutrans Split\ File\ E&xplorer		Розд╕лити\ для\ &перегляду\ файл╕в

menutrans &Close<Tab>^Wc		&Закрити<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Закрити\ ус╕\ &╕нш╕<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			&Наступне<Tab>^Ww
menutrans P&revious<Tab>^WW		&Попередн╓<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Вир╕вняти\ розм╕р<Tab>^W=
menutrans &Max\ Height<Tab>^W_		Най&б╕льша\ висота<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		Най&менша\ висота<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		Найб╕&льша\ ширина<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Наймен&ша\ ширина<Tab>^W1\|
menutrans Move\ &To			&Зм╕стити
menutrans &Top<Tab>^WK			До&гори<Tab>^WK
menutrans &Bottom<Tab>^WJ		До&низу<Tab>^WJ
menutrans &Left\ side<Tab>^WH		У&л╕во<Tab>^WH
menutrans &Right\ side<Tab>^WL		В&право<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		&Цикл╕чно\ догори<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Ц&икл╕чно\ униз<Tab>^Wr

" The popup menu
menutrans &Undo			&В╕дм╕нити
menutrans Cu&t			Ви&р╕зати
menutrans &Copy			&Коп╕ювати
menutrans &Paste		В&ставити
menutrans &Delete		Ви&далити
menutrans Select\ &Word		Вибрати\ &слово
menutrans Select\ &Line		Вибрати\ &рядок
menutrans Select\ &Block	Вибрати\ &блок
menutrans Select\ &All		Вибрати\ &усе



" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		В╕дкрити файл
    tmenu ToolBar.Save		Запам'ятати файл
    tmenu ToolBar.SaveAll		Запам'ятати ус╕ файли
    tmenu ToolBar.Print		Друкувати
    tmenu ToolBar.Undo		В╕дм╕нити
    tmenu ToolBar.Redo		Повернути
    tmenu ToolBar.Cut		Вир╕зати
    tmenu ToolBar.Copy		Коп╕ювати
    tmenu ToolBar.Paste		Вставити
    tmenu ToolBar.Find		Знайти...
    tmenu ToolBar.FindNext	Знайти наступний
    tmenu ToolBar.FindPrev	Знайти попередн╕й
    tmenu ToolBar.Replace	Зам╕нити...
    tmenu ToolBar.LoadSesn	Завантажити сеанс редагування
    tmenu ToolBar.SaveSesn	Запам'ятати сеанс редагування
    tmenu ToolBar.RunScript	Виконати файл команд
    tmenu ToolBar.Make		Збудувати проект
    tmenu ToolBar.Shell		Shell
    tmenu ToolBar.RunCtags	Створити файл пом╕ток
    tmenu ToolBar.TagJump	Перейти до пом╕тки
    tmenu ToolBar.Help		Допомога
    tmenu ToolBar.FindHelp	Пошук у допомоз╕
  endfun
endif

" Syntax menu
menutrans &Syntax &Синтаксис
menutrans Set\ '&syntax'\ only	Встановлювати\ лише\ '&syntax'
menutrans Set\ '&filetype'\ too	Встановлювати\ '&filetype'\ також
menutrans &Off			&Вимкнено
menutrans &Manual		&Ручний
menutrans A&utomatic		&Автоматично
menutrans on/off\ for\ &This\ file		Перемкнути\ для\ цього\ &файла
menutrans Co&lor\ test		Перев╕рка\ &кольор╕в
menutrans &Highlight\ test	&Перев╕рка\ вид╕лення
menutrans &Convert\ to\ HTML	Створити\ &HTML

" dialog texts
let menutrans_no_file = "[Нема╓\ Файла]"
let menutrans_help_dialog = "Вкаж╕ть команду або слово для пошуку:\n\nДодайте i_ для команд режиму вставки (напр. i_CTRL-X)\nДодайте i_ для командного режиму (напр. с_<Del>)\nДодайте ' для позначення назви опц╕╖ (напр. 'shiftwidth')"
let g:menutrans_path_dialog = "Вкаж╕ть шлях пошуку файл╕в\nРозд╕ляйте назви директор╕й комами."
let g:menutrans_tags_dialog = "Вкаж╕ть назви файл╕в пом╕ток\nРозд╕ляйте назви комами."
let g:menutrans_textwidth_dialog = "Вкаж╕ть нову ширину тексту (0 для в╕дм╕ни фоматування)"
let g:menutrans_fileformat_dialog = "Вибер╕ть формат файлу"

let &cpo = s:keepcpo
unlet s:keepcpo
