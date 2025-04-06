" Vim syntax file
" Filename:     foxpro.vim
" Version:      1.0
" Language:     FoxPro for DOS/UNIX v2.6
" Maintainer:   Bill W. Smith, Jr. <donal@brewich.com>
" Last Change:  15 May 2006

"     This file replaces the FoxPro for DOS v2.x syntax file 
" maintained by Powing Tse <powing@mcmug.org>
" 
" Change Log:	added support for FoxPro Codebook highlighting
" 		corrected highlighting of comments that do NOT start in col 1
" 		corrected highlighting of comments at end of line (&&)
" 
" 
" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

" FoxPro Codebook Naming Conventions
syn match foxproCBConst "\<[c][A-Z][A-Za-z0-9_]*\>"
syn match foxproCBVar "\<[lgrt][acndlmf][A-Z][A-Za-z0-9_]*\>"
syn match foxproCBField "\<[a-z0-9]*\.[A-Za-z0-9_]*\>"
" PROPER CodeBook field names start with the data type and do NOT have _
syn match foxproCBField "\<[A-Za-z0-9]*\.[acndlm][A-Z][A-Za-z0-9]*\>"
syn match foxproCBWin "\<w[rbcm][A-Z][A-Za-z0-9_]*\>"
" CodeBook 2.0 defined objects as follows
" This uses the hotkey from the screen builder as the second character
syn match foxproCBObject "\<[lgr][bfthnkoli][A-Z][A-Za-z0-9_]*\>"
" A later version added the following conventions for objects
syn match foxproCBObject "\<box[A-Z][A-Za-z0-9_]*\>"
syn match foxproCBObject "\<fld[A-Z][A-Za-z0-9_]*\>"
syn match foxproCBObject "\<txt[A-Z][A-Za-z0-9_]*\>"
syn match foxproCBObject "\<phb[A-Z][A-Za-z0-9_]*\>"
syn match foxproCBObject "\<rdo[A-Z][A-Za-z0-9_]*\>"
syn match foxproCBObject "\<chk[A-Z][A-Za-z0-9_]*\>"
syn match foxproCBObject "\<pop[A-Z][A-Za-z0-9_]*\>"
syn match foxproCBObject "\<lst[A-Z][A-Za-z0-9_]*\>"
syn match foxproCBObject "\<inv[A-Z][A-Za-z0-9_]*\>"
syn match foxproCBObject "\<mnu[A-Z][A-Za-z0-9_]*\>"

syntax case ignore

" Highlight special characters
syn match foxproSpecial "^\s*!"
syn match foxproSpecial "&"
syn match foxproSpecial ";\s*$"
syn match foxproSpecial "^\s*="
syn match foxproSpecial "^\s*\\"
syn match foxproSpecial "^\s*\\\\"
syn match foxproSpecial "^\s*?"
syn match foxproSpecial "^\s*??"
syn match foxproSpecial "^\s*???"
syn match foxproSpecial "\<m\>\."

" @ Statements
syn match foxproAtSymbol contained "^\s*@"
syn match foxproAtCmd    contained "\<say\>\|\<get\>\|\<edit\>\|\<box\>\|\<clea\%[r]\>\|\<fill\>\|\<menu\>\|\<prom\%[pt]\>\|\<scro\%[ll]\>\|\<to\>"
syn match foxproAtStart  transparent "^\s*@.*" contains=ALL

" preprocessor directives
syn match foxproPreProc "^\s*#\s*\(\<if\>\|\<elif\>\|\<else\>\|\<endi\%[f]\>\)"
syn match foxproPreProc "^\s*#\s*\(\<defi\%[ne]\>\|\<unde\%[f]\>\)"
syn match foxproPreProc "^\s*#\s*\<regi\%[on]\>"

