" Menu Translations: Português do Brasil
" Maintainer: José de Paula <jose@infoviaweb.com>
" Last Change: 2012 May 01
"

" Quit when menu translations have already been done.
if exists("did_menu_trans")
	finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

" Translations in latin1 (ISO-8859-1), and should work in
" latin9 (ISO-8859-15)

if &enc != "cp1252" && &enc != "iso-8859-15"
	scriptencoding latin1
endif

" Help menu
menutrans &Help			A&juda
menutrans &Overview<Tab><F1>	&Conteúdo
menutrans &User\ Manual		&Manual\ do\ Usuário
menutrans &How-to\ links	&Como\ fazer?
menutrans &Find\.\.\.		&Procurar\.\.\.
menutrans &Credits		&Créditos
menutrans O&rphans		&Órfãos
menutrans Co&pying		&Licença
menutrans &Sponsor/Register	&Doar/Registrar
menutrans &Version		&Versão
menutrans &About		&Sobre

" File menu
menutrans &File				&Arquivo
menutrans &Open\.\.\.<Tab>:e		A&brir\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Ab&rir\ em\ outra\ janela\.\.\.<Tab>:sp
menutrans &New<Tab>:enew		&Novo<Tab>:enew
menutrans &Close<Tab>:close		&Fechar<Tab>:close
menutrans &Save<Tab>:w			&Salvar<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Sa&lvar\ como\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	&Exibir\ diferenças\ com\.\.\.
menutrans Split\ Patched\ &By\.\.\.	Ex&ibir\ patcheado\ por\.\.\.
menutrans &Print			I&mprimir
menutrans Sa&ve-Exit<Tab>:wqa		Sal&var\ e\ sair<Tab>:wqa
menutrans E&xit<Tab>:qa			Sai&r<Tab>:qa

" Edit menu
menutrans &Edit				&Editar
menutrans &Undo<Tab>u			&Desfazer<Tab>u
menutrans &Redo<Tab>^R			&Refazer<Tab>u
menutrans Rep&eat<Tab>\.		Repe&tir<Tab>\.
menutrans Cu&t<Tab>"+x			Re&cortar<Tab>"+x
menutrans &Copy<Tab>"+y			Cop&iar<Tab>"+y
menutrans &Paste<Tab>"+gP		C&olar<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Colocar\ &antes<Tab>[p
menutrans Put\ &After<Tab>]p		Colocar\ &depois<Tab>]p
menutrans &Select\ all<Tab>ggVG		&Selecionar\ tudo<Tab>ggVG
menutrans &Find\.\.\.			&Procurar\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.	Procurar\ e\ substit&uir\.\.\.
menutrans Find\ and\ Rep&lace<Tab>:%s	Procurar\ e\ substit&uir<Tab>:%s
menutrans Find\ and\ Rep&lace		Procurar\ e\ substit&uir
menutrans Find\ and\ Rep&lace<Tab>:s	Procurar\ e\ substituir<Tab>:s
menutrans Settings\ &Window		&Opções
menutrans Startup\ &Settings		&Inicialização

" Edit/Global Settings
menutrans &Global\ Settings		Opções\ &Globais

menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Ativar/Desativar\ &Realce\ de\ Padrões<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		Ativar/Desativar\ &Ignorar\ maiúsculas<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		Ativar/Desativar\ &coincidências<Tab>:set\ sm!

menutrans &Context\ lines		Linhas\ de\ C&ontexto

menutrans &Virtual\ Edit		Edição\ &Virtual
menutrans Never				Nunca
menutrans Block\ Selection		Seleção\ de\ Bloco
menutrans Insert\ mode			Modo\ de\ inserção
menutrans Block\ and\ Insert		Bloco\ e\ inserção
menutrans Always			Sempre

menutrans Toggle\ Insert\ &Mode<Tab>:set\ im! Ativar/Desativar\ Modo\ de\ In&serção<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp! Ativar/Desativar\ Co&mpatibilidade\ com\ Vi<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.		Camin&ho\ de\ Busca\.\.\.
menutrans Ta&g\ Files\.\.\.		Arquivos\ de\ Tags\.\.\.

" GUI options
menutrans Toggle\ &Toolbar		Ocultar/Exibir\ Barra\ de\ &Ferramentas
menutrans Toggle\ &Bottom\ Scrollbar	Ocultar/Exibir\ Barra\ de\ &Rolagem\ Inferior
menutrans Toggle\ &Left\ Scrollbar	Ocultar/Exibir\ Barra\ de\ R&olagem\ Esquerda
menutrans Toggle\ &Right\ Scrollbar	Ocultar/Exibir\ Barra\ de\ Ro&lagem\ Direita
let g:menutrans_path_dialog = "Indique um caminho de procura para os arquivos.\nSepare os nomes dos diretórios com uma vírgula."
let g:menutrans_tags_dialog = "Indique os nomes dos arquivos de tags.\nSepare os nomes com uma vírgula."

" Edit/File Settings
menutrans F&ile\ Settings		Opções\ do\ &Arquivo

