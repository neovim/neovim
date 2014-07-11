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

scriptencoding cp1251

" Help menu
menutrans &Help			&Допомога
menutrans &Overview<Tab><F1>	&Загальна\ Інформація<Tab><F1>
menutrans &User\ Manual		&Керівництво\ для\ користувача
menutrans &How-to\ links	&Як-Зробити?
"menutrans &GUI			&GIU
menutrans &Credits		&Подяки
menutrans Co&pying		&Розповсюдження
menutrans O&rphans		&Допомога\ сиротам
menutrans &Version		&Версія
menutrans &About		Про\ &програму

" File menu
menutrans &File				&Файл
menutrans &Open\.\.\.<Tab>:e	    &Відкрити\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp &Розділити\ вікно\.\.\.<Tab>:sp
menutrans &New<Tab>:enew	    &Новий<Tab>:enew
menutrans &Close<Tab>:close	    &Закрити<Tab>:close
menutrans &Save<Tab>:w		    За&пам'ятати<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Запам'ятати\ &як\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	По&рівняти\ з\.\.\.
menutrans Split\ Patched\ &By\.\.\.	За&латати\.\.\.
menutrans &Print					&Друкувати
menutrans Sa&ve-Exit<Tab>:wqa		Записати\ і\ ви&йти<Tab>:wqa
menutrans E&xit<Tab>:qa			&Вихід<Tab>:qa

" Edit menu
menutrans &Edit				&Редагувати
menutrans &Undo<Tab>u			&Відмінити<Tab>u
menutrans &Redo<Tab>^R			&Повернути<Tab>^R
menutrans Rep&eat<Tab>\.		П&овторити<Tab>\.
menutrans Cu&t<Tab>"+x			Ви&різати<Tab>"+x
menutrans &Copy<Tab>"+y			&Копіювати<Tab>"+y
menutrans &Paste<Tab>"+gP		В&ставити<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Вставити\ попе&реду<Tab>[p
menutrans Put\ &After<Tab>]p		Вставити\ п&ісля<Tab>]p
menutrans &Select\ all<Tab>ggVG		Ви&брати\ усе<Tab>ggVG
menutrans &Find\.\.\.			&Знайти\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.	За&мінити\.\.\.
menutrans Settings\ &Window		Вікно\ &налаштувань
menutrans &Global\ Settings		Загальні\ на&лаштування
menutrans F&ile\ Settings		Налаштування\ для\ &файлу
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	&Нумерація\ рядків<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Режим\ на&длишкового\ відображення<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Режим\ &переносу<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Переносити\ усе\ &слово<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!			Користуватися\ символом\ &табуляції<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Автоматичний\ &відступ<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Відступи\ для\ мови\ &C<Tab>:set\ cin!
menutrans &Shiftwidth								&Зсув
menutrans Te&xt\ Width\.\.\.						&Ширина\ тексту\.\.\.
menutrans &File\ Format\.\.\.			&Формат\ файлу\.\.\.
menutrans Soft\ &Tabstop				Позиція\ &табуляції
menutrans C&olor\ Scheme		&Кольори
menutrans Select\ Fo&nt\.\.\.		Вибрати\ &шрифт\.\.\.


menutrans &Keymap			Режим\ клавіатури
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Виділяти\ &зразок<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		&Розрізняти\ \великі\ та\ малі\ літери<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		&Негайний\ пошук<Tab>:set\ sm!
menutrans &Context\ lines	Кількість\ &важливих\ рядків
menutrans &Virtual\ Edit	Курсор\ &рухається\ без\ меж

menutrans Never			Ніколи
menutrans Block\ Selection	Вибір\ Блоку
menutrans Insert\ mode		Режим\ вставки
menutrans Block\ and\ Insert	Вибір\ і\ вставка
menutrans Always		Завжди

menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	Режим\ &вставки<Tab>:set\ im!
menutrans Search\ &Path\.\.\.	&Шлях\ пошуку\.\.\.
menutrans Ta&g\ Files\.\.\.	Файли\ &поміток\.\.\.


"
" GUI options
menutrans Toggle\ &Toolbar		Панель\ &інструментів
menutrans Toggle\ &Bottom\ Scrollbar	&Нижня\ лінійка\ зсуву
menutrans Toggle\ &Left\ Scrollbar	&Ліва\ лінійка\ зсуву
menutrans Toggle\ &Right\ Scrollbar	&Права\ лінійка\ зсуву

" Programming menu
menutrans &Tools			&Інструменти
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Перейти\ до\ помітки<Tab>g^]
menutrans Jump\ &back<Tab>^T		По&вернутися<Tab>^T
menutrans Build\ &Tags\ File		&Створити\ файл\ поміток
" Folding
menutrans &Folding				&Згортки
menutrans &Enable/Disable\ folds<Tab>zi		&Дозволити/заборонити\ згортки<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv			&Бачити\ рядок\ з\ курсором<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx			Бачити\ &лише\ рядок\ з\ курсором<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm				Закрити\ &більше\ згортків<Tab>zm
menutrans &Close\ all\ folds<Tab>zM				Закрити\ &усі\ згортки<Tab>zM
menutrans &Open\ all\ folds<Tab>zR				Відкрити\ у&сі\ згортки<Tab>zR
menutrans O&pen\ more\ folds<Tab>zr				Відкрити\ б&ільше\ згортків<Tab>zr

menutrans Create\ &Fold<Tab>zf				С&творити\ згорток<Tab>zf
menutrans &Delete\ Fold<Tab>zd				&Видалити\ згорток<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD		Видалит&и\ усі\ згортки<Tab>zD
menutrans Fold\ column\ &width				&Товщина\ рядка\ згортків
menutrans Fold\ Met&hod		&Метод\ згортання
menutrans M&anual			&Ручний
menutrans I&ndent			&Відступ
menutrans E&xpression       В&ираз
menutrans S&yntax			&Синтаксично
menutrans Ma&rker			По&значки