" Functions
syn match foxproFunc "\<abs\>\s*("me=e-1
syn match foxproFunc "\<acop\%[y]\>\s*("me=e-1
syn match foxproFunc "\<acos\>\s*("me=e-1
syn match foxproFunc "\<adel\>\s*("me=e-1
syn match foxproFunc "\<adir\>\s*("me=e-1
syn match foxproFunc "\<aele\%[ment]\>\s*("me=e-1
syn match foxproFunc "\<afie\%[lds]\>\s*("me=e-1
syn match foxproFunc "\<afon\%[t]\>\s*("me=e-1
syn match foxproFunc "\<ains\>\s*("me=e-1
syn match foxproFunc "\<alen\>\s*("me=e-1
syn match foxproFunc "\<alia\%[s]\>\s*("me=e-1
syn match foxproFunc "\<allt\%[rim]\>\s*("me=e-1
syn match foxproFunc "\<ansi\%[tooem]\>\s*("me=e-1
syn match foxproFunc "\<asc\>\s*("me=e-1
syn match foxproFunc "\<asca\%[n]\>\s*("me=e-1
syn match foxproFunc "\<asin\>\s*("me=e-1
syn match foxproFunc "\<asor\%[t]\>\s*("me=e-1
syn match foxproFunc "\<asub\%[script]\>\s*("me=e-1
syn match foxproFunc "\<at\>\s*("me=e-1
syn match foxproFunc "\<atan\>\s*("me=e-1
syn match foxproFunc "\<atc\>\s*("me=e-1
syn match foxproFunc "\<atcl\%[ine]\>\s*("me=e-1
syn match foxproFunc "\<atli\%[ne]\>\s*("me=e-1
syn match foxproFunc "\<atn2\>\s*("me=e-1
syn match foxproFunc "\<bar\>\s*("me=e-1
syn match foxproFunc "\<barc\%[ount]\>\s*("me=e-1
syn match foxproFunc "\<barp\%[rompt]\>\s*("me=e-1
syn match foxproFunc "\<betw\%[een]\>\s*("me=e-1
syn match foxproFunc "\<bof\>\s*("me=e-1
syn match foxproFunc "\<caps\%[lock]\>\s*("me=e-1
syn match foxproFunc "\<cdow\>\s*("me=e-1
syn match foxproFunc "\<cdx\>\s*("me=e-1
syn match foxproFunc "\<ceil\%[ing]\>\s*("me=e-1
syn match foxproFunc "\<chr\>\s*("me=e-1
syn match foxproFunc "\<chrs\%[aw]\>\s*("me=e-1
syn match foxproFunc "\<chrt\%[ran]\>\s*("me=e-1
syn match foxproFunc "\<cmon\%[th]\>\s*("me=e-1
syn match foxproFunc "\<cntb\%[ar]\>\s*("me=e-1
syn match foxproFunc "\<cntp\%[ad]\>\s*("me=e-1
syn match foxproFunc "\<col\>\s*("me=e-1
syn match foxproFunc "\<cos\>\s*("me=e-1
syn match foxproFunc "\<cpco\%[nvert]\>\s*("me=e-1
syn match foxproFunc "\<cpcu\%[rrent]\>\s*("me=e-1
syn match foxproFunc "\<cpdb\%[f]\>\s*("me=e-1
syn match foxproFunc "\<ctod\>\s*("me=e-1
syn match foxproFunc "\<curd\%[ir]\>\s*("me=e-1
syn match foxproFunc "\<date\>\s*("me=e-1
syn match foxproFunc "\<day\>\s*("me=e-1
syn match foxproFunc "\<dbf\>\s*("me=e-1
syn match foxproFunc "\<ddea\%[borttrans]\>\s*("me=e-1
syn match foxproFunc "\<ddea\%[dvise]\>\s*("me=e-1
syn match foxproFunc "\<ddee\%[nabled]\>\s*("me=e-1
syn match foxproFunc "\<ddee\%[xecute]\>\s*("me=e-1
syn match foxproFunc "\<ddei\%[nitiate]\>\s*("me=e-1
syn match foxproFunc "\<ddel\%[asterror]\>\s*("me=e-1
syn match foxproFunc "\<ddep\%[oke]\>\s*("me=e-1
syn match foxproFunc "\<dder\%[equest]\>\s*("me=e-1
syn match foxproFunc "\<ddes\%[etoption]\>\s*("me=e-1
syn match foxproFunc "\<ddes\%[etservice]\>\s*("me=e-1
syn match foxproFunc "\<ddes\%[ettopic]\>\s*("me=e-1
syn match foxproFunc "\<ddet\%[erminate]\>\s*("me=e-1
syn match foxproFunc "\<dele\%[ted]\>\s*("me=e-1
syn match foxproFunc "\<desc\%[ending]\>\s*("me=e-1
syn match foxproFunc "\<diff\%[erence]\>\s*("me=e-1
syn match foxproFunc "\<disk\%[space]\>\s*("me=e-1
syn match foxproFunc "\<dmy\>\s*("me=e-1
syn match foxproFunc "\<dow\>\s*("me=e-1
syn match foxproFunc "\<dtoc\>\s*("me=e-1
syn match foxproFunc "\<dtor\>\s*("me=e-1
syn match foxproFunc "\<dtos\>\s*("me=e-1
syn match foxproFunc "\<empt\%[y]\>\s*("me=e-1
syn match foxproFunc "\<eof\>\s*("me=e-1
syn match foxproFunc "\<erro\%[r]\>\s*("me=e-1
syn match foxproFunc "\<eval\%[uate]\>\s*("me=e-1
syn match foxproFunc "\<exp\>\s*("me=e-1
syn match foxproFunc "\<fchs\%[ize]\>\s*("me=e-1
syn match foxproFunc "\<fclo\%[se]\>\s*("me=e-1
syn match foxproFunc "\<fcou\%[nt]\>\s*("me=e-1
syn match foxproFunc "\<fcre\%[ate]\>\s*("me=e-1
syn match foxproFunc "\<fdat\%[e]\>\s*("me=e-1
syn match foxproFunc "\<feof\>\s*("me=e-1
syn match foxproFunc "\<ferr\%[or]\>\s*("me=e-1
syn match foxproFunc "\<fflu\%[sh]\>\s*("me=e-1
syn match foxproFunc "\<fget\%[s]\>\s*("me=e-1
syn match foxproFunc "\<fiel\%[d]\>\s*("me=e-1
syn match foxproFunc "\<file\>\s*("me=e-1
syn match foxproFunc "\<filt\%[er]\>\s*("me=e-1
syn match foxproFunc "\<fkla\%[bel]\>\s*("me=e-1
syn match foxproFunc "\<fkma\%[x]\>\s*("me=e-1
syn match foxproFunc "\<fldl\%[ist]\>\s*("me=e-1
syn match foxproFunc "\<floc\%[k]\>\s*("me=e-1
syn match foxproFunc "\<floo\%[r]\>\s*("me=e-1
syn match foxproFunc "\<font\%[metric]\>\s*("me=e-1
syn match foxproFunc "\<fope\%[n]\>\s*("me=e-1
syn match foxproFunc "\<for\>\s*("me=e-1
syn match foxproFunc "\<foun\%[d]\>\s*("me=e-1
syn match foxproFunc "\<fput\%[s]\>\s*("me=e-1
syn match foxproFunc "\<frea\%[d]\>\s*("me=e-1
syn match foxproFunc "\<fsee\%[k]\>\s*("me=e-1
syn match foxproFunc "\<fsiz\%[e]\>\s*("me=e-1
syn match foxproFunc "\<ftim\%[e]\>\s*("me=e-1
syn match foxproFunc "\<full\%[path]\>\s*("me=e-1
syn match foxproFunc "\<fv\>\s*("me=e-1
syn match foxproFunc "\<fwri\%[te]\>\s*("me=e-1
syn match foxproFunc "\<getb\%[ar]\>\s*("me=e-1
syn match foxproFunc "\<getd\%[ir]\>\s*("me=e-1
syn match foxproFunc "\<gete\%[nv]\>\s*("me=e-1
syn match foxproFunc "\<getf\%[ile]\>\s*("me=e-1
syn match foxproFunc "\<getf\%[ont]\>\s*("me=e-1
syn match foxproFunc "\<getp\%[ad]\>\s*("me=e-1
syn match foxproFunc "\<gomo\%[nth]\>\s*("me=e-1
syn match foxproFunc "\<head\%[er]\>\s*("me=e-1
syn match foxproFunc "\<home\>\s*("me=e-1
syn match foxproFunc "\<idxc\%[ollate]\>\s*("me=e-1
syn match foxproFunc "\<iif\>\s*("me=e-1
syn match foxproFunc "\<inke\%[y]\>\s*("me=e-1
syn match foxproFunc "\<inli\%[st]\>\s*("me=e-1
syn match foxproFunc "\<insm\%[ode]\>\s*("me=e-1
syn match foxproFunc "\<int\>\s*("me=e-1
syn match foxproFunc "\<isal\%[pha]\>\s*("me=e-1
syn match foxproFunc "\<isbl\%[ank]\>\s*("me=e-1
syn match foxproFunc "\<isco\%[lor]\>\s*("me=e-1
syn match foxproFunc "\<isdi\%[git]\>\s*("me=e-1
syn match foxproFunc "\<islo\%[wer]\>\s*("me=e-1
syn match foxproFunc "\<isre\%[adonly]\>\s*("me=e-1
syn match foxproFunc "\<isup\%[per]\>\s*("me=e-1
syn match foxproFunc "\<key\>\s*("me=e-1
syn match foxproFunc "\<keym\%[atch]\>\s*("me=e-1
syn match foxproFunc "\<last\%[key]\>\s*("me=e-1
syn match foxproFunc "\<left\>\s*("me=e-1
syn match foxproFunc "\<len\>\s*("me=e-1
syn match foxproFunc "\<like\>\s*("me=e-1
syn match foxproFunc "\<line\%[no]\>\s*("me=e-1
syn match foxproFunc "\<locf\%[ile]\>\s*("me=e-1
syn match foxproFunc "\<lock\>\s*("me=e-1
syn match foxproFunc "\<log\>\s*("me=e-1
syn match foxproFunc "\<log1\%[0]\>\s*("me=e-1
syn match foxproFunc "\<look\%[up]\>\s*("me=e-1
syn match foxproFunc "\<lowe\%[r]\>\s*("me=e-1
syn match foxproFunc "\<ltri\%[m]\>\s*("me=e-1
syn match foxproFunc "\<lupd\%[ate]\>\s*("me=e-1
syn match foxproFunc "\<max\>\s*("me=e-1
syn match foxproFunc "\<mcol\>\s*("me=e-1
syn match foxproFunc "\<mdow\%[n]\>\s*("me=e-1
syn match foxproFunc "\<mdx\>\s*("me=e-1
syn match foxproFunc "\<mdy\>\s*("me=e-1
syn match foxproFunc "\<meml\%[ines]\>\s*("me=e-1
syn match foxproFunc "\<memo\%[ry]\>\s*("me=e-1
syn match foxproFunc "\<menu\>\s*("me=e-1
syn match foxproFunc "\<mess\%[age]\>\s*("me=e-1
syn match foxproFunc "\<min\>\s*("me=e-1
syn match foxproFunc "\<mlin\%[e]\>\s*("me=e-1
syn match foxproFunc "\<mod\>\s*("me=e-1
syn match foxproFunc "\<mont\%[h]\>\s*("me=e-1
syn match foxproFunc "\<mrkb\%[ar]\>\s*("me=e-1
syn match foxproFunc "\<mrkp\%[ad]\>\s*("me=e-1
syn match foxproFunc "\<mrow\>\s*("me=e-1
syn match foxproFunc "\<mwin\%[dow]\>\s*("me=e-1
syn match foxproFunc "\<ndx\>\s*("me=e-1
syn match foxproFunc "\<norm\%[alize]\>\s*("me=e-1
syn match foxproFunc "\<numl\%[ock]\>\s*("me=e-1
syn match foxproFunc "\<objn\%[um]\>\s*("me=e-1
syn match foxproFunc "\<objv\%[ar]\>\s*("me=e-1
syn match foxproFunc "\<occu\%[rs]\>\s*("me=e-1
syn match foxproFunc "\<oemt\%[oansi]\>\s*("me=e-1
syn match foxproFunc "\<on\>\s*("me=e-1
syn match foxproFunc "\<orde\%[r]\>\s*("me=e-1
syn match foxproFunc "\<os\>\s*("me=e-1
syn match foxproFunc "\<pad\>\s*("me=e-1
syn match foxproFunc "\<padc\>\s*("me=e-1
syn match foxproFunc "\<padl\>\s*("me=e-1
syn match foxproFunc "\<padr\>\s*("me=e-1
syn match foxproFunc "\<para\%[meters]\>\s*("me=e-1
syn match foxproFunc "\<paym\%[ent]\>\s*("me=e-1
syn match foxproFunc "\<pcol\>\s*("me=e-1
syn match foxproFunc "\<pi\>\s*("me=e-1
syn match foxproFunc "\<popu\%[p]\>\s*("me=e-1
syn match foxproFunc "\<prin\%[tstatus]\>\s*("me=e-1
syn match foxproFunc "\<prmb\%[ar]\>\s*("me=e-1
syn match foxproFunc "\<prmp\%[ad]\>\s*("me=e-1
syn match foxproFunc "\<prog\%[ram]\>\s*("me=e-1
syn match foxproFunc "\<prom\%[pt]\>\s*("me=e-1
syn match foxproFunc "\<prop\%[er]\>\s*("me=e-1
syn match foxproFunc "\<prow\>\s*("me=e-1
syn match foxproFunc "\<prti\%[nfo]\>\s*("me=e-1
syn match foxproFunc "\<putf\%[ile]\>\s*("me=e-1
syn match foxproFunc "\<pv\>\s*("me=e-1
syn match foxproFunc "\<rand\>\s*("me=e-1
syn match foxproFunc "\<rat\>\s*("me=e-1
syn match foxproFunc "\<ratl\%[ine]\>\s*("me=e-1
syn match foxproFunc "\<rdle\%[vel]\>\s*("me=e-1
syn match foxproFunc "\<read\%[key]\>\s*("me=e-1
syn match foxproFunc "\<recc\%[ount]\>\s*("me=e-1
syn match foxproFunc "\<recn\%[o]\>\s*("me=e-1
syn match foxproFunc "\<recs\%[ize]\>\s*("me=e-1
syn match foxproFunc "\<rela\%[tion]\>\s*("me=e-1
syn match foxproFunc "\<repl\%[icate]\>\s*("me=e-1
syn match foxproFunc "\<rgbs\%[cheme]\>\s*("me=e-1
syn match foxproFunc "\<righ\%[t]\>\s*("me=e-1
syn match foxproFunc "\<rloc\%[k]\>\s*("me=e-1
syn match foxproFunc "\<roun\%[d]\>\s*("me=e-1
syn match foxproFunc "\<row\>\s*("me=e-1
syn match foxproFunc "\<rtod\>\s*("me=e-1
syn match foxproFunc "\<rtri\%[m]\>\s*("me=e-1
syn match foxproFunc "\<sche\%[me]\>\s*("me=e-1
syn match foxproFunc "\<scol\%[s]\>\s*("me=e-1
syn match foxproFunc "\<seco\%[nds]\>\s*("me=e-1
syn match foxproFunc "\<seek\>\s*("me=e-1
syn match foxproFunc "\<sele\%[ct]\>\s*("me=e-1
syn match foxproFunc "\<set\>\s*("me=e-1
syn match foxproFunc "\<sign\>\s*("me=e-1
syn match foxproFunc "\<sin\>\s*("me=e-1
syn match foxproFunc "\<skpb\%[ar]\>\s*("me=e-1
syn match foxproFunc "\<skpp\%[ad]\>\s*("me=e-1
syn match foxproFunc "\<soun\%[dex]\>\s*("me=e-1
syn match foxproFunc "\<spac\%[e]\>\s*("me=e-1
syn match foxproFunc "\<sqrt\>\s*("me=e-1
syn match foxproFunc "\<srow\%[s]\>\s*("me=e-1
syn match foxproFunc "\<str\>\s*("me=e-1
syn match foxproFunc "\<strt\%[ran]\>\s*("me=e-1
syn match foxproFunc "\<stuf\%[f]\>\s*("me=e-1
syn match foxproFunc "\<subs\%[tr]\>\s*("me=e-1
syn match foxproFunc "\<sysm\%[etric]\>\s*("me=e-1
syn match foxproFunc "\<sys\>\s*("me=e-1
syn match foxproFunc "\<tag\>\s*("me=e-1
syn match foxproFunc "\<tagc\%[ount]\>\s*("me=e-1
syn match foxproFunc "\<tagn\%[o]\>\s*("me=e-1
syn match foxproFunc "\<tan\>\s*("me=e-1
syn match foxproFunc "\<targ\%[et]\>\s*("me=e-1
syn match foxproFunc "\<time\>\s*("me=e-1
syn match foxproFunc "\<tran\%[sform]\>\s*("me=e-1
syn match foxproFunc "\<trim\>\s*("me=e-1
syn match foxproFunc "\<txtw\%[idth]\>\s*("me=e-1
syn match foxproFunc "\<type\>\s*("me=e-1
syn match foxproFunc "\<uniq\%[ue]\>\s*("me=e-1
syn match foxproFunc "\<upda\%[ted]\>\s*("me=e-1
syn match foxproFunc "\<uppe\%[r]\>\s*("me=e-1
syn match foxproFunc "\<used\>\s*("me=e-1
syn match foxproFunc "\<val\>\s*("me=e-1
syn match foxproFunc "\<varr\%[ead]\>\s*("me=e-1
syn match foxproFunc "\<vers\%[ion]\>\s*("me=e-1
syn match foxproFunc "\<wbor\%[der]\>\s*("me=e-1
syn match foxproFunc "\<wchi\%[ld]\>\s*("me=e-1
syn match foxproFunc "\<wcol\%[s]\>\s*("me=e-1
syn match foxproFunc "\<wexi\%[st]\>\s*("me=e-1
syn match foxproFunc "\<wfon\%[t]\>\s*("me=e-1
syn match foxproFunc "\<wlas\%[t]\>\s*("me=e-1
syn match foxproFunc "\<wlco\%[l]\>\s*("me=e-1
syn match foxproFunc "\<wlro\%[w]\>\s*("me=e-1
syn match foxproFunc "\<wmax\%[imum]\>\s*("me=e-1
syn match foxproFunc "\<wmin\%[imum]\>\s*("me=e-1
syn match foxproFunc "\<wont\%[op]\>\s*("me=e-1
syn match foxproFunc "\<wout\%[put]\>\s*("me=e-1
syn match foxproFunc "\<wpar\%[ent]\>\s*("me=e-1
syn match foxproFunc "\<wrea\%[d]\>\s*("me=e-1
syn match foxproFunc "\<wrow\%[s]\>\s*("me=e-1
syn match foxproFunc "\<wtit\%[le]\>\s*("me=e-1
syn match foxproFunc "\<wvis\%[ible]\>\s*("me=e-1
syn match foxproFunc "\<year\>\s*("me=e-1