" Boolean options
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	Ativar/Desativar\ &numeração\ de\ linhas<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Ativar/Desativar\ modo\ &list<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Ativar/Desativar\ &quebra\ de\ linhas<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Ativar/Desativar\ quebra\ na\ &palavra<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		Ativar/Desativar\ expansão de tabs<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Ativar/Desativar\ &auto-indentação<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Ativar/Desativar\ indentação estilo &C<Tab>:set\ cin!

" other options
menutrans &Shiftwidth			Largura\ da\ &indentação

menutrans Soft\ &Tabstop		&Tabulação\ com\ espaços

menutrans Te&xt\ Width\.\.\.		Largura\ do\ te&xto\.\.\.
let g:menutrans_textwidth_dialog = "Digite a nova largura do texto (0 para desativar a formatação): "

menutrans &File\ Format\.\.\.		&Formato\ do\ arquivo\.\.\.
let g:menutrans_fileformat_dialog = "Selecione o formato para gravar o arquivo"

menutrans C&olor\ Scheme		Esquema\ de\ c&ores
menutrans default	padrão

menutrans Select\ Fo&nt\.\.\.		Selecionar\ fo&nte\.\.\.

menutrans &Keymap	&Mapa\ de\ teclado
menutrans None		Nenhum

" Programming menu
menutrans &Tools			&Ferramentas
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Pular\ para\ este\ tag<Tab>g^]
menutrans Jump\ &back<Tab>^T		&Voltar<Tab>^T
menutrans Build\ &Tags\ File		&Construir\ Arquivo\ de\ tags
menutrans &Spelling			&Ortografia
menutrans &Folding			&Dobra
menutrans &Make<Tab>:make		&Make<Tab>:make
menutrans &List\ Errors<Tab>:cl		&Lista\ de\ erros<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	Li&sta\ de\ mensagens<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		P&róximo\ erro<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	&Erro\ anterior<Tab>:cp
menutrans &Older\ List<Tab>:cold	Listar\ erros\ &antigos<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	Listar\ erros\ &novos<Tab>:cnew
menutrans Error\ &Window		&Janela\ de\ erros
menutrans Se&T\ Compiler		Def&inir\ Compilador
menutrans &Convert\ to\ HEX<Tab>:%!xxd	Converter\ para\ hexadecimal<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r	Conver&ter\ de\ volta<Tab>:%!xxd\ -r

