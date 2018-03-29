" Vim syntax file
" Language:     SAS
" Maintainer:   Zhen-Huan Hu <wildkeny@gmail.com>
" Original Maintainer: James Kidd <james.kidd@covance.com>
" Version:      3.0.0
" Last Change:  Aug 26, 2017
"
" 2017 Mar 7
"
" Upgrade version number to 3.0. Improvements include:
" - Improve sync speed
" - Largely enhance precision
" - Update keywords in the latest SAS (as of Mar 2017)
" - Add syntaxes for date/time constants
" - Add syntax for data lines
" - Add (back) syntax for TODO in comments
"
" 2017 Feb 9
"
" Add syntax folding 
"
" 2016 Oct 10
"
" Add highlighting for functions
"
" 2016 Sep 14
"
" Change the implementation of syntaxing
" macro function names so that macro parameters same
" as SAS keywords won't be highlighted
" (Thank Joug Raw for the suggestion)
" Add section highlighting:
" - Use /** and **/ to define a section
" - It functions the same as a comment but
"   with different highlighting
"
" 2016 Jun 14
"
" Major changes so upgrade version number to 2.0
" Overhaul the entire script (again). Improvements include:
" - Higher precision
" - Faster synchronization
" - Separate color for control statements
" - Highlight hash and java objects
" - Highlight macro variables in double quoted strings
" - Update all syntaxes based on SAS 9.4
" - Add complete SAS/GRAPH and SAS/STAT procedure syntaxes
" - Add Proc TEMPLATE and GTL syntaxes
" - Add complete DS2 syntaxes
" - Add basic IML syntaxes
" - Many other improvements and bug fixes
" Drop support for VIM version < 600

if version < 600
  syntax clear
elseif exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore

