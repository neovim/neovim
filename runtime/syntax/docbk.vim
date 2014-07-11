" Vim syntax file
" Language:	DocBook
" Maintainer:	Devin Weaver <vim@tritarget.com>
" Last Updated By: Shlomi Fish
" URL:		http://tritarget.com/pub/vim/syntax/docbk.vim
" Last Change:	2012 Nov 28
" Version:	1.2 (and modified after that)
" Thanks to Johannes Zellner <johannes@zellner.org> for the default to XML
" suggestion.

" REFERENCES:
"   http://docbook.org/
"   http://www.open-oasis.org/docbook/
"

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Auto detect added by Bram Moolenaar
if !exists('b:docbk_type')
  if expand('%:e') == "sgml"
    let b:docbk_type = 'sgml'
  else
    let b:docbk_type = 'xml'
  endif
endif

if !exists('b:docbk_ver')
  if exists('docbk_ver')
    let b:docbk_ver = docbk_ver
  else
    let b:docbk_ver = 4
  endif
end

if 'xml' == b:docbk_type
    doau Syntax xml
    syn cluster xmlTagHook add=docbkKeyword
    syn cluster xmlRegionHook add=docbkRegion,docbkTitle,docbkRemark,docbkCite
    syn case match
elseif 'sgml' == b:docbk_type
    doau Syntax sgml
    syn cluster sgmlTagHook add=docbkKeyword
    syn cluster sgmlRegionHook add=docbkRegion,docbkTitle,docbkRemark,docbkCite
    syn case ignore
endif

syn keyword docbkKeyword abbrev abstract accel acronym address contained
syn keyword docbkKeyword affiliation alt anchor answer appendix contained
syn keyword docbkKeyword application area areaset areaspec arg contained
syn keyword docbkKeyword article artpagenums attribution audiodata contained
syn keyword docbkKeyword audioobject author authorgroup contained
syn keyword docbkKeyword authorinitials bibliocoverage bibliodiv contained
syn keyword docbkKeyword biblioentry bibliography biblioid contained
syn keyword docbkKeyword bibliolist bibliomisc bibliomixed contained
syn keyword docbkKeyword bibliomset biblioref bibliorelation contained
syn keyword docbkKeyword biblioset bibliosource blockquote book contained
syn keyword docbkKeyword bridgehead callout calloutlist caption contained
syn keyword docbkKeyword caution chapter citation citebiblioid contained
syn keyword docbkKeyword citerefentry citetitle city classname contained
syn keyword docbkKeyword classsynopsis classsynopsisinfo cmdsynopsis contained
syn keyword docbkKeyword co code col colgroup collab colophon contained
syn keyword docbkKeyword colspec command computeroutput confdates contained
syn keyword docbkKeyword confgroup confnum confsponsor conftitle contained
syn keyword docbkKeyword constant constructorsynopsis contractnum contained
syn keyword docbkKeyword contractsponsor contrib copyright coref contained
syn keyword docbkKeyword country database date dedication contained
syn keyword docbkKeyword destructorsynopsis edition editor email contained
syn keyword docbkKeyword emphasis entry entrytbl envar epigraph contained
syn keyword docbkKeyword equation errorcode errorname errortext contained
syn keyword docbkKeyword errortype example exceptionname fax contained
syn keyword docbkKeyword fieldsynopsis figure filename firstname contained
syn keyword docbkKeyword firstterm footnote footnoteref contained
syn keyword docbkKeyword foreignphrase formalpara funcdef funcparams contained
syn keyword docbkKeyword funcprototype funcsynopsis funcsynopsisinfo contained
syn keyword docbkKeyword function glossary glossdef glossdiv contained
syn keyword docbkKeyword glossentry glosslist glosssee glossseealso contained
syn keyword docbkKeyword glossterm group guibutton guiicon guilabel contained
syn keyword docbkKeyword guimenu guimenuitem guisubmenu hardware contained
syn keyword docbkKeyword holder honorific imagedata imageobject contained
syn keyword docbkKeyword imageobjectco important index indexdiv contained
syn keyword docbkKeyword indexentry indexterm informalequation contained
syn keyword docbkKeyword informalexample informalfigure contained
syn keyword docbkKeyword informaltable initializer inlineequation contained
syn keyword docbkKeyword inlinemediaobject interfacename issuenum contained
syn keyword docbkKeyword itemizedlist itermset jobtitle keycap contained
syn keyword docbkKeyword keycode keycombo keysym keyword keywordset contained
syn keyword docbkKeyword label legalnotice lineage lineannotation contained
syn keyword docbkKeyword link listitem literal literallayout contained
syn keyword docbkKeyword manvolnum markup mathphrase mediaobject contained
syn keyword docbkKeyword member menuchoice methodname methodparam contained
syn keyword docbkKeyword methodsynopsis modifier mousebutton msg contained
syn keyword docbkKeyword msgaud msgentry msgexplan msginfo msglevel contained
syn keyword docbkKeyword msgmain msgorig msgrel msgset msgsub contained
syn keyword docbkKeyword msgtext note olink ooclass ooexception contained
syn keyword docbkKeyword oointerface option optional orderedlist contained
syn keyword docbkKeyword orgdiv orgname otheraddr othercredit contained
syn keyword docbkKeyword othername package pagenums para paramdef contained
syn keyword docbkKeyword parameter part partintro personblurb contained
syn keyword docbkKeyword personname phone phrase pob postcode contained
syn keyword docbkKeyword preface primary primaryie printhistory contained
syn keyword docbkKeyword procedure productname productnumber contained
syn keyword docbkKeyword programlisting programlistingco prompt contained
syn keyword docbkKeyword property pubdate publisher publishername contained
syn keyword docbkKeyword qandadiv qandaentry qandaset question quote contained
syn keyword docbkKeyword refclass refdescriptor refentry contained
syn keyword docbkKeyword refentrytitle reference refmeta refmiscinfo contained
syn keyword docbkKeyword refname refnamediv refpurpose refsect1 contained
syn keyword docbkKeyword refsect2 refsect3 refsection refsynopsisdiv contained
syn keyword docbkKeyword releaseinfo remark replaceable returnvalue contained
syn keyword docbkKeyword revdescription revhistory revision contained
syn keyword docbkKeyword revnumber revremark row sbr screen screenco contained
syn keyword docbkKeyword screenshot secondary secondaryie sect1 contained
syn keyword docbkKeyword sect2 sect3 sect4 sect5 section see seealso contained
syn keyword docbkKeyword seealsoie seeie seg seglistitem contained
syn keyword docbkKeyword segmentedlist segtitle seriesvolnums set contained
syn keyword docbkKeyword setindex shortaffil shortcut sidebar contained
syn keyword docbkKeyword simpara simplelist simplemsgentry contained
syn keyword docbkKeyword simplesect spanspec state step contained
syn keyword docbkKeyword stepalternatives street subject subjectset contained
syn keyword docbkKeyword subjectterm subscript substeps subtitle contained
syn keyword docbkKeyword superscript surname symbol synopfragment contained
syn keyword docbkKeyword synopfragmentref synopsis systemitem table contained
syn keyword docbkKeyword task taskprerequisites taskrelated contained
syn keyword docbkKeyword tasksummary tbody td term termdef tertiary contained
syn keyword docbkKeyword tertiaryie textdata textobject tfoot tgroup contained
syn keyword docbkKeyword th thead tip title titleabbrev toc tocentry contained
syn keyword docbkKeyword token tr trademark type uri userinput contained
syn keyword docbkKeyword varargs variablelist varlistentry varname contained
syn keyword docbkKeyword videodata videoobject void volumenum contained
syn keyword docbkKeyword warning wordasword xref year contained

