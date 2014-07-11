" Menu Translations:	Russian
" Maintainer:		Sergey Alyoshin <alyoshin.s@gmail.com>
" Previous Maintainer:	vassily ragosin <vrr[at]users.sourceforge.net>
" Last Change:		29 May 2013
" URL:			cvs://cvs.sf.net:/cvsroot/ruvim/extras/menu/menu_ru_ru.vim
"
" $Id: menu_ru_ru.vim,v 1.1 2004/06/13 16:09:10 vimboss Exp $
"
" Adopted for RuVim project by Vassily Ragosin.
" First translation: Tim Alexeevsky <realtim [at] mail.ru>,
" based on ukrainian translation by Bohdan Vlasyuk <bohdan@vstu.edu.ua>
"
"
" Quit when menu translations have already been done.
"
if exists("did_menu_trans")
   finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding koi8-r

" Top
menutrans &File				&Файл
menutrans &Edit				П&равка
menutrans &Tools			&Инструменты
menutrans &Syntax			&Синтаксис
menutrans &Buffers			&Буферы
menutrans &Window			&Окно
menutrans &Help				С&правка
"
"
"
" Help menu
menutrans &Overview<Tab><F1>		&Обзор<Tab><F1>
menutrans &User\ Manual			Руково&дство\ пользователя
menutrans &How-to\ links		&Как\ это\ сделать\.\.\.
menutrans &Find\.\.\.			&Поиск
"--------------------
menutrans &Credits			&Благодарности
menutrans Co&pying			&Распространение
menutrans &Sponsor/Register		Помо&щь/Регистрация
menutrans O&rphans			&Сироты
"--------------------
menutrans &Version			&Информация\ о\ программе
menutrans &About			&Заставка
"
"
" File menu
menutrans &Open\.\.\.<Tab>:e		&Открыть\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	По&делить\ окно\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	Открыть\ в&кладку\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew		&Новый<Tab>:enew
menutrans &Close<Tab>:close		&Закрыть<Tab>:close
"--------------------
menutrans &Save<Tab>:w			&Сохранить<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Сохранить\ &как\.\.\.<Tab>:sav
"--------------------
menutrans Split\ &Diff\ with\.\.\.	Ср&авнить\ с\.\.\.
menutrans Split\ Patched\ &By\.\.\.	Сравнить\ с\ применением\ зап&латки\.\.\.
"--------------------
menutrans &Print			На&печатать
menutrans Sa&ve-Exit<Tab>:wqa		Вы&ход\ с\ сохранением<Tab>:wqa
menutrans E&xit<Tab>:qa			&Выход<Tab>:qa
"
"
" Edit menu
menutrans &Undo<Tab>u			О&тменить<Tab>u
menutrans &Redo<Tab>^R			В&ернуть<Tab>^R
menutrans Rep&eat<Tab>\.		Повторит&ь<Tab>\.
"--------------------
menutrans Cu&t<Tab>"+x			&Вырезать<Tab>"+x
menutrans &Copy<Tab>"+y			&Копировать<Tab>"+y
menutrans &Paste<Tab>"+gP		Вк&леить<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Вклеить\ пере&д<Tab>[p
menutrans Put\ &After<Tab>]p		Вклеить\ по&сле<Tab>]p
menutrans &Delete<Tab>x			&Удалить<Tab>x
menutrans &Select\ All<Tab>ggVG		В&ыделить\ всё<Tab>ggVG
"--------------------
" Athena GUI only
menutrans &Find<Tab>/			&Поиск<Tab>/
menutrans Find\ and\ Rep&lace<Tab>:%s	Поиск\ и\ &замена<Tab>:%s
" End Athena GUI only
menutrans &Find\.\.\.<Tab>/		&Поиск\.\.\.<Tab>/
menutrans Find\ and\ Rep&lace\.\.\.	Поиск\ и\ &замена\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.<Tab>:%s	Поиск\ и\ &замена\.\.\.<Tab>:%s
menutrans Find\ and\ Rep&lace\.\.\.<Tab>:s	Поиск\ и\ &замена\.\.\.<Tab>:s
"--------------------
menutrans Settings\ &Window		Окно\ настройки\ &опций
menutrans Startup\ &Settings		Настройки\ запус&ка
menutrans &Global\ Settings		&Глобальные\ настройки
menutrans F&ile\ Settings		Настройки\ &файлов
menutrans C&olor\ Scheme		&Цветовая\ схема
menutrans &Keymap			Раскладка\ кл&авиатуры
menutrans Select\ Fo&nt\.\.\.		Выбор\ &шрифта\.\.\.
">>>----------------- Edit/Global settings
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Подсветка\ &найденных\ соответствий<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		&Регистронезависимый\ поиск<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		Показывать\ парные\ &элементы<Tab>:set\ sm!
menutrans &Context\ lines				Стр&ок\ вокруг\ курсора
menutrans &Virtual\ Edit				Вир&туальное\ редактирование
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		Режим\ &Вставки<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!		&Совместимость\ с\ Vi<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.				&Путь\ для\ поиска\ файлов\.\.\.
menutrans Ta&g\ Files\.\.\.				Файлы\ &меток\.\.\.
"
menutrans Toggle\ &Toolbar				&Инструментальная\ панель
menutrans Toggle\ &Bottom\ Scrollbar			Полоса\ прокрутки\ вни&зу
menutrans Toggle\ &Left\ Scrollbar			Полоса\ прокрутки\ с&лева
menutrans Toggle\ &Right\ Scrollbar			Полоса\ прокрутки\ спр&ава
">>>->>>------------- Edit/Global settings/Virtual edit
menutrans Never						Выключено
menutrans Block\ Selection				При\ выделении\ блока
menutrans Insert\ mode					В\ режиме\ Вставки
menutrans Block\ and\ Insert				При\ выделении\ блока\ и\ в\ режиме\ Вставки
menutrans Always					Включено\ всегда
">>>----------------- Edit/File settings
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	&Нумерация\ строк<Tab>:set\ nu!
menutrans Toggle\ relati&ve\ Line\ Numbering<Tab>:set\ rnu!	Относите&льная\ нумерация\ строк<Tab>:set\ nru!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Отобра&жение\ невидимых\ символов<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		&Перенос\ длинных\ строк<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Перенос\ &целых\ слов<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		Про&белы\ вместо\ табуляции<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Автоматическое\ форматирование\ &отступов<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Форматирование\ отступов\ в\ &стиле\ C<Tab>:set\ cin!
">>>---
menutrans &Shiftwidth					Вели&чина\ отступа
menutrans Soft\ &Tabstop				Ширина\ &табуляции
menutrans Te&xt\ Width\.\.\.				&Ширина\ текста\.\.\.
menutrans &File\ Format\.\.\.				&Формат\ файла\.\.\.
"
"
"
" Tools menu
menutrans &Jump\ to\ this\ tag<Tab>g^]			&Переход\ к\ метке<Tab>g^]
menutrans Jump\ &back<Tab>^T				&Вернуться\ назад<Tab>^T
menutrans Build\ &Tags\ File				Создать\ &файл\ меток
"-------------------
menutrans &Folding					Работа\ со\ &складками
menutrans &Spelling					Пр&авописание
menutrans &Diff						&Отличия\ (diff)
"-------------------
menutrans &Make<Tab>:make				Ко&мпиляция<Tab>:make
menutrans &List\ Errors<Tab>:cl				Список\ о&шибок<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!			Список\ все&х\ ошибок\ и\ предупреждений<Tab>:cl!
menutrans &Next\ Error<Tab>:cn				Следу&ющая\ ошибка<Tab>:cn
menutrans &Previous\ Error<Tab>:cp			П&редыдущая\ ошибка<Tab>:cp
menutrans &Older\ List<Tab>:cold			Более\ стар&ый\ список\ ошибок<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew			Более\ све&жий\ список\ ошибок<Tab>:cnew
menutrans Error\ &Window				Ок&но\ ошибок
menutrans Se&T\ Compiler				Выбор\ &компилятора
"-------------------
menutrans &Convert\ to\ HEX<Tab>:%!xxd			П&еревести\ в\ HEX<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r			Перевести\ и&з\ HEX<Tab>:%!xxd\ -r
">>>---------------- Tools/Spelling
menutrans &Spell\ Check\ On				&Вкл\ проверку\ правописания
menutrans Spell\ Check\ &Off				Вы&кл\ проверку\ правописания
menutrans To\ &Next\ error<Tab>]s			&Следующая\ ошибка
menutrans To\ &Previous\ error<Tab>[s			&Предыдущая\ ошибка
menutrans Suggest\ &Corrections<Tab>z=			Предложить\ исп&равления
menutrans &Repeat\ correction<Tab>:spellrepall		Пов&торить\ исправление\ для\ всех
"-------------------
menutrans Set\ language\ to\ "en"			Установить\ язык\ "en"
menutrans Set\ language\ to\ "en_au"			Установить\ язык\ "en_au"
menutrans Set\ language\ to\ "en_ca"			Установить\ язык\ "en_ca"
menutrans Set\ language\ to\ "en_gb"			Установить\ язык\ "en_gb"
menutrans Set\ language\ to\ "en_nz"			Установить\ язык\ "en_nz"
menutrans Set\ language\ to\ "en_us"			Установить\ язык\ "en_us"
menutrans &Find\ More\ Languages			&Найти\ больше\ языков
let g:menutrans_set_lang_to =				'Установить язык'
">>>---------------- Folds
menutrans &Enable/Disable\ folds<Tab>zi			Вкл/выкл\ &складки<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv			Открыть\ строку\ с\ &курсором<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx		Открыть\ &только\ строку\ с\ курсором<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm			Закрыть\ &больше\ складок<Tab>zm
menutrans &Close\ all\ folds<Tab>zM			Закрыть\ &все\ складки<Tab>zM
menutrans &Open\ all\ folds<Tab>zR			Откр&ыть\ все\ складки<Tab>zR
menutrans O&pen\ more\ folds<Tab>zr			Отк&рыть\ больше\ складок<Tab>zr
menutrans Fold\ Met&hod					&Метод\ складок
menutrans Create\ &Fold<Tab>zf				Со&здать\ складку<Tab>zf
menutrans &Delete\ Fold<Tab>zd				У&далить\ складку<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD			Удалить\ вс&е\ складки<Tab>zD
menutrans Fold\ col&umn\ width				&Ширина\ колонки\ складок
">>>->>>----------- Tools/Folds/Fold Method
menutrans M&anual					Вру&чную
menutrans I&ndent					О&тступ
menutrans E&xpression					&Выражение
menutrans S&yntax					&Синтаксис
menutrans Ma&rker					&Маркеры
">>>--------------- Tools/Diff
menutrans &Update					О&бновить
menutrans &Get\ Block					Изменить\ &этот\ буфер
menutrans &Put\ Block					Изменить\ &другой\ буфер
">>>--------------- Tools/Diff/Error window
menutrans &Update<Tab>:cwin				О&бновить<Tab>:cwin
menutrans &Close<Tab>:cclose				&Закрыть<Tab>:cclose
menutrans &Open<Tab>:copen				&Открыть<Tab>:copen
"
"
" Syntax menu
"
menutrans &Show\ filetypes\ in\ menu			Показать\ меню\ для\ выбора\ типа\ &файла
menutrans Set\ '&syntax'\ only				&Изменять\ только\ значение\ 'syntax'
menutrans Set\ '&filetype'\ too				Изменять\ &также\ значение\ 'filetype'
menutrans &Off						&Отключить
menutrans &Manual					Вру&чную
menutrans A&utomatic					&Автоматически
menutrans on/off\ for\ &This\ file			Вкл/выкл\ для\ &этого\ файла
menutrans Co&lor\ test					Проверка\ &цветов
menutrans &Highlight\ test				Проверка\ под&светки
menutrans &Convert\ to\ HTML				С&делать\ HTML\ с\ подсветкой
"
"
" Buffers menu
"
menutrans &Refresh\ menu				О&бновить\ меню
menutrans Delete					У&далить
menutrans &Alternate					&Соседний
menutrans &Next						С&ледующий
menutrans &Previous					&Предыдущий
menutrans [No\ File]					[Нет\ файла]
"
"
" Window menu
"
menutrans &New<Tab>^Wn					&Новое\ окно<Tab>^Wn
menutrans S&plit<Tab>^Ws				&Разделить\ окно<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^			Открыть\ &соседний\ файл\ в\ новом\ окне<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv			Разделить\ по\ &вертикали<Tab>^Wv
menutrans Split\ File\ E&xplorer			Открыть\ проводник\ по\ &файловой\ системе
"
menutrans &Close<Tab>^Wc				&Закрыть\ это\ окно<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo			Закрыть\ &остальные\ окна<Tab>^Wo
"
menutrans Move\ &To					&Переместить
menutrans Rotate\ &Up<Tab>^WR				Сдвинуть\ ввер&х<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr				Сдвинуть\ в&низ<Tab>^Wr
"
menutrans &Equal\ Size<Tab>^W=				О&динаковый\ размер<Tab>^W=
menutrans &Max\ Height<Tab>^W_				Максимальная\ в&ысота<Tab>^W_
menutrans M&in\ Height<Tab>^W1_				Минимальная\ высо&та<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|				Максимальная\ &ширина<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|				Минимал&ьная\ ширина<Tab>^W1\|
">>>----------------- Window/Move To
menutrans &Top<Tab>^WK					В&верх<Tab>^WK
menutrans &Bottom<Tab>^WJ				В&низ<Tab>^WJ
menutrans &Left\ side<Tab>^WH				В&лево<Tab>^WH
menutrans &Right\ side<Tab>^WL				В&право<Tab>^WL
"
"
" The popup menu
"
"
menutrans &Undo						О&тменить
menutrans Cu&t						&Вырезать
menutrans &Copy						&Копировать
menutrans &Paste					Вк&леить
menutrans &Delete					&Удалить
menutrans Select\ Blockwise				Блоковое\ выделение
menutrans Select\ &Word					Выделить\ &слово
menutrans Select\ &Line					Выделить\ ст&року
menutrans Select\ &Block				Выделить\ &блок
menutrans Select\ &All					В&ыделить\ &всё
"
" The GUI toolbar
"
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open					Открыть файл
    tmenu ToolBar.Save					Сохранить файл
    tmenu ToolBar.SaveAll				Сохранить все файлы
    tmenu ToolBar.Print					Напечатать
    tmenu ToolBar.Undo					Отменить
    tmenu ToolBar.Redo					Вернуть
    tmenu ToolBar.Cut					Вырезать
    tmenu ToolBar.Copy					Копировать
    tmenu ToolBar.Paste					Вклеить
    tmenu ToolBar.Find					Поиск...
    tmenu ToolBar.FindNext				Поиск следующего соответствия
    tmenu ToolBar.FindPrev				Поиск предыдущего соответствия
    tmenu ToolBar.Replace				Заменить...
    tmenu ToolBar.LoadSesn				Загрузить сеанс редактирования
    tmenu ToolBar.SaveSesn				Сохранить сеанс редактирования
    tmenu ToolBar.RunScript				Выполнить сценарий Vim
    tmenu ToolBar.Make					Компиляция
    tmenu ToolBar.Shell					Оболочка
    tmenu ToolBar.RunCtags				Создать файл меток
    tmenu ToolBar.TagJump				Перейти к метке
    tmenu ToolBar.Help					Справка
    tmenu ToolBar.FindHelp				Найти справку
  endfun
endif
"
"
" Dialog texts
"
" Find in help dialog
"
let g:menutrans_help_dialog = "Введите команду или слово для поиска:\n\nДобавьте i_ для поиска команд режима Вставки (например, i_CTRL-X)\nДобавьте c_ для поиска команд Обычного режима (например, с_<Del>)\nДобавьте ' для поиска справки по опции (например, 'shiftwidth')"
"
" Searh path dialog
"
let g:menutrans_path_dialog = "Укажите путь для поиска файлов.\nИмена каталогов разделяются запятыми."
"
" Tag files dialog
"
let g:menutrans_tags_dialog = "Введите имена файлов меток (через запятую).\n"
"
" Text width dialog
"
let g:menutrans_textwidth_dialog = "Введите ширину текста для форматирования.\nДля отмены форматирования введите 0."
"
" File format dialog
"
let g:menutrans_fileformat_dialog = "Выберите формат файла."
let g:menutrans_fileformat_choices = "&Unix\n&Dos\n&Mac\nО&тмена"
"
let menutrans_no_file = "[Нет файла]"

let &cpo = s:keepcpo
unlet s:keepcpo