" Commands
syn match foxproCmd "^\s*\<acce\%[pt]\>"
syn match foxproCmd "^\s*\<acti\%[vate]\>\s*\<menu\>"
syn match foxproCmd "^\s*\<acti\%[vate]\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<acti\%[vate]\>\s*\<scre\%[en]\>"
syn match foxproCmd "^\s*\<acti\%[vate]\>\s*\<wind\%[ow]\>"
syn match foxproCmd "^\s*\<appe\%[nd]\>"
syn match foxproCmd "^\s*\<appe\%[nd]\>\s*\<from\>"
syn match foxproCmd "^\s*\<appe\%[nd]\>\s*\<from\>\s*\<arra\%[y]\>"
syn match foxproCmd "^\s*\<appe\%[nd]\>\s*\<gene\%[ral]\>"
syn match foxproCmd "^\s*\<appe\%[nd]\>\s*\<memo\>"
syn match foxproCmd "^\s*\<assi\%[st]\>"
syn match foxproCmd "^\s*\<aver\%[age]\>"
syn match foxproCmd "^\s*\<blan\%[k]\>"
syn match foxproCmd "^\s*\<brow\%[se]\>"
syn match foxproCmd "^\s*\<buil\%[d]\>\s*\<app\>"
syn match foxproCmd "^\s*\<buil\%[d]\>\s*\<exe\>"
syn match foxproCmd "^\s*\<buil\%[d]\>\s*\<proj\%[ect]\>"
syn match foxproCmd "^\s*\<calc\%[ulate]\>"
syn match foxproCmd "^\s*\<call\>"
syn match foxproCmd "^\s*\<canc\%[el]\>"
syn match foxproCmd "^\s*\<chan\%[ge]\>"
syn match foxproCmd "^\s*\<clea\%[r]\>"
syn match foxproCmd "^\s*\<clos\%[e]\>"
syn match foxproCmd "^\s*\<clos\%[e]\>\s*\<memo\>"
syn match foxproCmd "^\s*\<comp\%[ile]\>"
syn match foxproCmd "^\s*\<cont\%[inue]\>"
syn match foxproCmd "^\s*\<copy\>\s*\<file\>"
syn match foxproCmd "^\s*\<copy\>\s*\<inde\%[xes]\>"
syn match foxproCmd "^\s*\<copy\>\s*\<memo\>"
syn match foxproCmd "^\s*\<copy\>\s*\<stru\%[cture]\>"
syn match foxproCmd "^\s*\<copy\>\s*\<stru\%[cture]\>\s*\<exte\%[nded]\>"
syn match foxproCmd "^\s*\<copy\>\s*\<tag\>"
syn match foxproCmd "^\s*\<copy\>\s*\<to\>"
syn match foxproCmd "^\s*\<copy\>\s*\<to\>\s*\<arra\%[y]\>"
syn match foxproCmd "^\s*\<coun\%[t]\>"
syn match foxproCmd "^\s*\<crea\%[te]\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<colo\%[r]\>\s*\<set\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<curs\%[or]\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<from\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<labe\%[l]\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<menu\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<proj\%[ect]\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<quer\%[y]\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<repo\%[rt]\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<scre\%[en]\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<tabl\%[e]\>"
syn match foxproCmd "^\s*\<crea\%[te]\>\s*\<view\>"
syn match foxproCmd "^\s*\<dde\>"
syn match foxproCmd "^\s*\<deac\%[tivate]\>\s*\<menu\>"
syn match foxproCmd "^\s*\<deac\%[tivate]\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<deac\%[tivate]\>\s*\<wind\%[ow]\>"
syn match foxproCmd "^\s*\<decl\%[are]\>"
syn match foxproCmd "^\s*\<defi\%[ne]\>\s*\<bar\>"
syn match foxproCmd "^\s*\<defi\%[ne]\>\s*\<box\>"
syn match foxproCmd "^\s*\<defi\%[ne]\>\s*\<menu\>"
syn match foxproCmd "^\s*\<defi\%[ne]\>\s*\<pad\>"
syn match foxproCmd "^\s*\<defi\%[ne]\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<defi\%[ne]\>\s*\<wind\%[ow]\>"
syn match foxproCmd "^\s*\<dele\%[te]\>"
syn match foxproCmd "^\s*\<dele\%[te]\>\s*\<file\>"
syn match foxproCmd "^\s*\<dele\%[te]\>\s*\<tag\>"
syn match foxproCmd "^\s*\<dime\%[nsion]\>"
syn match foxproCmd "^\s*\<dire\%[ctory]\>"
syn match foxproCmd "^\s*\<disp\%[lay]\>"
syn match foxproCmd "^\s*\<disp\%[lay]\>\s*\<file\%[s]\>"
syn match foxproCmd "^\s*\<disp\%[lay]\>\s*\<memo\%[ry]\>"
syn match foxproCmd "^\s*\<disp\%[lay]\>\s*\<stat\%[us]\>"
syn match foxproCmd "^\s*\<disp\%[lay]\>\s*\<stru\%[cture]\>"
syn match foxproCmd "^\s*\<do\>"
syn match foxproCmd "^\s*\<edit\>"
syn match foxproCmd "^\s*\<ejec\%[t]\>"
syn match foxproCmd "^\s*\<ejec\%[t]\>\s*\<page\>"
syn match foxproCmd "^\s*\<eras\%[e]\>"
syn match foxproCmd "^\s*\<exit\>"
syn match foxproCmd "^\s*\<expo\%[rt]\>"
syn match foxproCmd "^\s*\<exte\%[rnal]\>"
syn match foxproCmd "^\s*\<file\%[r]\>"
syn match foxproCmd "^\s*\<find\>"
syn match foxproCmd "^\s*\<flus\%[h]\>"
syn match foxproCmd "^\s*\<func\%[tion]\>"
syn match foxproCmd "^\s*\<gath\%[er]\>"
syn match foxproCmd "^\s*\<gete\%[xpr]\>"
syn match foxproCmd "^\s*\<go\>"
syn match foxproCmd "^\s*\<goto\>"
syn match foxproCmd "^\s*\<help\>"
syn match foxproCmd "^\s*\<hide\>\s*\<menu\>"
syn match foxproCmd "^\s*\<hide\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<hide\>\s*\<wind\%[ow]\>"
syn match foxproCmd "^\s*\<impo\%[rt]\>"
syn match foxproCmd "^\s*\<inde\%[x]\>"
syn match foxproCmd "^\s*\<inpu\%[t]\>"
syn match foxproCmd "^\s*\<inse\%[rt]\>"
syn match foxproCmd "^\s*\<join\>"
syn match foxproCmd "^\s*\<keyb\%[oard]\>"
syn match foxproCmd "^\s*\<labe\%[l]\>"
syn match foxproCmd "^\s*\<list\>"
syn match foxproCmd "^\s*\<load\>"
syn match foxproCmd "^\s*\<loca\%[te]\>"
syn match foxproCmd "^\s*\<loop\>"
syn match foxproCmd "^\s*\<menu\>"
syn match foxproCmd "^\s*\<menu\>\s*\<to\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<comm\%[and]\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<file\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<gene\%[ral]\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<labe\%[l]\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<memo\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<menu\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<proj\%[ect]\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<quer\%[y]\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<repo\%[rt]\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<scre\%[en]\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<stru\%[cture]\>"
syn match foxproCmd "^\s*\<modi\%[fy]\>\s*\<wind\%[ow]\>"
syn match foxproCmd "^\s*\<move\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<move\>\s*\<wind\%[ow]\>"
syn match foxproCmd "^\s*\<note\>"
syn match foxproCmd "^\s*\<on\>\s*\<apla\%[bout]\>"
syn match foxproCmd "^\s*\<on\>\s*\<bar\>"
syn match foxproCmd "^\s*\<on\>\s*\<erro\%[r]\>"
syn match foxproCmd "^\s*\<on\>\s*\<esca\%[pe]\>"
syn match foxproCmd "^\s*\<on\>\s*\<exit\>\s*\<bar\>"
syn match foxproCmd "^\s*\<on\>\s*\<exit\>\s*\<menu\>"
syn match foxproCmd "^\s*\<on\>\s*\<exit\>\s*\<pad\>"
syn match foxproCmd "^\s*\<on\>\s*\<exit\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<on\>\s*\<key\>"
syn match foxproCmd "^\s*\<on\>\s*\<key\>\s*\<=\>"
syn match foxproCmd "^\s*\<on\>\s*\<key\>\s*\<labe\%[l]\>"
syn match foxproCmd "^\s*\<on\>\s*\<mach\%[elp]\>"
syn match foxproCmd "^\s*\<on\>\s*\<pad\>"
syn match foxproCmd "^\s*\<on\>\s*\<page\>"
syn match foxproCmd "^\s*\<on\>\s*\<read\%[error]\>"
syn match foxproCmd "^\s*\<on\>\s*\<sele\%[ction]\>\s*\<bar\>"
syn match foxproCmd "^\s*\<on\>\s*\<sele\%[ction]\>\s*\<menu\>"
syn match foxproCmd "^\s*\<on\>\s*\<sele\%[ction]\>\s*\<pad\>"
syn match foxproCmd "^\s*\<on\>\s*\<sele\%[ction]\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<on\>\s*\<shut\%[down]\>"
syn match foxproCmd "^\s*\<pack\>"
syn match foxproCmd "^\s*\<para\%[meters]\>"
syn match foxproCmd "^\s*\<play\>\s*\<macr\%[o]\>"
syn match foxproCmd "^\s*\<pop\>\s*\<key\>"
syn match foxproCmd "^\s*\<pop\>\s*\<menu\>"
syn match foxproCmd "^\s*\<pop\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<priv\%[ate]\>"
syn match foxproCmd "^\s*\<proc\%[edure]\>"
syn match foxproCmd "^\s*\<publ\%[ic]\>"
syn match foxproCmd "^\s*\<push\>\s*\<key\>"
syn match foxproCmd "^\s*\<push\>\s*\<menu\>"
syn match foxproCmd "^\s*\<push\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<quit\>"
syn match foxproCmd "^\s*\<read\>"
syn match foxproCmd "^\s*\<read\>\s*\<menu\>"
syn match foxproCmd "^\s*\<reca\%[ll]\>"
syn match foxproCmd "^\s*\<rein\%[dex]\>"
syn match foxproCmd "^\s*\<rele\%[ase]\>"
syn match foxproCmd "^\s*\<rele\%[ase]\>\s*\<modu\%[le]\>"
syn match foxproCmd "^\s*\<rena\%[me]\>"
syn match foxproCmd "^\s*\<repl\%[ace]\>"
syn match foxproCmd "^\s*\<repl\%[ace]\>\s*\<from\>\s*\<arra\%[y]\>"
syn match foxproCmd "^\s*\<repo\%[rt]\>"
syn match foxproCmd "^\s*\<rest\%[ore]\>\s*\<from\>"
syn match foxproCmd "^\s*\<rest\%[ore]\>\s*\<macr\%[os]\>"
syn match foxproCmd "^\s*\<rest\%[ore]\>\s*\<scre\%[en]\>"
syn match foxproCmd "^\s*\<rest\%[ore]\>\s*\<wind\%[ow]\>"
syn match foxproCmd "^\s*\<resu\%[me]\>"
syn match foxproCmd "^\s*\<retr\%[y]\>"
syn match foxproCmd "^\s*\<retu\%[rn]\>"
syn match foxproCmd "^\s*\<run\>"
syn match foxproCmd "^\s*\<run\>\s*\/n"
syn match foxproCmd "^\s*\<runs\%[cript]\>"
syn match foxproCmd "^\s*\<save\>\s*\<macr\%[os]\>"
syn match foxproCmd "^\s*\<save\>\s*\<scre\%[en]\>"
syn match foxproCmd "^\s*\<save\>\s*\<to\>"
syn match foxproCmd "^\s*\<save\>\s*\<wind\%[ows]\>"
syn match foxproCmd "^\s*\<scat\%[ter]\>"
syn match foxproCmd "^\s*\<scro\%[ll]\>"
syn match foxproCmd "^\s*\<seek\>"
syn match foxproCmd "^\s*\<sele\%[ct]\>"
syn match foxproCmd "^\s*\<set\>"
syn match foxproCmd "^\s*\<set\>\s*\<alte\%[rnate]\>"
syn match foxproCmd "^\s*\<set\>\s*\<ansi\>"
syn match foxproCmd "^\s*\<set\>\s*\<apla\%[bout]\>"
syn match foxproCmd "^\s*\<set\>\s*\<auto\%[save]\>"
syn match foxproCmd "^\s*\<set\>\s*\<bell\>"
syn match foxproCmd "^\s*\<set\>\s*\<blin\%[k]\>"
syn match foxproCmd "^\s*\<set\>\s*\<bloc\%[ksize]\>"
syn match foxproCmd "^\s*\<set\>\s*\<bord\%[er]\>"
syn match foxproCmd "^\s*\<set\>\s*\<brst\%[atus]\>"
syn match foxproCmd "^\s*\<set\>\s*\<carr\%[y]\>"
syn match foxproCmd "^\s*\<set\>\s*\<cent\%[ury]\>"
syn match foxproCmd "^\s*\<set\>\s*\<clea\%[r]\>"
syn match foxproCmd "^\s*\<set\>\s*\<cloc\%[k]\>"
syn match foxproCmd "^\s*\<set\>\s*\<coll\%[ate]\>"
syn match foxproCmd "^\s*\<set\>\s*\<colo\%[r]\>\s*\<of\>"
syn match foxproCmd "^\s*\<set\>\s*\<colo\%[r]\>\s*\<of\>\s*\<sche\%[me]\>"
syn match foxproCmd "^\s*\<set\>\s*\<colo\%[r]\>\s*\<set\>"
syn match foxproCmd "^\s*\<set\>\s*\<colo\%[r]\>\s*\<to\>"
syn match foxproCmd "^\s*\<set\>\s*\<comp\%[atible]\>"
syn match foxproCmd "^\s*\<set\>\s*\<conf\%[irm]\>"
syn match foxproCmd "^\s*\<set\>\s*\<cons\%[ole]\>"
syn match foxproCmd "^\s*\<set\>\s*\<curr\%[ency]\>"
syn match foxproCmd "^\s*\<set\>\s*\<curs\%[or]\>"
syn match foxproCmd "^\s*\<set\>\s*\<date\>"
syn match foxproCmd "^\s*\<set\>\s*\<debu\%[g]\>"
syn match foxproCmd "^\s*\<set\>\s*\<deci\%[mals]\>"
syn match foxproCmd "^\s*\<set\>\s*\<defa\%[ult]\>"
syn match foxproCmd "^\s*\<set\>\s*\<dele\%[ted]\>"
syn match foxproCmd "^\s*\<set\>\s*\<deli\%[miters]\>"
syn match foxproCmd "^\s*\<set\>\s*\<deve\%[lopment]\>"
syn match foxproCmd "^\s*\<set\>\s*\<devi\%[ce]\>"
syn match foxproCmd "^\s*\<set\>\s*\<disp\%[lay]\>"
syn match foxproCmd "^\s*\<set\>\s*\<dohi\%[story]\>"
syn match foxproCmd "^\s*\<set\>\s*\<echo\>"
syn match foxproCmd "^\s*\<set\>\s*\<esca\%[pe]\>"
syn match foxproCmd "^\s*\<set\>\s*\<exac\%[t]\>"
syn match foxproCmd "^\s*\<set\>\s*\<excl\%[usive]\>"
syn match foxproCmd "^\s*\<set\>\s*\<fiel\%[ds]\>"
syn match foxproCmd "^\s*\<set\>\s*\<filt\%[er]\>"
syn match foxproCmd "^\s*\<set\>\s*\<fixe\%[d]\>"
syn match foxproCmd "^\s*\<set\>\s*\<form\%[at]\>"
syn match foxproCmd "^\s*\<set\>\s*\<full\%[path]\>"
syn match foxproCmd "^\s*\<set\>\s*\<func\%[tion]\>"
syn match foxproCmd "^\s*\<set\>\s*\<head\%[ings]\>"
syn match foxproCmd "^\s*\<set\>\s*\<help\>"
syn match foxproCmd "^\s*\<set\>\s*\<help\%[filter]\>"
syn match foxproCmd "^\s*\<set\>\s*\<hour\%[s]\>"
syn match foxproCmd "^\s*\<set\>\s*\<inde\%[x]\>"
syn match foxproCmd "^\s*\<set\>\s*\<inte\%[nsity]\>"
syn match foxproCmd "^\s*\<set\>\s*\<key\>"
syn match foxproCmd "^\s*\<set\>\s*\<keyc\%[omp]\>"
syn match foxproCmd "^\s*\<set\>\s*\<libr\%[ary]\>"
syn match foxproCmd "^\s*\<set\>\s*\<lock\>"
syn match foxproCmd "^\s*\<set\>\s*\<loge\%[rrors]\>"
syn match foxproCmd "^\s*\<set\>\s*\<macd\%[esktop]\>"
syn match foxproCmd "^\s*\<set\>\s*\<mach\%[elp]\>"
syn match foxproCmd "^\s*\<set\>\s*\<mack\%[ey]\>"
syn match foxproCmd "^\s*\<set\>\s*\<marg\%[in]\>"
syn match foxproCmd "^\s*\<set\>\s*\<mark\>\s*\<of\>"
syn match foxproCmd "^\s*\<set\>\s*\<mark\>\s*\<to\>"
syn match foxproCmd "^\s*\<set\>\s*\<memo\%[width]\>"
syn match foxproCmd "^\s*\<set\>\s*\<mess\%[age]\>"
syn match foxproCmd "^\s*\<set\>\s*\<mous\%[e]\>"
syn match foxproCmd "^\s*\<set\>\s*\<mult\%[ilocks]\>"
syn match foxproCmd "^\s*\<set\>\s*\<near\>"
syn match foxproCmd "^\s*\<set\>\s*\<nocp\%[trans]\>"
syn match foxproCmd "^\s*\<set\>\s*\<noti\%[fy]\>"
syn match foxproCmd "^\s*\<set\>\s*\<odom\%[eter]\>"
syn match foxproCmd "^\s*\<set\>\s*\<opti\%[mize]\>"
syn match foxproCmd "^\s*\<set\>\s*\<orde\%[r]\>"
syn match foxproCmd "^\s*\<set\>\s*\<pale\%[tte]\>"
syn match foxproCmd "^\s*\<set\>\s*\<path\>"
syn match foxproCmd "^\s*\<set\>\s*\<pdse\%[tup]\>"
syn match foxproCmd "^\s*\<set\>\s*\<poin\%[t]\>"
syn match foxproCmd "^\s*\<set\>\s*\<prin\%[ter]\>"
syn match foxproCmd "^\s*\<set\>\s*\<proc\%[edure]\>"
syn match foxproCmd "^\s*\<set\>\s*\<read\%[border]\>"
syn match foxproCmd "^\s*\<set\>\s*\<refr\%[esh]\>"
syn match foxproCmd "^\s*\<set\>\s*\<rela\%[tion]\>"
syn match foxproCmd "^\s*\<set\>\s*\<rela\%[tion]\>\s*\<off\>"
syn match foxproCmd "^\s*\<set\>\s*\<repr\%[ocess]\>"
syn match foxproCmd "^\s*\<set\>\s*\<reso\%[urce]\>"
syn match foxproCmd "^\s*\<set\>\s*\<safe\%[ty]\>"
syn match foxproCmd "^\s*\<set\>\s*\<scor\%[eboard]\>"
syn match foxproCmd "^\s*\<set\>\s*\<sepa\%[rator]\>"
syn match foxproCmd "^\s*\<set\>\s*\<shad\%[ows]\>"
syn match foxproCmd "^\s*\<set\>\s*\<skip\>"
syn match foxproCmd "^\s*\<set\>\s*\<skip\>\s*\<of\>"
syn match foxproCmd "^\s*\<set\>\s*\<spac\%[e]\>"
syn match foxproCmd "^\s*\<set\>\s*\<stat\%[us]\>"
syn match foxproCmd "^\s*\<set\>\s*\<stat\%[us]\>\s*\<bar\>"
syn match foxproCmd "^\s*\<set\>\s*\<step\>"
syn match foxproCmd "^\s*\<set\>\s*\<stic\%[ky]\>"
syn match foxproCmd "^\s*\<set\>\s*\<sysm\%[enu]\>"
syn match foxproCmd "^\s*\<set\>\s*\<talk\>"
syn match foxproCmd "^\s*\<set\>\s*\<text\%[merge]\>"
syn match foxproCmd "^\s*\<set\>\s*\<text\%[merge]\>\s*\<deli\%[miters]\>"
syn match foxproCmd "^\s*\<set\>\s*\<topi\%[c]\>"
syn match foxproCmd "^\s*\<set\>\s*\<trbe\%[tween]\>"
syn match foxproCmd "^\s*\<set\>\s*\<type\%[ahead]\>"
syn match foxproCmd "^\s*\<set\>\s*\<udfp\%[arms]\>"
syn match foxproCmd "^\s*\<set\>\s*\<uniq\%[ue]\>"
syn match foxproCmd "^\s*\<set\>\s*\<view\>"
syn match foxproCmd "^\s*\<set\>\s*\<volu\%[me]\>"
syn match foxproCmd "^\s*\<set\>\s*\<wind\%[ow]\>\s*\<of\>\s*\<memo\>"
syn match foxproCmd "^\s*\<set\>\s*\<xcmd\%[file]\>"
syn match foxproCmd "^\s*\<show\>\s*\<get\>"
syn match foxproCmd "^\s*\<show\>\s*\<gets\>"
syn match foxproCmd "^\s*\<show\>\s*\<menu\>"
syn match foxproCmd "^\s*\<show\>\s*\<obje\%[ct]\>"
syn match foxproCmd "^\s*\<show\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<show\>\s*\<wind\%[ow]\>"
syn match foxproCmd "^\s*\<size\>\s*\<popu\%[p]\>"
syn match foxproCmd "^\s*\<skip\>"
syn match foxproCmd "^\s*\<sort\>"
syn match foxproCmd "^\s*\<stor\%[e]\>"
syn match foxproCmd "^\s*\<sum\>"
syn match foxproCmd "^\s*\<susp\%[end]\>"
syn match foxproCmd "^\s*\<tota\%[l]\>"
syn match foxproCmd "^\s*\<type\>"
syn match foxproCmd "^\s*\<unlo\%[ck]\>"
syn match foxproCmd "^\s*\<upda\%[te]\>"
syn match foxproCmd "^\s*\<use\>"
syn match foxproCmd "^\s*\<wait\>"
syn match foxproCmd "^\s*\<zap\>"
syn match foxproCmd "^\s*\<zoom\>\s*\<wind\%[ow]\>"