" Diff
menutrans &Diff					По&рівняння
menutrans &Update				&Поновити
menutrans &Get\ Block			&Запозичити\ різницю
menutrans &Put\ Block			&Впровадити\ різницю

" Make and stuff...
menutrans &Make<Tab>:make		&Будувати(make)<Tab>:make
menutrans &List\ Errors<Tab>:cl		&Список\ помилок<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	Сп&исок\ повідомлень<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		&Наступна\ помилка<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	&Попередня\ помилка<Tab>:cp
menutrans &Older\ List<Tab>:cold	&Бувші\ помилки<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	&Майбутні\ помилки<Tab>:cnew
menutrans Error\ &Window	    &Вікно\ помилок
menutrans &Update<Tab>:cwin			&Поновити<Tab>:cwin
menutrans &Close<Tab>:cclose		&Закрити<Tab>:cclose
menutrans &Open<Tab>:copen			&Відкрити<Tab>:copen

menutrans &Set\ Compiler				Встановити\ &компілятор
menutrans &Convert\ to\ HEX<Tab>:%!xxd     Перевести\ в\ шістнадцяткові\ коди<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r     Повернути\ в\ двійкову\ форму<Tab>:%!xxd\ -r

" Names for buffer menu.
menutrans &Buffers	&Буфери
menutrans &Refresh\ menu &Поновити
menutrans Delete	&Видалити
menutrans &Alternate	&Вторинний
menutrans &Next		&Слідуючий
menutrans &Previous	&Попередній
menutrans [No\ File]	[Немає\ Файла]

" Window menu
menutrans &Window			&Вікно
menutrans &New<Tab>^Wn			&Нове<Tab>^Wn
menutrans S&plit<Tab>^Ws		&Розділити<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	Розділити\ для\ &вторинного\ файлу<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Розділити\ &поперек<Tab>^Wv
"menutrans Split\ &Vertically<Tab>^Wv	&Розділити\ поперек<Tab>^Wv
menutrans Split\ File\ E&xplorer		Розділити\ для\ &перегляду\ файлів

menutrans &Close<Tab>^Wc		&Закрити<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Закрити\ усі\ &інші<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			&Наступне<Tab>^Ww
menutrans P&revious<Tab>^WW		&Попереднє<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Вирівняти\ розмір<Tab>^W=
menutrans &Max\ Height<Tab>^W_		Най&більша\ висота<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		Най&менша\ висота<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		Найбі&льша\ ширина<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Наймен&ша\ ширина<Tab>^W1\|
menutrans Move\ &To			&Змістити
menutrans &Top<Tab>^WK			До&гори<Tab>^WK
menutrans &Bottom<Tab>^WJ		До&низу<Tab>^WJ
menutrans &Left\ side<Tab>^WH		У&ліво<Tab>^WH
menutrans &Right\ side<Tab>^WL		В&право<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		&Циклічно\ догори<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Ц&иклічно\ униз<Tab>^Wr

" The popup menu
menutrans &Undo			&Відмінити
menutrans Cu&t			Ви&різати
menutrans &Copy			&Копіювати
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
    tmenu ToolBar.Open		Відкрити файл
    tmenu ToolBar.Save		Запам'ятати файл
    tmenu ToolBar.SaveAll		Запам'ятати усі файли
    tmenu ToolBar.Print		Друкувати
    tmenu ToolBar.Undo		Відмінити
    tmenu ToolBar.Redo		Повернути
    tmenu ToolBar.Cut		Вирізати
    tmenu ToolBar.Copy		Копіювати
    tmenu ToolBar.Paste		Вставити
    tmenu ToolBar.Find		Знайти...
    tmenu ToolBar.FindNext	Знайти наступний
    tmenu ToolBar.FindPrev	Знайти попередній
    tmenu ToolBar.Replace	Замінити...
    tmenu ToolBar.LoadSesn	Завантажити сеанс редагування
    tmenu ToolBar.SaveSesn	Запам'ятати сеанс редагування
    tmenu ToolBar.RunScript	Виконати файл команд
    tmenu ToolBar.Make		Збудувати проект
    tmenu ToolBar.Shell		Shell
    tmenu ToolBar.RunCtags	Створити файл поміток
    tmenu ToolBar.TagJump	Перейти до помітки
    tmenu ToolBar.Help		Допомога
    tmenu ToolBar.FindHelp	Пошук у допомозі
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
menutrans Co&lor\ test		Перевірка\ &кольорів
menutrans &Highlight\ test	&Перевірка\ виділення
menutrans &Convert\ to\ HTML	Створити\ &HTML

" dialog texts
let menutrans_no_file = "[Немає\ Файла]"
let menutrans_help_dialog = "Вкажіть команду або слово для пошуку:\n\nДодайте i_ для команд режиму вставки (напр. i_CTRL-X)\nДодайте i_ для командного режиму (напр. с_<Del>)\nДодайте ' для позначення назви опції (напр. 'shiftwidth')"
let g:menutrans_path_dialog = "Вкажіть шлях пошуку файлів\nРозділяйте назви директорій комами."
let g:menutrans_tags_dialog = "Вкажіть назви файлів поміток\nРозділяйте назви комами."
let g:menutrans_textwidth_dialog = "Вкажіть нову ширину тексту (0 для відміни фоматування)"
let g:menutrans_fileformat_dialog = "Виберіть формат файлу"

let &cpo = s:keepcpo
unlet s:keepcpo
