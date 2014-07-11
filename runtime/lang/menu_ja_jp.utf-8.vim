" vi:set ts=8 sts=8 sw=8 tw=0:
"
" Menu Translations:	Japanese (UTF-8)
" Translated By:	MURAOKA Taro  <koron.kaoriya@gmail.com>
" Last Change:		12-May-2013.
"
" Copyright (C) 2001-13 MURAOKA Taro <koron.kaoriya@gmail.com>
" THIS FILE IS DISTRIBUTED UNDER THE VIM LICENSE.

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding utf-8

" Help menu
menutrans &Help			ヘルプ(&H)
menutrans &Overview<Tab><F1>	概略(&O)<Tab><F1>
menutrans &User\ Manual		ユーザマニュアル(&U)
menutrans &How-to\ links	&How-toリンク
menutrans &Credits		クレジット(&C)
menutrans Co&pying		著作権情報(&P)
menutrans &Sponsor/Register	スポンサー/登録(&S)
menutrans O&rphans		孤児(&R)
menutrans &Version		バージョン情報(&V)
menutrans &About		Vimについて(&A)

let g:menutrans_help_dialog = "ヘルプを検索したいコマンドもしくは単語を入力してください:\n\n挿入モードのコマンドには i_ を先頭に付加します. (例: i_CTRL-X)\nコマンドライン編集コマンドには c_ を先頭に付加します. (例: c_<Del>)\nオプションの名前には ' を付加します. (例: 'shiftwidth')"

" File menu
menutrans &File				ファイル(&F)
menutrans &Open\.\.\.<Tab>:e		開く(&O)\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	分割して開く(&L)\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	タブページで開く<Tab>:tabnew
menutrans &New<Tab>:enew		新規作成(&N)<Tab>:enew
menutrans &Close<Tab>:close		閉じる(&C)<Tab>:close
menutrans &Save<Tab>:w			保存(&S)<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	名前を付けて保存(&A)\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	差分表示(&D)\.\.\.
menutrans Split\ Patched\ &By\.\.\.	パッチ結果を表示(&B)\.\.\.
menutrans &Print			印刷(&P)
menutrans Sa&ve-Exit<Tab>:wqa		保存して終了(&V)<Tab>:wqa
menutrans E&xit<Tab>:qa			終了(&X)<Tab>:qa

" Edit menu
menutrans &Edit				編集(&E)
menutrans &Undo<Tab>u			取り消す(&U)<Tab>u
menutrans &Redo<Tab>^R			もう一度やる(&R)<Tab>^R
menutrans Rep&eat<Tab>\.		繰り返す(&E)<Tab>\.
menutrans Cu&t<Tab>"+x			切り取り(&T)<Tab>"+x
menutrans &Copy<Tab>"+y			コピー(&C)<Tab>"+y
menutrans &Paste<Tab>"+gP		貼り付け(&P)<Tab>"+gP
menutrans Put\ &Before<Tab>[p		前に貼る(&B)<Tab>[p
menutrans Put\ &After<Tab>]p		後に貼る(&A)<Tab>]p
menutrans &Delete<Tab>x			消す(&D)<Tab>x
menutrans &Select\ All<Tab>ggVG		全て選択(&S)<Tab>ggVG
menutrans &Find\.\.\.			検索(&F)\.\.\.
menutrans &Find<Tab>/			検索(&F)<Tab>/
menutrans Find\ and\ Rep&lace\.\.\.	置換(&L)\.\.\.
menutrans Find\ and\ Rep&lace<Tab>:%s	置換(&L)<Tab>:%s
menutrans Find\ and\ Rep&lace<Tab>:s	置換(&L)<Tab>:s
"menutrans Options\.\.\.			オプション(&O)\.\.\.
menutrans Settings\ &Window		設定ウィンドウ(&W)
menutrans Startup\ &Settings		起動時の設定(&S)

" Edit/Global Settings
menutrans &Global\ Settings		全体設定(&G)
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!
	\	パターン強調切替(&H)<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!
	\	大小文字区別切替(&I)<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!
	\	マッチ表示切替(&S)<Tab>:set\ sm!