" Basic SAS syntaxes
syn keyword sasOperator and eq ge gt in le lt ne not of or
syn keyword sasReserved _all_ _automatic_ _char_ _character_ _data_ _infile_ _last_ _n_ _name_ _null_ _num_ _numeric_ _temporary_ _user_ _webout_
" Strings
syn region sasString start=+'+ skip=+''+ end=+'+ contains=@Spell
syn region sasString start=+"+ skip=+""+ end=+"+ contains=sasMacroVariable,@Spell
" Constants
syn match sasNumber /\v<\d+%(\.\d+)=%(>|e[\-+]=\d+>)/ display
syn match sasDateTime /\v(['"])\d{2}%(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\d{2}%(\d{2})=:\d{2}:\d{2}%(:\d{2})=%(am|pm)\1dt>/ display
syn match sasDateTime /\v(['"])\d{2}%(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\d{2}%(\d{2})=\1d>/ display
syn match sasDateTime /\v(['"])\d{2}:\d{2}%(:\d{2})=%(am|pm)\1t>/ display
" Comments
syn keyword sasTodo todo tbd fixme contained
syn region sasComment start='/\*' end='\*/' contains=sasTodo
syn region sasComment start='\v%(^|;)\s*\zs\%=\*' end=';'me=s-1 contains=sasTodo
syn region sasSectLbl matchgroup=sasSectLblEnds start='/\*\*\s*' end='\s*\*\*/' concealends
" Macros
syn match sasMacroVariable '\v\&+\w+%(\.\w+)=' display
syn match sasMacroReserved '\v\%%(abort|by|copy|display|do|else|end|global|goto|if|include|input|let|list|local|macro|mend|put|return|run|symdel|syscall|sysexec|syslput|sysrput|then|to|until|window|while)>' display
syn region sasMacroFunction matchgroup=sasMacroFunctionName start='\v\%\w+\ze\(' end=')'he=s-1 contains=@sasBasicSyntax,sasMacroFunction
syn region sasMacroFunction matchgroup=sasMacroFunctionName start='\v\%q=sysfunc\ze\(' end=')'he=s-1 contains=@sasBasicSyntax,sasMacroFunction,sasDataStepFunction
" Syntax cluster for basic SAS syntaxes
syn cluster sasBasicSyntax contains=sasOperator,sasReserved,sasNumber,sasDateTime,sasString,sasComment,sasMacroReserved,sasMacroFunction,sasMacroVariable,sasSectLbl

" Formats
syn match sasFormat '\v\$\w+\.' display contained
syn match sasFormat '\v<\w+\.%(\d+>)=' display contained
syn region sasFormatContext start='.' end=';'me=s-1 contained contains=@sasBasicSyntax,sasFormat

" Define global statements that can be accessed out of data step or procedures
syn keyword sasGlobalStatementKeyword catname dm endsas filename footnote footnote1 footnote2 footnote3 footnote4 footnote5 footnote6 footnote7 footnote8 footnote9 footnote10 missing libname lock ods options page quit resetline run sasfile skip sysecho title title1 title2 title3 title4 title5 title6 title7 title8 title9 title10 contained
syn keyword sasGlobalStatementODSKeyword chtml csvall docbook document escapechar epub epub2 epub3 exclude excel graphics html html3 html5 htmlcss imode listing markup output package path pcl pdf preferences phtml powerpoint printer proclabel proctitle ps results rtf select show tagsets trace usegopt verify wml contained
syn match sasGlobalStatement '\v%(^|;)\s*\zs\h\w*>' display transparent contains=sasGlobalStatementKeyword
syn match sasGlobalStatement '\v%(^|;)\s*\zsods>' display transparent contains=sasGlobalStatementKeyword nextgroup=sasGlobalStatementODSKeyword skipwhite skipnl skipempty

" Data step statements, 9.4
syn keyword sasDataStepFunctionName abs addr addrlong airy allcomb allperm anyalnum anyalpha anycntrl anydigit anyfirst anygraph anylower anyname anyprint anypunct anyspace anyupper anyxdigit arcos arcosh arsin arsinh artanh atan atan2 attrc attrn band beta betainv blackclprc blackptprc blkshclprc blkshptprc blshift bnot bor brshift bxor byte cat catq cats catt catx cdf ceil ceilz cexist char choosec choosen cinv close cmiss cnonct coalesce coalescec collate comb compare compbl compfuzz compged complev compound compress constant convx convxp cos cosh cot count countc countw csc css cumipmt cumprinc curobs cv daccdb daccdbsl daccsl daccsyd dacctab dairy datdif date datejul datepart datetime day dclose dcreate depdb depdbsl depsl depsyd deptab dequote deviance dhms dif digamma dim dinfo divide dnum dopen doptname doptnum dosubl dread dropnote dsname dsncatlgd dur durp effrate envlen erf erfc euclid exist exp fact fappend fclose fcol fcopy fdelete fetch fetchobs fexist fget fileexist filename fileref finance find findc findw finfo finv fipname fipnamel fipstate first floor floorz fmtinfo fnonct fnote fopen foptname foptnum fpoint fpos fput fread frewind frlen fsep fuzz fwrite gaminv gamma garkhclprc garkhptprc gcd geodist geomean geomeanz getoption getvarc getvarn graycode harmean harmeanz hbound hms holiday holidayck holidaycount holidayname holidaynx holidayny holidaytest hour htmldecode htmlencode ibessel ifc ifn index indexc indexw input inputc inputn int intcindex intck intcycle intfit intfmt intget intindex intnx intrr intseas intshift inttest intz iorcmsg ipmt iqr irr jbessel juldate juldate7 kurtosis lag largest lbound lcm lcomb left length lengthc lengthm lengthn lexcomb lexcombi lexperk lexperm lfact lgamma libname libref log log1px log10 log2 logbeta logcdf logistic logpdf logsdf lowcase lperm lpnorm mad margrclprc margrptprc max md5 mdy mean median min minute missing mod modexist module modulec modulen modz month mopen mort msplint mvalid contained
syn keyword sasDataStepFunctionName n netpv nliteral nmiss nomrate normal notalnum notalpha notcntrl notdigit note notfirst notgraph notlower notname notprint notpunct notspace notupper notxdigit npv nvalid nwkdom open ordinal pathname pctl pdf peek peekc peekclong peeklong perm pmt point poisson ppmt probbeta probbnml probbnrm probchi probf probgam probhypr probit probmc probnegb probnorm probt propcase prxchange prxmatch prxparen prxparse prxposn ptrlongadd put putc putn pvp qtr quantile quote ranbin rancau rand ranexp rangam range rank rannor ranpoi rantbl rantri ranuni rename repeat resolve reverse rewind right rms round rounde roundz saving savings scan sdf sec second sha256 sha256hex sha256hmachex sign sin sinh skewness sleep smallest soapweb soapwebmeta soapwipservice soapwipsrs soapws soapwsmeta soundex spedis sqrt squantile std stderr stfips stname stnamel strip subpad substr substrn sum sumabs symexist symget symglobl symlocal sysexist sysget sysmsg sysparm sysprocessid sysprocessname sysprod sysrc system tan tanh time timepart timevalue tinv tnonct today translate transtrn tranwrd trigamma trim trimn trunc tso typeof tzoneid tzonename tzoneoff tzones2u tzoneu2s uniform upcase urldecode urlencode uss uuidgen var varfmt varinfmt varlabel varlen varname varnum varray varrayx vartype verify vformat vformatd vformatdx vformatn vformatnx vformatw vformatwx vformatx vinarray vinarrayx vinformat vinformatd vinformatdx vinformatn vinformatnx vinformatw vinformatwx vinformatx vlabel vlabelx vlength vlengthx vname vnamex vtype vtypex vvalue vvaluex week weekday whichc whichn wto year yieldp yrdif yyq zipcity zipcitydistance zipfips zipname zipnamel zipstate contained
syn keyword sasDataStepCallRoutineName allcomb allcombi allperm cats catt catx compcost execute graycode is8601_convert label lexcomb lexcombi lexperk lexperm logistic missing module poke pokelong prxchange prxdebug prxfree prxnext prxposn prxsubstr ranbin rancau rancomb ranexp rangam rannor ranperk ranperm ranpoi rantbl rantri ranuni scan set sleep softmax sortc sortn stdize streaminit symput symputx system tanh tso vname vnext wto contained
syn region sasDataStepFunctionContext start='(' end=')' contained contains=@sasBasicSyntax,sasDataStepFunction
syn region sasDataStepFunctionFormatContext start='(' end=')' contained contains=@sasBasicSyntax,sasDataStepFunction,sasFormat
syn match sasDataStepFunction '\v<\w+\ze\(' contained contains=sasDataStepFunctionName,sasDataStepCallRoutineName nextgroup=sasDataStepFunctionContext
syn match sasDataStepFunction '\v%(input|put)\ze\(' contained contains=sasDataStepFunctionName nextgroup=sasDataStepFunctionFormatContext
syn keyword sasDataStepHashMethodName add check clear definedata definedone definekey delete do_over equals find find_next find_prev first has_next has_prev last next output prev ref remove removedup replace replacedup reset_dup setcur sum sumdup contained
syn region sasDataStepHashMethodContext start='(' end=')' contained contains=@sasBasicSyntax,sasDataStepFunction
syn match sasDataStepHashMethod '\v\.\w+\ze\(' contained contains=sasDataStepHashMethodName nextgroup=sasDataStepHashMethodContext
syn keyword sasDataStepHashAttributeName item_size num_items contained
syn match sasDataStepHashAttribute '\v\.\w+>\ze\_[^(]' display contained contains=sasDataStepHashAttributeName
syn keyword sasDataStepControl continue do end go goto if leave link otherwise over return select to until when while contained
syn keyword sasDataStepControl else then contained nextgroup=sasDataStepStatementKeyword skipwhite skipnl skipempty
syn keyword sasDataStepHashOperator _new_ contained
syn keyword sasDataStepStatementKeyword abort array attrib by call cards cards4 datalines datalines4 dcl declare delete describe display drop error execute file format infile informat input keep label length lines lines4 list lostcard merge modify output put putlog redirect remove rename replace retain set stop update where window contained
syn keyword sasDataStepStatementHashKeyword hash hiter javaobj contained
syn match sasDataStepStatement '\v%(^|;)\s*\zs\h\w*>' display contained contains=sasDataStepStatementKeyword,sasGlobalStatementKeyword
syn match sasDataStepStatement '\v%(^|;)\s*\zs%(dcl|declare)>' display contained contains=sasDataStepStatementKeyword nextgroup=sasDataStepStatementHashKeyword skipwhite skipnl skipempty
syn match sasDataStepStatement '\v%(^|;)\s*\zsods>' display contained contains=sasGlobalStatementKeyword nextgroup=sasGlobalStatementODSKeyword skipwhite skipnl skipempty
syn match sasDataStepStatement '\v%(^|;)\s*\zs%(format|informat|input|put)>' display contained contains=sasDataStepStatementKeyword nextgroup=sasFormatContext skipwhite skipnl skipempty
syn match sasDataStepStatement '\v%(^|;)\s*\zs%(cards|datalines|lines)4=\s*;' display contained contains=sasDataStepStatementKeyword nextgroup=sasDataLine skipwhite skipnl skipempty
syn region sasDataLine start='^' end='^\s*;'me=s-1 contained
syn region sasDataStep matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsdata>' end='\v%(^|;)\s*%(run|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,@sasDataStepSyntax
syn cluster sasDataStepSyntax contains=sasDataStepFunction,sasDataStepHashOperator,sasDataStepHashAttribute,sasDataStepHashMethod,sasDataStepControl,sasDataStepStatement

" Procedures, base SAS, 9.4
syn keyword sasProcStatementKeyword abort age append array attrib audit block break by calid cdfplot change checkbox class classlev column compute contents copy create datarow dbencoding define delete deletefunc deletesubr delimiter device dialog dur endcomp exact exchange exclude explore fin fmtlib fontfile fontpath format formats freq function getnames guessingrows hbar hdfs histogram holidur holifin holistart holivar id idlabel informat inset invalue item key keylabel keyword label line link listfunc listsubr mapmiss mapreduce mean menu messages meta modify opentype outargs outdur outfin output outstart pageby partial picture pie pig plot ppplot printer probplot profile prompter qqplot radiobox ranks rbreak rbutton rebuild record remove rename repair report roptions save select selection separator source star start statistics struct submenu subroutine sum sumby table tables test text trantab truetype type1 types value var vbar ways weight where with write contained
syn match sasProcStatement '\v%(^|;)\s*\zs\h\w*>' display contained contains=sasProcStatementKeyword,sasGlobalStatementKeyword
syn match sasProcStatement '\v%(^|;)\s*\zsods>' display contained contains=sasGlobalStatementKeyword nextgroup=sasGlobalStatementODSKeyword skipwhite skipnl skipempty
syn match sasProcStatement '\v%(^|;)\s*\zs%(format|informat)>' display contained contains=sasProcStatementKeyword nextgroup=sasFormatContext skipwhite skipnl skipempty
syn region sasProc matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc%(\s+\h\w*)=>' end='\v%(^|;)\s*%(run|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasDataStepFunction,sasProcStatement
syn region sasProc matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc\s+%(catalog|chart|datasets|document|plot)>' end='\v%(^|;)\s*%(quit|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasDataStepFunction,sasProcStatement

" Procedures, SAS/GRAPH, 9.4
syn keyword sasGraphProcStatementKeyword add area axis bar block bubble2 byline cc ccopy cdef cdelete chart cmap choro copy delete device dial donut exclude flow format fs goptions gout grid group hbar hbar3d hbullet hslider htrafficlight id igout label legend list modify move nobyline note pattern pie pie3d plot plot2 preview prism quit rename replay select scatter speedometer star surface symbol tc tcopy tdef tdelete template tile toggle treplay vbar vbar3d vtrafficlight vbullet vslider where contained
syn match sasGraphProcStatement '\v%(^|;)\s*\zs\h\w*>' display contained contains=sasGraphProcStatementKeyword,sasGlobalStatementKeyword
syn match sasGraphProcStatement '\v%(^|;)\s*\zsformat>' display contained contains=sasGraphProcStatementKeyword nextgroup=sasFormatContext skipwhite skipnl skipempty
syn region sasGraphProc matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc\s+%(g3d|g3grid|ganno|gcontour|gdevice|geocode|gfont|ginside|goptions|gproject|greduce|gremove|mapimport)>' end='\v%(^|;)\s*%(run|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasDataStepFunction,sasGraphProcStatement
syn region sasGraphProc matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc\s+%(gareabar|gbarline|gchart|gkpi|gmap|gplot|gradar|greplay|gslide|gtile)>' end='\v%(^|;)\s*%(quit|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasDataStepFunction,sasGraphProcStatement

" Procedures, SAS/STAT, 14.1
syn keyword sasAnalyticalProcStatementKeyword absorb add array assess baseline bayes beginnodata bivar bootstrap bounds by cdfplot cells class cluster code compute condition contrast control coordinates copy cosan cov covtest coxreg der design determ deviance direct directions domain effect effectplot effpart em endnodata equality estimate exact exactoptions factor factors fcs filter fitindex format freq fwdlink gender grid group grow hazardratio height hyperprior id impjoint inset insetgroup invar invlink ippplot lincon lineqs lismod lmtests location logistic loglin lpredplot lsmeans lsmestimate manova matings matrix mcmc mean means missmodel mnar model modelaverage modeleffects monotone mstruct mtest multreg name nlincon nloptions oddsratio onecorr onesamplefreq onesamplemeans onewayanova outfiles output paired pairedfreq pairedmeans parameters parent parms partial partition path pathdiagram pcov performance plot population poststrata power preddist predict predpplot priors process probmodel profile prune pvar ram random ratio reference refit refmodel renameparm repeated replicate repweights response restore restrict retain reweight ridge rmsstd roc roccontrast rules samplesize samplingunit seed size scale score selection show simtests simulate slice std stderr store strata structeq supplementary table tables test testclass testfreq testfunc testid time transform treatments trend twosamplefreq twosamplemeans towsamplesurvival twosamplewilcoxon uds units univar var variance varnames weight where with zeromodel contained
syn match sasAnalyticalProcStatement '\v%(^|;)\s*\zs\h\w*>' display contained contains=sasAnalyticalProcStatementKeyword,sasGlobalStatementKeyword
syn match sasAnalyticalProcStatement '\v%(^|;)\s*\zsods>' display contained contains=sasGlobalStatementKeyword nextgroup=sasGlobalStatementODSKeyword skipwhite skipnl skipempty
syn match sasAnalyticalProcStatement '\v%(^|;)\s*\zsformat>' display contained contains=sasAnalyticalProcStatementKeyword nextgroup=sasFormatContext skipwhite skipnl skipempty
syn region sasAnalyticalProc matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc\s+%(aceclus|adaptivereg|bchoice|boxplot|calis|cancorr|candisc|cluster|corresp|discrim|distance|factor|fastclus|fmm|freq|gam|gampl|gee|genmod|glimmix|glmmod|glmpower|glmselect|hpcandisc|hpfmm|hpgenselect|hplmixed|hplogistic|hpmixed|hpnlmod|hppls|hpprincomp|hpquantselect|hpreg|hpsplit|iclifetest|icphreg|inbreed|irt|kde|krige2d|lattice|lifereg|lifetest|loess|logistic|mcmc|mds|mi|mianalyze|mixed|modeclus|multtest|nested|nlin|nlmixed|npar1way|orthoreg|phreg|plm|pls|power|princomp|prinqual|probit|quantlife|quantreg|quantselect|robustreg|rsreg|score|seqdesign|seqtest|sim2d|simnormal|spp|stdize|stdrate|stepdisc|surveyfreq|surveyimpute|surveylogistic|surveymeans|surveyphreg|surveyreg|surveyselect|tpspline|transreg|tree|ttest|varclus|varcomp|variogram)>' end='\v%(^|;)\s*%(run|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasDataStepControl,sasDataStepFunction,sasAnalyticalProcStatement
syn region sasAnalyticalProc matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc\s+%(anova|arima|catmod|factex|glm|model|optex|plan|reg)>' end='\v%(^|;)\s*%(quit|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasDataStepControl,sasDataStepFunction,sasAnalyticalProcStatement

" Procedures, ODS graphics, 9.4
syn keyword sasODSGraphicsProcStatementKeyword band block bubble by colaxis compare dattrvar density dot dropline dynamic ellipse ellipseparm format fringe gradlegend hbar hbarbasic hbarparm hbox heatmap heatmapparm highlow histogram hline inset keylegend label lineparm loess matrix needle parent panelby pbspline plot polygon refline reg rowaxis scatter series spline step style styleattrs symbolchar symbolimage text vbar vbarbasic vbarparm vbox vector vline waterfall where xaxis x2axis yaxis y2axis yaxistable contained
syn match sasODSGraphicsProcStatement '\v%(^|;)\s*\zs\h\w*>' display contained contains=sasODSGraphicsProcStatementKeyword,sasGlobalStatementKeyword
syn match sasODSGraphicsProcStatement '\v%(^|;)\s*\zsods>' display contained contains=sasGlobalStatementKeyword nextgroup=sasGlobalStatementODSKeyword skipwhite skipnl skipempty
syn match sasODSGraphicsProcStatement '\v%(^|;)\s*\zsformat>' display contained contains=sasODSGraphicsProcStatementKeyword nextgroup=sasFormatContext skipwhite skipnl skipempty
syn region sasODSGraphicsProc matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc\s+%(sgdesign|sgpanel|sgplot|sgrender|sgscatter)>' end='\v%(^|;)\s*%(run|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasDataStepFunction,sasODSGraphicsProcStatement

" Proc TEMPLATE, 9.4
syn keyword sasProcTemplateClause as into
syn keyword sasProcTemplateStatementKeyword block break cellstyle class close column compute continue define delete delstream do done dynamic edit else end eval flush footer header import iterate link list mvar ndent next nmvar notes open path put putl putlog putq putstream putvars replace set source stop style test text text2 text3 translate trigger unblock unset xdent contained
syn keyword sasProcTemplateStatementComplexKeyword cellvalue column crosstabs event footer header statgraph style table tagset contained
syn keyword sasProcTemplateGTLStatementKeyword axislegend axistable bandplot barchart barchartparm begingraph beginpolygon beginpolyline bihistogram3dparm blockplot boxplot boxplotparm bubbleplot continuouslegend contourplotparm dendrogram discretelegend drawarrow drawimage drawline drawoval drawrectangle drawtext dropline ellipse ellipseparm endgraph endinnermargin endlayout endpolygon endpolyline endsidebar entry entryfootnote entrytitle fringeplot heatmap heatmapparm highlowplot histogram histogramparm innermargin layout legenditem legendtextitems linechart lineparm loessplot mergedlegend modelband needleplot pbsplineplot polygonplot referenceline regressionplot scatterplot seriesplot sidebar stepplot surfaceplotparm symbolchar symbolimage textplot vectorplot waterfallchart contained
syn keyword sasProcTemplateGTLComplexKeyword datalattice datapanel globallegend gridded lattice overlay overlayequated overlay3d region contained
syn match sasProcTemplateStatement '\v%(^|;)\s*\zs\h\w*>' display contained contains=sasProcTemplateStatementKeyword,sasProcTemplateGTLStatementKeyword,sasGlobalStatementKeyword
syn match sasProcTemplateStatement '\v%(^|;)\s*\zsdefine>' display contained contains=sasProcTemplateStatementKeyword nextgroup=sasProcTemplateStatementComplexKeyword skipwhite skipnl skipempty
syn match sasProcTemplateStatement '\v%(^|;)\s*\zslayout>' display contained contains=sasProcTemplateGTLStatementKeyword nextgroup=sasProcTemplateGTLComplexKeyword skipwhite skipnl skipempty
syn match sasProcTemplateStatement '\v%(^|;)\s*\zsods>' display contained contains=sasGlobalStatementKeyword nextgroup=sasGlobalStatementODSKeyword skipwhite skipnl skipempty
syn region sasProcTemplate matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc\s+template>' end='\v%(^|;)\s*%(run|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasProcTemplateClause,sasProcTemplateStatement

" Proc SQL, 9.4
syn keyword sasProcSQLFunctionName avg count css cv freq max mean median min n nmiss prt range std stderr sum sumwgt t uss var contained
syn region sasProcSQLFunctionContext start='(' end=')' contained contains=@sasBasicSyntax,sasProcSQLFunction
syn match sasProcSQLFunction '\v<\w+\ze\(' contained contains=sasProcSQLFunctionName,sasDataStepFunctionName nextgroup=sasProcSQLFunctionContext
syn keyword sasProcSQLClause add asc between by calculated cascade case check connection constraint cross desc distinct drop else end escape except exists foreign from full group having in inner intersect into is join key left libname like modify natural newline notrim null on order outer primary references restrict right separated set then to trimmed union unique user using values when where contained
syn keyword sasProcSQLClause as contained nextgroup=sasProcSQLStatementKeyword skipwhite skipnl skipempty
syn keyword sasProcSQLStatementKeyword connect delete disconnect execute insert reset select update validate contained
syn keyword sasProcSQLStatementComplexKeyword alter create describe drop contained nextgroup=sasProcSQLStatementNextKeyword skipwhite skipnl skipempty
syn keyword sasProcSQLStatementNextKeyword index table view contained
syn match sasProcSQLStatement '\v%(^|;)\s*\zs\h\w*>' display contained contains=sasProcSQLStatementKeyword,sasGlobalStatementKeyword
syn match sasProcSQLStatement '\v%(^|;)\s*\zs%(alter|create|describe|drop)>' display contained contains=sasProcSQLStatementComplexKeyword nextgroup=sasProcSQLStatementNextKeyword skipwhite skipnl skipempty
syn match sasProcSQLStatement '\v%(^|;)\s*\zsvalidate>' display contained contains=sasProcSQLStatementKeyword nextgroup=sasProcSQLStatementKeyword,sasProcSQLStatementComplexKeyword skipwhite skipnl skipempty
syn match sasProcSQLStatement '\v%(^|;)\s*\zsods>' display contained contains=sasGlobalStatementKeyword nextgroup=sasGlobalStatementODSKeyword skipwhite skipnl skipempty 
syn region sasProcSQL matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc\s+sql>' end='\v%(^|;)\s*%(quit|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasProcSQLFunction,sasProcSQLClause,sasProcSQLStatement

" SAS/DS2, 9.4
syn keyword sasDS2FunctionName abs anyalnum anyalpha anycntrl anydigit anyfirst anygraph anylower anyname anyprint anypunct anyspace anyupper anyxdigit arcos arcosh arsin arsinh artanh atan atan2 band beta betainv blackclprc blackptprc blkshclprc blkshptprc blshift bnot bor brshift bxor byte cat cats catt catx ceil ceilz choosec choosen cmp cmpt coalesce coalescec comb compare compbl compfuzz compound compress constant convx convxp cos cosh count countc countw css cumipmt cumprinc cv datdif date datejul datepart datetime day dequote deviance dhms dif digamma dim divide dur durp effrate erf erfc exp fact find findc findw floor floorz fmtinfo fuzz gaminv gamma garkhclprc garkhptprc gcd geodist geomean geomeanz harmean harmeanz hbound hms holiday hour index indexc indexw inputc inputn int intcindex intck intcycle intdt intfit intget intindex intnest intnx intrr intseas intshift inttest intts intz ipmt iqr irr juldate juldate7 kcount kstrcat kstrip kupdate kupdates kurtosis lag largest lbound lcm left length lengthc lengthm lengthn lgamma log logbeta log10 log1px log2 lowcase mad margrclprc margrptprc max md5 mdy mean median min minute missing mod modz month mort n ndims netpv nmiss nomrate notalnum notalpha notcntrl notdigit notfirst notgraph notlower notname notprint notpunct notspace notupper notxdigit npv null nwkdom ordinal pctl perm pmt poisson power ppmt probbeta probbnml probbnrm probchi probdf probf probgam probhypr probit probmc probmed probnegb probnorm probt prxchange prxmatch prxparse prxposn put pvp qtr quote ranbin rancau rand ranexp rangam range rank rannor ranpoi rantbl rantri ranuni repeat reverse right rms round rounde roundz savings scan sec second sha256hex sha256hmachex sign sin sinh skewness sleep smallest sqlexec sqrt std stderr streaminit strip substr substrn sum sumabs tan tanh time timepart timevalue tinv to_date to_double to_time to_timestamp today translate transtrn tranwrd trigamma trim trimn trunc uniform upcase uss uuidgen var verify vformat vinarray vinformat vlabel vlength vname vtype week weekday whichc whichn year yieldp yrdif yyq contained
syn region sasDS2FunctionContext start='(' end=')' contained contains=@sasBasicSyntax,sasDS2Function
syn match sasDS2Function '\v<\w+\ze\(' contained contains=sasDS2FunctionName nextgroup=sasDS2FunctionContext
syn keyword sasDS2Control continue data dcl declare do drop else end enddata endpackage endthread from go goto if leave method otherwise package point return select then thread to until when while contained
syn keyword sasDS2StatementKeyword array by forward keep merge output put rename retain set stop vararray varlist contained
syn keyword sasDS2StatementComplexKeyword package thread contained
syn match sasDS2Statement '\v%(^|;)\s*\zs\h\w*>' display contained contains=sasDS2StatementKeyword,sasGlobalStatementKeyword
syn match sasDS2Statement '\v%(^|;)\s*\zs%(dcl|declare|drop)>' display contained contains=sasDS2StatementKeyword nextgroup=sasDS2StatementComplexKeyword skipwhite skipnl skipempty
syn match sasDS2Statement '\v%(^|;)\s*\zsods>' display contained contains=sasGlobalStatementKeyword nextgroup=sasGlobalStatementODSKeyword skipwhite skipnl skipempty
syn region sasDS2 matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc\s+ds2>' end='\v%(^|;)\s*%(quit|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasDS2Function,sasDS2Control,sasDS2Statement

" SAS/IML, 14.1
syn keyword sasIMLFunctionName abs all allcomb allperm any apply armasim bin blankstr block branks bspline btran byte char choose col colvec concat contents convexit corr corr2cov countmiss countn countunique cov cov2corr covlag cshape cusum cuprod cv cvexhull datasets design designf det diag dif dimension distance do duration echelon eigval eigvec element exp expmatrix expandgrid fft forward froot full gasetup geomean ginv hadamard half hankel harmean hdir hermite homogen i ifft insert int inv invupdt isempty isskipped j jroot kurtosis lag length loc log logabsdet mad magic mahalanobis max mean median min mod moduleic modulein name ncol ndx2sub nleng norm normal nrow num opscal orpol parentname palette polyroot prod product pv quartile rancomb randdirichlet randfun randmultinomial randmvt randnormal randwishart ranperk ranperm range rank ranktie rates ratio remove repeat root row rowcat rowcatc rowvec rsubstr sample setdif shape shapecol skewness solve sparse splinev spot sqrsym sqrt sqrvech ssq standard std storage sub2ndx substr sum sweep symsqr t toeplitz trace trisolv type uniform union unique uniqueby value var vecdiag vech xmult xsect yield contained
syn keyword sasIMLCallRoutineName appcort armacov armalik bar box change comport delete eigen execute exportdatasettor exportmatrixtor farmacov farmafit farmalik farmasim fdif gaend gagetmem gagetval gainit gareeval garegen gasetcro gasetmut gasetobj gasetsel gblkvp gblkvpd gclose gdelete gdraw gdrawl geneig ggrid ginclude gopen gpie gpiexy gpoint gpoly gport gportpop gportstk gscale gscript gset gshow gsorth gstart gstop gstrlen gtext gvtext gwindow gxaxis gyaxis heatmapcont heatmapdisc histogram importdatasetfromr importmatrixfromr ipf itsolver kalcvf kalcvs kaldff kaldfs lav lcp lms lp lpsolve lts lupdt marg maxqform mcd milpsolve modulei mve nlpcg nlpdd nlpfdd nlpfea nlphqn nlplm nlpnms nlpnra nlpnrr nlpqn nlpqua nlptr ode odsgraph ortvec pgraf push qntl qr quad queue randgen randseed rdodt rupdt rename rupdt rzlind scatter seq seqscale seqshift seqscale seqshift series solvelin sort sortndx sound spline splinec svd tabulate tpspline tpsplnev tsbaysea tsdecomp tsmlocar tsmlomar tsmulmar tspears tspred tsroot tstvcar tsunimar valset varmacov varmalik varmasim vnormal vtsroot wavft wavget wavift wavprint wavthrsh contained
syn region sasIMLFunctionContext start='(' end=')' contained contains=@sasBasicSyntax,sasIMLFunction
syn match sasIMLFunction '\v<\w+\ze\(' contained contains=sasIMLFunctionName,sasDataStepFunction nextgroup=sasIMLFunctionContext
syn keyword sasIMLControl abort by do else end finish goto if link pause quit resume return run start stop then to until while contained
syn keyword sasIMLStatementKeyword append call close closefile create delete display edit file find force free index infile input list load mattrib print purge read remove replace reset save setin setout show sort store summary use window contained
syn match sasIMLStatement '\v%(^|;)\s*\zs\h\w*>' display contained contains=sasIMLStatementKeyword,sasGlobalStatementKeyword
syn match sasIMLStatement '\v%(^|;)\s*\zsods>' display contained contains=sasGlobalStatementKeyword nextgroup=sasGlobalStatementODSKeyword skipwhite skipnl skipempty
syn region sasIML matchgroup=sasSectionKeyword start='\v%(^|;)\s*\zsproc\s+iml>' end='\v%(^|;)\s*%(quit|data|proc|endsas)>'me=s-1 fold contains=@sasBasicSyntax,sasIMLFunction,sasIMLControl,sasIMLStatement

" Macro definition
syn region sasMacro start='\v\%macro>' end='\v\%mend>' fold keepend contains=@sasBasicSyntax,@sasDataStepSyntax,sasDataStep,sasProc,sasODSGraphicsProc,sasGraphProc,sasAnalyticalProc,sasProcTemplate,sasProcSQL,sasDS2,sasIML

" Define default highlighting
hi def link sasComment Comment
hi def link sasTodo Delimiter
hi def link sasSectLbl Title
hi def link sasSectLblEnds Comment
hi def link sasNumber Number
hi def link sasDateTime Constant
hi def link sasString String
hi def link sasDataStepControl Keyword
hi def link sasProcTemplateClause Keyword
hi def link sasProcSQLClause Keyword
hi def link sasDS2Control Keyword
hi def link sasIMLControl Keyword
hi def link sasOperator Operator
hi def link sasGlobalStatementKeyword Statement
hi def link sasGlobalStatementODSKeyword Statement
hi def link sasSectionKeyword Statement
hi def link sasDataStepFunctionName Function
hi def link sasDataStepCallRoutineName Function
hi def link sasDataStepStatementKeyword Statement
hi def link sasDataStepStatementHashKeyword Statement
hi def link sasDataStepHashOperator Operator
hi def link sasDataStepHashMethodName Function
hi def link sasDataStepHashAttributeName Identifier
hi def link sasProcStatementKeyword Statement
hi def link sasODSGraphicsProcStatementKeyword Statement
hi def link sasGraphProcStatementKeyword Statement
hi def link sasAnalyticalProcStatementKeyword Statement
hi def link sasProcTemplateStatementKeyword Statement
hi def link sasProcTemplateStatementComplexKeyword Statement
hi def link sasProcTemplateGTLStatementKeyword Statement
hi def link sasProcTemplateGTLComplexKeyword Statement
hi def link sasProcSQLFunctionName Function
hi def link sasProcSQLStatementKeyword Statement
hi def link sasProcSQLStatementComplexKeyword Statement
hi def link sasProcSQLStatementNextKeyword Statement
hi def link sasDS2FunctionName Function
hi def link sasDS2StatementKeyword Statement
hi def link sasIMLFunctionName Function
hi def link sasIMLCallRoutineName Function
hi def link sasIMLStatementKeyword Statement
hi def link sasMacroReserved PreProc
hi def link sasMacroVariable Define
hi def link sasMacroFunctionName Define
hi def link sasDataLine SpecialChar
hi def link sasFormat SpecialChar
hi def link sasReserved Special

" Syncronize from beginning to keep large blocks from losing
" syntax coloring while moving through code.
syn sync fromstart

let b:current_syntax = "sas"

let &cpo = s:cpo_save
unlet s:cpo_save