if b:docbk_ver == 4
  syn keyword docbkKeyword ackno action appendixinfo articleinfo contained
  syn keyword docbkKeyword authorblurb beginpage bibliographyinfo contained
  syn keyword docbkKeyword blockinfo bookinfo chapterinfo contained
  syn keyword docbkKeyword collabname corpauthor corpcredit contained
  syn keyword docbkKeyword corpname glossaryinfo graphic graphicco contained
  syn keyword docbkKeyword highlights indexinfo inlinegraphic contained
  syn keyword docbkKeyword interface invpartnumber isbn issn lot contained
  syn keyword docbkKeyword lotentry medialabel mediaobjectco contained
  syn keyword docbkKeyword modespec objectinfo partinfo contained
  syn keyword docbkKeyword prefaceinfo pubsnumber refentryinfo contained
  syn keyword docbkKeyword referenceinfo refsect1info refsect2info contained
  syn keyword docbkKeyword refsect3info refsectioninfo contained
  syn keyword docbkKeyword refsynopsisdivinfo screeninfo sect1info contained
  syn keyword docbkKeyword sect2info sect3info sect4info sect5info contained
  syn keyword docbkKeyword sectioninfo setindexinfo setinfo contained
  syn keyword docbkKeyword sgmltag sidebarinfo structfield contained
  syn keyword docbkKeyword structname tocback tocchap tocfront contained
  syn keyword docbkKeyword toclevel1 toclevel2 toclevel3 toclevel4 contained
  syn keyword docbkKeyword toclevel5 tocpart ulink contained

else
  syn keyword docbkKeyword acknowledgements annotation arc contained
  syn keyword docbkKeyword constraint constraintdef cover contained
  syn keyword docbkKeyword extendedlink givenname info lhs locator contained
  syn keyword docbkKeyword multimediaparam nonterminal org person contained
  syn keyword docbkKeyword production productionrecap contained
  syn keyword docbkKeyword productionset rhs tag tocdiv topic contained

endif

" Add special emphasis on some regions. Thanks to Rory Hunter <roryh@dcs.ed.ac.uk> for these ideas.
syn region docbkRegion start="<emphasis>"lc=10 end="</emphasis>"me=e-11 contains=xmlRegion,xmlEntity,sgmlRegion,sgmlEntity keepend
syn region docbkTitle  start="<title>"lc=7     end="</title>"me=e-8	contains=xmlRegion,xmlEntity,sgmlRegion,sgmlEntity keepend
syn region docbkRemark start="<remark>"lc=8    end="</remark>"me=e-9	contains=xmlRegion,xmlEntity,sgmlRegion,sgmlEntity keepend
syn region docbkRemark start="<comment>"lc=9  end="</comment>"me=e-10	contains=xmlRegion,xmlEntity,sgmlRegion,sgmlEntity keepend
syn region docbkCite   start="<citation>"lc=10 end="</citation>"me=e-11 contains=xmlRegion,xmlEntity,sgmlRegion,sgmlEntity keepend

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_docbk_syn_inits")
  if version < 508
    let did_docbk_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
    hi DocbkBold term=bold cterm=bold gui=bold
  else
    command -nargs=+ HiLink hi def link <args>
    hi def DocbkBold term=bold cterm=bold gui=bold
  endif

  HiLink docbkKeyword	Statement
  HiLink docbkRegion	DocbkBold
  HiLink docbkTitle	Title
  HiLink docbkRemark	Comment
  HiLink docbkCite	Constant

  delcommand HiLink
endif

let b:current_syntax = "docbk"

" vim: ts=8