menutrans &Context\ lines		カーソル周辺行数(&C)
menutrans &Virtual\ Edit		仮想編集(&V)
menutrans Never				無効
menutrans Block\ Selection		ブロック選択時
menutrans Insert\ mode			挿入モード時
menutrans Block\ and\ Insert		ブロック/挿入モード時
menutrans Always			常時
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!
	\	挿入(初心者)モード切替(&M)<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!
	\	Vi互換モード切替(&O)<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.		検索パス(&P)\.\.\.
menutrans Ta&g\ Files\.\.\.		タグファイル(&G)\.\.\.
"
" GUI options
menutrans Toggle\ &Toolbar		ツールバー表示切替(&T)
menutrans Toggle\ &Bottom\ Scrollbar	スクロールバー(下)表示切替(&B)
menutrans Toggle\ &Left\ Scrollbar	スクロールバー(左)表示切替(&L)
menutrans Toggle\ &Right\ Scrollbar	スクロールバー(右)表示切替(&R)

let g:menutrans_path_dialog = "ファイルの検索パスを入力してください:\nディレクトリ名はカンマ ( , ) で区切ってください."
let g:menutrans_tags_dialog = "タグファイルの名前を入力してください:\n名前はカンマ ( , ) で区切ってください."

" Edit/File Settings

" Boolean options
menutrans F&ile\ Settings		ファイル設定(&I)
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!
	\	行番号表示切替(&N)<Tab>:set\ nu!
menutrans Toggle\ relati&ve\ Line\ Numbering<Tab>:set\ rnu!
	\	相対行番号表示切替(&V)<Tab>:set\ rnu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!
	\ リストモード切替(&L)<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!
	\	行折返し切替(&W)<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!
	\	単語折返し切替(&R)<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!
	\	タブ展開切替(&E)<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!
	\	自動字下げ切替(&A)<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!
	\	C言語字下げ切替(&C)<Tab>:set\ cin!

" other options
menutrans &Shiftwidth			シフト幅(&S)
menutrans Soft\ &Tabstop		ソフトウェアタブ幅(&T)
menutrans Te&xt\ Width\.\.\.		テキスト幅(&X)\.\.\.
menutrans &File\ Format\.\.\.		改行記号選択(&F)\.\.\.

let g:menutrans_textwidth_dialog = "テキストの幅('textwidth')を設定してください (0で整形を無効化):"
let g:menutrans_fileformat_dialog = "ファイル出力の際の改行記号の形式を選んでください."
let g:menutrans_fileformat_choices = "&Unix\n&Dos\n&Mac\nキャンセル(&C)"

menutrans C&olor\ Scheme		色テーマ選択(&O)
menutrans &Keymap			キーマップ(&K)
menutrans None				なし

" Programming menu
menutrans &Tools			ツール(&T)
menutrans &Jump\ to\ this\ tag<Tab>g^]	タグジャンプ(&J)<Tab>g^]
menutrans Jump\ &back<Tab>^T		戻る(&B)<Tab>^T
menutrans Build\ &Tags\ File		タグファイル作成(&T)
menutrans &Make<Tab>:make		メイク(&M)<Tab>:make
menutrans &List\ Errors<Tab>:cl		エラーリスト(&L)<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	メッセージリスト(&I)<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		次のエラーへ(&N)<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	前のエラーへ(&P)<Tab>:cp
menutrans &Older\ List<Tab>:cold	古いリスト(&O)<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	新しいリスト(&E)<Tab>:cnew
menutrans Error\ &Window		エラーウィンドウ(&W)
menutrans &Update<Tab>:cwin		更新(&U)<Tab>:cwin
menutrans &Open<Tab>:copen		開く(&O)<Tab>:copen
menutrans &Close<Tab>:cclose		閉じる(&C)<Tab>:cclose
menutrans &Convert\ to\ HEX<Tab>:%!xxd	HEXへ変換(&C)<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r	HEXから逆変換(&R)<Tab>%!xxd\ -r
menutrans Se&T\ Compiler		コンパイラ設定(&T)