" Enclosed Block
syn match foxproEnBlk "^\s*\<do\>\s*\<case\>"
syn match foxproEnBlk "^\s*\<case\>"
syn match foxproEnBlk "^\s*\<othe\%[rwise]\>"
syn match foxproEnBlk "^\s*\<endc\%[ase]\>"
syn match foxproEnBlk "^\s*\<do\>\s*\<whil\%[e]\>"
syn match foxproEnBlk "^\s*\<endd\%[o]\>"
syn match foxproEnBlk "^\s*\<for\>"
syn match foxproEnBlk "^\s*\<endf\%[or]\>"
syn match foxproEnBlk "^\s*\<next\>"
syn match foxproEnBlk "^\s*\<if\>"
syn match foxproEnBlk "^\s*\<else\>"
syn match foxproEnBlk "^\s*\<endi\%[f]\>"
syn match foxproEnBlk "^\s*\<prin\%[tjob]\>"
syn match foxproEnBlk "^\s*\<endp\%[rintjob]\>"
syn match foxproEnBlk "^\s*\<scan\>"
syn match foxproEnBlk "^\s*\<ends\%[can]\>"
syn match foxproEnBlk "^\s*\<text\>"
syn match foxproEnBlk "^\s*\<endt\%[ext]\>"

" System Variables
syn keyword foxproSysVar _alignment _assist _beautify _box _calcmem _calcvalue
syn keyword foxproSysVar _cliptext _curobj _dblclick _diarydate _dos _foxdoc
syn keyword foxproSysVar _foxgraph _gengraph _genmenu _genpd _genscrn _genxtab
syn keyword foxproSysVar _indent _lmargin _mac _mline _padvance _pageno _pbpage
syn keyword foxproSysVar _pcolno _pcopies _pdriver _pdsetup _pecode _peject _pepage
syn keyword foxproSysVar _plength _plineno _ploffset _ppitch _pquality _pretext
syn keyword foxproSysVar _pscode _pspacing _pwait _rmargin _shell _spellchk
syn keyword foxproSysVar _startup _tabs _tally _text _throttle _transport _unix
syn keyword foxproSysVar _windows _wrap