" Tools.Spelling menu
menutrans &Spell Check On		&Ativar Correção Ortográfica
menutrans &Spell Check Off		&Desativar Correção Ortográfica
menutrans To &Next error<Tab>]s		&Próximo Erro<Tab>]s
menutrans To &Previous Error<Tab>[s	Erro A&nterior<Tab>[s
menutrans Suggest &Corrections<Tab>z=	&Sugerir Correções<Tab>z=
menutrans &Repeat correction<Tab>:spellrepall	&Repetir Correção<Tab>:spellrepall

menutrans Set\ language\ to\ "en"               Inglês
menutrans Set\ language\ to\ "en_au"            Inglês\ (en_au)
menutrans Set\ language\ to\ "en_ca"            Inglês\ (en_ca)
menutrans Set\ language\ to\ "en_gb"            Inglês\ (en_gb)
menutrans Set\ language\ to\ "en_nz"            Inglês\ (en_nz)
menutrans Set\ language\ to\ "en_us"            Inglês\ (en_us)

menutrans &Find\ More\ Languages                &Buscar mais idiomas

" Tools.Fold Menu
menutrans &Enable/Disable\ folds<Tab>zi		&Ativar/Desativar\ dobras<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv		&Ver\ linha\ do\ cursor<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx	Ve&r\ somente\ linha\ do\ cursor<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm		&Fechar\ mais\ dobras<Tab>zm
menutrans &Close\ all\ folds<Tab>zM		F&echar\ todas\ as\ dobras<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr		A&brir\ mais\ dobras<Tab>zr
menutrans &Open\ all\ folds<Tab>zR		Abr&ir\ todas\ as\ dobras<Tab>zR
" fold method
menutrans Fold\ Met&hod				&Modo\ de\ dobras
menutrans Create\ &Fold<Tab>zf			Criar\ &dobras<Tab>zf
menutrans &Delete\ Fold<Tab>zd			Remover\ d&obras<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD		Remover\ &todas\ as\ dobras<Tab>zD
" moving around in folds
menutrans Fold\ col&umn\ width			&Largura\ da\ coluna\ da\ dobra

" Tools.Diff Menu
menutrans &Update	&Atualizar
menutrans &Get\ Block	&Obter\ Bloco
menutrans &Put\ Block	&Pôr\ Bloco

" Tools.Error Menu
menutrans &Update<Tab>:cwin	&Atualizar<Tab>:cwin
menutrans &Open<Tab>:copen	A&brir<Tab>:copen
menutrans &Close<Tab>:cclose	&Fechar<Tab>:cclose

" Names for buffer menu.
menutrans &Buffers		&Buffers
menutrans &Refresh\ menu	A&tualizar\ menu
menutrans &Delete		&Apagar
menutrans &Alternate		A&lternar
menutrans &Next			P&róximo
menutrans &Previous		A&nterior
let g:menutrans_no_file = "[Sem arquivos]"

" Window menu
menutrans &Window			&Janela
menutrans &New<Tab>^Wn			N&ova<Tab>^Wn
menutrans S&plit<Tab>^Ws		&Dividir<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	D&ividir\ para\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Dividir\ &verticalmente<Tab>^Wv
menutrans Split\ File\ E&xplorer	&Abrir\ Gerenciador\ de\ arquivos
menutrans &Close<Tab>^Wc		&Fechar<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Fechar\ &outra(s)<Tab>^Wo
menutrans Move\ &To			Mover\ &para
menutrans &Top<Tab>^WK			A&cima<Tab>^WK
menutrans &Bottom<Tab>^WJ		A&baixo<Tab>^WJ
menutrans &Left\ side<Tab>^WH		Lado\ &esquerdo<Tab>^WH
menutrans &Right\ side<Tab>^WL		Lado\ di&reito<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		&Girar\ para\ cima<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Girar\ para\ bai&xo<Tab>^Wr
menutrans &Equal\ Size<Tab>^W=		Mesmo\ &Tamanho<Tab>^W=
menutrans &Max\ Height<Tab>^W_		Altura\ &Máxima<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		A&ltura\ Mínima<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		Larg&ura\ Máxima<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Largura\ Mí&nima<Tab>^W1\|

" The popup menu
menutrans &Undo			&Desfazer
menutrans Cu&t			Recor&tar
menutrans &Copy			&Copiar
menutrans &Paste		Co&lar
menutrans &Delete		&Apagar
menutrans Select\ Blockwise	Seleção\ de\ bloco
menutrans Select\ &Word		Selecionar\ &Palavra
menutrans Select\ &Line		Selecionar\ L&inha
menutrans Select\ &All		Selecionar\ T&udo

" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
	  tmenu ToolBar.Open	Abrir Arquivo
	  tmenu ToolBar.Save	Salvar Arquivo
	  tmenu ToolBar.SaveAll	Salvar Todos os arquivos
	  tmenu ToolBar.Print	Imprimir
	  tmenu ToolBar.Undo	Desfazer
	  tmenu ToolBar.Redo	Refazer
	  tmenu ToolBar.Cut	Recortar
	  tmenu ToolBar.Copy	Copiar
	  tmenu ToolBar.Paste	Colar
	  tmenu ToolBar.Find	Procurar...
	  tmenu ToolBar.FindNext	Procurar Próximo
	  tmenu ToolBar.FindPrev	Procurar Anterior
	  tmenu ToolBar.Replace		Procurar e Substituir
	  if 0	" disable; these are in the Windoze menu
		  tmenu ToolBar.New	Nova Janela
		  tmenu ToolBar.WinSplit	Dividir Janela
		  tmenu ToolBar.WinMax		Janela Máxima
		  tmenu ToolBar.WinMin		Janela Mínima
		  tmenu ToolBar.WinVSplit	Dividir Verticalmente
		  tmenu ToolBar.WinMaxWidth	Largura Máxima
		  tmenu ToolBar.WinMinWidth	Largura Mínima
		  tmenu ToolBar.WinClose	Fechar Janela
	  endif
	  tmenu ToolBar.LoadSesn	Carregar Sessão
	  tmenu ToolBar.SaveSesn	Salvar Sessão
	  tmenu ToolBar.RunScript	Executar script
	  tmenu ToolBar.Make		Make
	  tmenu ToolBar.Shell		Abrir um shell
	  tmenu ToolBar.RunCtags	Gerar um arquivo de tags
	  tmenu ToolBar.TagJump		Saltar para um tag
	  tmenu ToolBar.Help		Ajuda
	  tmenu ToolBar.FindHelp	Procurar na Ajuda
  endfun
endif

" Syntax menu
menutrans &Syntax			&Sintaxe
"menutrans &Show\ individual\ choices	E&xibir\ escolhas\ individuais
menutrans &Show\ filetypes\ in\ menu	E&xibir\ tipos\ de\ arquivos\ no\ menu
menutrans Set\ '&syntax'\ only		Ativar\ somente\ s&intaxe
menutrans Set\ '&filetype'\ too		Ativar\ também\ &tipo\ de\ arquivo
menutrans &Off				&Desativar
menutrans &Manual			&Manual
menutrans A&utomatic			A&utomática
menutrans on/off\ for\ &This\ file	Ativar/Desativar\ neste\ &arquivo
menutrans Co&lor\ test			T&este\ de\ cores
menutrans &Highlight\ test		Teste\ de\ &realce
menutrans &Convert\ to\ HTML		&Converter\ para\ HTML

" Find Help dialog text
let g:menutrans_help_dialog = "Digite um comando ou palavra para obter ajuda;\n\nAnteponha i_ para comandos de entrada (ex.: i_CTRL-X)\nAnteponha c_ para comandos da linha de comandos (ex.: c_<Del>)\nAnteponha ` para um nome de opção (ex.: `shiftwidth`)"

let &cpo = s:keepcpo
unlet s:keepcpo