" Tools.Spelling Menu
menutrans &Spelling			スペリング(&S)
menutrans &Spell\ Check\ On		スペルチェック有効(&S)
menutrans Spell\ Check\ &Off		スペルチェック無効(&O)
menutrans To\ &Next\ error<Tab>]s	次のエラー(&N)<Tab>]s
menutrans To\ &Previous\ error<Tab>[s	前のエラー(&P)<Tab>[s
menutrans Suggest\ &Corrections<Tab>z=	修正候補(&C)<Tab>z=
menutrans &Repeat\ correction<Tab>:spellrepall	修正を繰り返す(&R)<Tab>:spellrepall
menutrans Set\ language\ to\ "en"	言語を\ "en"\ に設定する
menutrans Set\ language\ to\ "en_au"	言語を\ "en_au"\ に設定する
menutrans Set\ language\ to\ "en_ca"	言語を\ "en_ca"\ に設定する
menutrans Set\ language\ to\ "en_gb"	言語を\ "en_gb"\ に設定する
menutrans Set\ language\ to\ "en_nz"	言語を\ "en_nz"\ に設定する
menutrans Set\ language\ to\ "en_us"	言語を\ "en_us"\ に設定する
menutrans &Find\ More\ Languages	他の言語を検索する(&F)

" Tools.Fold Menu
menutrans &Folding			折畳み(&F)
" open close folds
menutrans &Enable/Disable\ folds<Tab>zi	有効/無効切替(&E)<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv	カーソル行を表示(&V)<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx	カーソル行だけを表示(&W)<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm	折畳みを閉じる(&L)<Tab>zm
menutrans &Close\ all\ folds<Tab>zM	全折畳みを閉じる(&C)<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr	折畳みを開く(&P)<Tab>zr
menutrans &Open\ all\ folds<Tab>zR	全折畳みを開く(&O)<Tab>zR
" fold method
menutrans Fold\ Met&hod			折畳み方法(&H)
menutrans M&anual			手動(&A)
menutrans I&ndent			インデント(&N)
menutrans E&xpression			式評価(&X)
menutrans S&yntax			シンタックス(&Y)
menutrans &Diff				差分(&D)
menutrans Ma&rker			マーカー(&R)
" create and delete folds
menutrans Create\ &Fold<Tab>zf		折畳み作成(&F)<Tab>zf
menutrans &Delete\ Fold<Tab>zd		折畳み削除(&D)<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD	全折畳み削除(&A)<Tab>zD
" moving around in folds
menutrans Fold\ col&umn\ width		折畳みカラム幅(&U)

menutrans &Update		更新(&U)
menutrans &Get\ Block		ブロック抽出(&G)
menutrans &Put\ Block		ブロック適用(&P)

" Names for buffer menu.
menutrans &Buffers		バッファ(&B)
menutrans &Refresh\ menu	メニュー再読込(&R)
menutrans &Delete		削除(&D)
menutrans &Alternate		裏へ切替(&A)
menutrans &Next			次のバッファ(&N)
menutrans &Previous		前のバッファ(&P)
menutrans [No\ File]		[無題]
let g:menutrans_no_file = "[無題]"

" Window menu
menutrans &Window			ウィンドウ(&W)
menutrans &New<Tab>^Wn			新規作成(&N)<Tab>^Wn
menutrans S&plit<Tab>^Ws		分割(&P)<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	裏バッファへ分割(&L)<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	垂直分割(&V)<Tab>^Wv
menutrans Split\ File\ E&xplorer	ファイルエクスプローラ(&X)
menutrans &Close<Tab>^Wc		閉じる(&C)<Tab>^Wc
menutrans Move\ &To			移動(&T)
menutrans &Top<Tab>^WK			上(&T)<Tab>^WK
menutrans &Bottom<Tab>^WJ		下(&B)<Tab>^WJ
menutrans &Left\ side<Tab>^WH		左(&L)<Tab>^WH
menutrans &Right\ side<Tab>^WL		右(&R)<Tab>^WL
menutrans Close\ &Other(s)<Tab>^Wo	他を閉じる(&O)<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			次へ(&X)<Tab>^Ww
menutrans P&revious<Tab>^WW		前へ(&R)<Tab>^WW
menutrans &Equal\ Size<Tab>^W=	同じ高さに(&E)<Tab>^W=
menutrans &Max\ Height<Tab>^W_		最大高に(&M)<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		最小高に(&i)<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		最大幅に(&W)<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		最小幅に(&H)<Tab>^W1\|
menutrans Rotate\ &Up<Tab>^WR		上にローテーション(&U)<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		下にローテーション(&D)<Tab>^Wr
menutrans Select\ Fo&nt\.\.\.		フォント設定(&N)\.\.\.

" The popup menu
menutrans &Undo			取り消す(&U)
menutrans Cu&t			切り取り(&T)
menutrans &Copy			コピー(&C)
menutrans &Paste		貼り付け(&P)
menutrans &Delete		削除(&D)
menutrans Select\ Blockwise	矩形ブロック選択
menutrans Select\ &Word		単語選択(&W)
menutrans Select\ &Sentence	文選択(&S)
menutrans Select\ Pa&ragraph	段落選択(&R)
menutrans Select\ &Line		行選択(&L)
menutrans Select\ &Block	ブロック選択(&B)
menutrans Select\ &All		すべて選択(&A)

" The GUI toolbar (for Win32 or GTK)
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		ファイルを開く
    tmenu ToolBar.Save		現在のファイルを保存
    tmenu ToolBar.SaveAll	すべてのファイルを保存
    tmenu ToolBar.Print		印刷
    tmenu ToolBar.Undo		取り消し
    tmenu ToolBar.Redo		もう一度やる
    tmenu ToolBar.Cut		クリップボードへ切り取り
    tmenu ToolBar.Copy		クリップボードへコピー
    tmenu ToolBar.Paste		クリップボードから貼り付け
    tmenu ToolBar.Find		検索...
    tmenu ToolBar.FindNext	次を検索
    tmenu ToolBar.FindPrev	前を検索
    tmenu ToolBar.Replace	置換...
    if 0	" disabled; These are in the Windows menu
      tmenu ToolBar.New		新規ウィンドウ作成
      tmenu ToolBar.WinSplit	ウィンドウ分割
      tmenu ToolBar.WinMax	ウィンドウ最大化
      tmenu ToolBar.WinMin	ウィンドウ最小化
      tmenu ToolBar.WinClose	ウィンドウを閉じる
    endif
    tmenu ToolBar.LoadSesn	セッション読込
    tmenu ToolBar.SaveSesn	セッション保存
    tmenu ToolBar.RunScript	Vimスクリプト実行
    tmenu ToolBar.Make		プロジェクトをMake
    tmenu ToolBar.Shell		シェルを開く
    tmenu ToolBar.RunCtags	tags作成
    tmenu ToolBar.TagJump	タグジャンプ
    tmenu ToolBar.Help		Vimヘルプ
    tmenu ToolBar.FindHelp	Vimヘルプ検索
  endfun
endif

" Syntax menu
menutrans &Syntax		シンタックス(&S)
menutrans &Show\ filetypes\ in\ menu	対応形式をメニューに表示(&S)
menutrans Set\ '&syntax'\ only	'syntax'だけ設定(&S)
menutrans Set\ '&filetype'\ too	'filetype'も設定(&F)
menutrans &Off			無効化(&O)
menutrans &Manual		手動設定(&M)
menutrans A&utomatic		自動設定(&U)
menutrans on/off\ for\ &This\ file
	\	オン/オフ切替(&T)
menutrans Co&lor\ test		カラーテスト(&L)
menutrans &Highlight\ test	ハイライトテスト(&H)
menutrans &Convert\ to\ HTML	HTMLへコンバート(&C)

let &cpo = s:keepcpo
unlet s:keepcpo

" filler to avoid the line above being recognized as a modeline
" filler