" Strings
syn region foxproString start=+"+ end=+"+ oneline
syn region foxproString start=+'+ end=+'+ oneline
syn region foxproString start=+\[+ end=+\]+ oneline

" Constants
syn match foxproConst "\.t\."
syn match foxproConst "\.f\."

"integer number, or floating point number without a dot and with "f".
syn match foxproNumber "\<[0-9]\+\>"
"floating point number, with dot, optional exponent
syn match foxproFloat  "\<[0-9]\+\.[0-9]*\(e[-+]\=[0-9]\+\)\=\>"
"floating point number, starting with a dot, optional exponent
syn match foxproFloat  "\.[0-9]\+\(e[-+]\=[0-9]\+\)\=\>"
"floating point number, without dot, with exponent
syn match foxproFloat  "\<[0-9]\+e[-+]\=[0-9]\+\>"

syn match foxproComment "^\s*\*.*"
syn match foxproComment "&&.*"

"catch errors caused by wrong parenthesis
syn region foxproParen transparent start='(' end=')' contains=ALLBUT,foxproParenErr
syn match foxproParenErr ")"

syn sync minlines=1 maxlines=3

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link foxproSpecial  Special
hi def link foxproAtSymbol Special
hi def link foxproAtCmd    Statement
hi def link foxproPreProc  PreProc
hi def link foxproFunc     Identifier
hi def link foxproCmd      Statement
hi def link foxproEnBlk    Type
hi def link foxproSysVar   String
hi def link foxproString   String
hi def link foxproConst    Constant
hi def link foxproNumber   Number
hi def link foxproFloat    Float
hi def link foxproComment  Comment
hi def link foxproParenErr Error
hi def link foxproCBConst  PreProc
hi def link foxproCBField  Special
hi def link foxproCBVar    Identifier
hi def link foxproCBWin    Special
hi def link foxproCBObject Identifier


let b:current_syntax = "foxpro"
