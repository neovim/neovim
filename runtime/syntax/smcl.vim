" smcl.vim -- Vim syntax file for smcl files.
" Language:	SMCL -- Stata Markup and Control Language
" Maintainer:	Jeff Pitblado <jpitblado@stata.com>
" Last Change:	26apr2006
" Version:	1.1.2

" Log:
" 20mar2003	updated the match definition for cmdab
" 14apr2006	'syntax clear' only under version control
"		check for 'b:current_syntax', removed 'did_smcl_syntax_inits'
" 26apr2006	changed 'stata_smcl' to 'smcl'

" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

syntax case match

syn keyword smclCCLword current_date		contained
syn keyword smclCCLword current_time		contained
syn keyword smclCCLword rmsg_time		contained
syn keyword smclCCLword stata_version		contained
syn keyword smclCCLword version			contained
syn keyword smclCCLword born_date		contained
syn keyword smclCCLword flavor			contained
syn keyword smclCCLword SE			contained
syn keyword smclCCLword mode			contained
syn keyword smclCCLword console			contained
syn keyword smclCCLword os			contained
syn keyword smclCCLword osdtl			contained
syn keyword smclCCLword machine_type		contained
syn keyword smclCCLword byteorder		contained
syn keyword smclCCLword sysdir_stata		contained
syn keyword smclCCLword sysdir_updates		contained
syn keyword smclCCLword sysdir_base		contained
syn keyword smclCCLword sysdir_site		contained
syn keyword smclCCLword sysdir_plus		contained
syn keyword smclCCLword sysdir_personal		contained
syn keyword smclCCLword sysdir_oldplace		contained
syn keyword smclCCLword adopath			contained
syn keyword smclCCLword pwd			contained
syn keyword smclCCLword dirsep			contained
syn keyword smclCCLword max_N_theory		contained
syn keyword smclCCLword max_N_current		contained
syn keyword smclCCLword max_k_theory		contained
syn keyword smclCCLword max_k_current		contained
syn keyword smclCCLword max_width_theory	contained
syn keyword smclCCLword max_width_current	contained
syn keyword smclCCLword max_matsize		contained
syn keyword smclCCLword min_matsize		contained
syn keyword smclCCLword max_macrolen		contained
syn keyword smclCCLword macrolen		contained
syn keyword smclCCLword max_cmdlen		contained
syn keyword smclCCLword cmdlen			contained
syn keyword smclCCLword namelen			contained
syn keyword smclCCLword mindouble		contained
syn keyword smclCCLword maxdouble		contained
syn keyword smclCCLword epsdouble		contained
syn keyword smclCCLword minfloat		contained
syn keyword smclCCLword maxfloat		contained
syn keyword smclCCLword epsfloat		contained
syn keyword smclCCLword minlong			contained
syn keyword smclCCLword maxlong			contained
syn keyword smclCCLword minint			contained
syn keyword smclCCLword maxint			contained
syn keyword smclCCLword minbyte			contained
syn keyword smclCCLword maxbyte			contained
syn keyword smclCCLword maxstrvarlen		contained
syn keyword smclCCLword memory			contained
syn keyword smclCCLword maxvar			contained
syn keyword smclCCLword matsize			contained
syn keyword smclCCLword N			contained
syn keyword smclCCLword k			contained
syn keyword smclCCLword width			contained
syn keyword smclCCLword changed			contained
syn keyword smclCCLword filename		contained
syn keyword smclCCLword filedate		contained
syn keyword smclCCLword more			contained
syn keyword smclCCLword rmsg			contained
syn keyword smclCCLword dp			contained
syn keyword smclCCLword linesize		contained
syn keyword smclCCLword pagesize		contained
syn keyword smclCCLword logtype			contained
syn keyword smclCCLword linegap			contained
syn keyword smclCCLword scrollbufsize		contained
syn keyword smclCCLword varlabelpos		contained
syn keyword smclCCLword reventries		contained
syn keyword smclCCLword graphics		contained
syn keyword smclCCLword scheme			contained
syn keyword smclCCLword printcolor		contained
syn keyword smclCCLword adosize			contained
syn keyword smclCCLword maxdb			contained
syn keyword smclCCLword virtual			contained
syn keyword smclCCLword checksum		contained
syn keyword smclCCLword timeout1		contained
syn keyword smclCCLword timeout2		contained
syn keyword smclCCLword httpproxy		contained
syn keyword smclCCLword h_current		contained
syn keyword smclCCLword max_matsize		contained
syn keyword smclCCLword min_matsize		contained
syn keyword smclCCLword max_macrolen		contained
syn keyword smclCCLword macrolen		contained
syn keyword smclCCLword max_cmdlen		contained
syn keyword smclCCLword cmdlen			contained
syn keyword smclCCLword namelen			contained
syn keyword smclCCLword mindouble		contained
syn keyword smclCCLword maxdouble		contained
syn keyword smclCCLword epsdouble		contained
syn keyword smclCCLword minfloat		contained
syn keyword smclCCLword maxfloat		contained
syn keyword smclCCLword epsfloat		contained
syn keyword smclCCLword minlong			contained
syn keyword smclCCLword maxlong			contained
syn keyword smclCCLword minint			contained
syn keyword smclCCLword maxint			contained
syn keyword smclCCLword minbyte			contained
syn keyword smclCCLword maxbyte			contained
syn keyword smclCCLword maxstrvarlen		contained
syn keyword smclCCLword memory			contained
syn keyword smclCCLword maxvar			contained
syn keyword smclCCLword matsize			contained
syn keyword smclCCLword N			contained
syn keyword smclCCLword k			contained
syn keyword smclCCLword width			contained
syn keyword smclCCLword changed			contained
syn keyword smclCCLword filename		contained
syn keyword smclCCLword filedate		contained
syn keyword smclCCLword more			contained
syn keyword smclCCLword rmsg			contained
syn keyword smclCCLword dp			contained
syn keyword smclCCLword linesize		contained
syn keyword smclCCLword pagesize		contained
syn keyword smclCCLword logtype			contained
syn keyword smclCCLword linegap			contained
syn keyword smclCCLword scrollbufsize		contained
syn keyword smclCCLword varlabelpos		contained
syn keyword smclCCLword reventries		contained
syn keyword smclCCLword graphics		contained
syn keyword smclCCLword scheme			contained
syn keyword smclCCLword printcolor		contained
syn keyword smclCCLword adosize			contained
syn keyword smclCCLword maxdb			contained
syn keyword smclCCLword virtual			contained
syn keyword smclCCLword checksum		contained
syn keyword smclCCLword timeout1		contained
syn keyword smclCCLword timeout2		contained
syn keyword smclCCLword httpproxy		contained
syn keyword smclCCLword httpproxyhost		contained
syn keyword smclCCLword httpproxyport		contained
syn keyword smclCCLword httpproxyauth		contained
syn keyword smclCCLword httpproxyuser		contained
syn keyword smclCCLword httpproxypw		contained
syn keyword smclCCLword trace			contained
syn keyword smclCCLword tracedepth		contained
syn keyword smclCCLword tracesep		contained
syn keyword smclCCLword traceindent		contained
syn keyword smclCCLword traceexapnd		contained
syn keyword smclCCLword tracenumber		contained
syn keyword smclCCLword type			contained
syn keyword smclCCLword level			contained
syn keyword smclCCLword seed			contained
syn keyword smclCCLword searchdefault		contained
syn keyword smclCCLword pi			contained
syn keyword smclCCLword rc			contained

" Directive for the contant and current-value class
syn region smclCCL start=/{ccl / end=/}/ oneline contains=smclCCLword

" The order of the following syntax definitions is roughly that of the on-line
" documentation for smcl in Stata, from within Stata see help smcl.

" Format directives for line and paragraph modes
syn match smclFormat /{smcl}/
syn match smclFormat /{sf\(\|:[^}]\+\)}/
syn match smclFormat /{it\(\|:[^}]\+\)}/
syn match smclFormat /{bf\(\|:[^}]\+\)}/
syn match smclFormat /{inp\(\|:[^}]\+\)}/
syn match smclFormat /{input\(\|:[^}]\+\)}/
syn match smclFormat /{err\(\|:[^}]\+\)}/
syn match smclFormat /{error\(\|:[^}]\+\)}/
syn match smclFormat /{res\(\|:[^}]\+\)}/
syn match smclFormat /{result\(\|:[^}]\+\)}/
syn match smclFormat /{txt\(\|:[^}]\+\)}/
syn match smclFormat /{text\(\|:[^}]\+\)}/
syn match smclFormat /{com\(\|:[^}]\+\)}/
syn match smclFormat /{cmd\(\|:[^}]\+\)}/
syn match smclFormat /{cmdab:[^:}]\+:[^:}()]*\(\|:\|:(\|:()\)}/
syn match smclFormat /{hi\(\|:[^}]\+\)}/
syn match smclFormat /{hilite\(\|:[^}]\+\)}/
syn match smclFormat /{ul \(on\|off\)}/
syn match smclFormat /{ul:[^}]\+}/
syn match smclFormat /{hline\(\| \d\+\| -\d\+\|:[^}]\+\)}/
syn match smclFormat /{dup \d\+:[^}]\+}/
syn match smclFormat /{c [^}]\+}/
syn match smclFormat /{char [^}]\+}/
syn match smclFormat /{reset}/

" Formatting directives for line mode
syn match smclFormat /{title:[^}]\+}/
syn match smclFormat /{center:[^}]\+}/
syn match smclFormat /{centre:[^}]\+}/
syn match smclFormat /{center \d\+:[^}]\+}/
syn match smclFormat /{centre \d\+:[^}]\+}/
syn match smclFormat /{right:[^}]\+}/
syn match smclFormat /{lalign \d\+:[^}]\+}/
syn match smclFormat /{ralign \d\+:[^}]\+}/
syn match smclFormat /{\.\.\.}/
syn match smclFormat /{col \d\+}/
syn match smclFormat /{space \d\+}/
syn match smclFormat /{tab}/

" Formatting directives for paragraph mode
syn match smclFormat /{bind:[^}]\+}/
syn match smclFormat /{break}/

syn match smclFormat /{p}/
syn match smclFormat /{p \d\+}/
syn match smclFormat /{p \d\+ \d\+}/
syn match smclFormat /{p \d\+ \d\+ \d\+}/
syn match smclFormat /{pstd}/
syn match smclFormat /{psee}/
syn match smclFormat /{phang\(\|2\|3\)}/
syn match smclFormat /{pmore\(\|2\|3\)}/
syn match smclFormat /{pin\(\|2\|3\)}/
syn match smclFormat /{p_end}/

syn match smclFormat /{opt \w\+\(\|:\w\+\)\(\|([^)}]*)\)}/

syn match smclFormat /{opth \w*\(\|:\w\+\)(\w*)}/
syn match smclFormat /{opth "\w\+\((\w\+:[^)}]\+)\)"}/
syn match smclFormat /{opth \w\+:\w\+(\w\+:[^)}]\+)}/

syn match smclFormat /{dlgtab\s*\(\|\d\+\|\d\+\s\+\d\+\):[^}]\+}/

syn match smclFormat /{p2colset\s\+\d\+\s\+\d\+\s\+\d\+\s\+\d\+}/
syn match smclFormat /{p2col\s\+:[^{}]*}.*{p_end}/
syn match smclFormat /{p2col\s\+:{[^{}]*}}.*{p_end}/
syn match smclFormat /{p2coldent\s*:[^{}]*}.*{p_end}/
syn match smclFormat /{p2coldent\s*:{[^{}]*}}.*{p_end}/
syn match smclFormat /{p2line\s*\(\|\d\+\s\+\d\+\)}/
syn match smclFormat /{p2colreset}/

syn match smclFormat /{synoptset\s\+\d\+\s\+\w\+}/
syn match smclFormat /{synopt\s*:[^{}]*}.*{p_end}/
syn match smclFormat /{synopt\s*:{[^{}]*}}.*{p_end}/
syn match smclFormat /{syntab\s*:[^{}]*}/
syn match smclFormat /{synopthdr}/
syn match smclFormat /{synoptline}/

" Link directive for line and paragraph modes
syn match smclLink /{help [^}]\+}/
syn match smclLink /{helpb [^}]\+}/
syn match smclLink /{help_d:[^}]\+}/
syn match smclLink /{search [^}]\+}/
syn match smclLink /{search_d:[^}]\+}/
syn match smclLink /{browse [^}]\+}/
syn match smclLink /{view [^}]\+}/
syn match smclLink /{view_d:[^}]\+}/
syn match smclLink /{news:[^}]\+}/
syn match smclLink /{net [^}]\+}/
syn match smclLink /{net_d:[^}]\+}/
syn match smclLink /{netfrom_d:[^}]\+}/
syn match smclLink /{ado [^}]\+}/
syn match smclLink /{ado_d:[^}]\+}/
syn match smclLink /{update [^}]\+}/
syn match smclLink /{update_d:[^}]\+}/
syn match smclLink /{dialog [^}]\+}/
syn match smclLink /{back:[^}]\+}/
syn match smclLink /{clearmore:[^}]\+}/
syn match smclLink /{stata [^}]\+}/

syn match smclLink /{newvar\(\|:[^}]\+\)}/
syn match smclLink /{var\(\|:[^}]\+\)}/
syn match smclLink /{varname\(\|:[^}]\+\)}/
syn match smclLink /{vars\(\|:[^}]\+\)}/
syn match smclLink /{varlist\(\|:[^}]\+\)}/
syn match smclLink /{depvar\(\|:[^}]\+\)}/
syn match smclLink /{depvars\(\|:[^}]\+\)}/
syn match smclLink /{depvarlist\(\|:[^}]\+\)}/
syn match smclLink /{indepvars\(\|:[^}]\+\)}/

syn match smclLink /{dtype}/
syn match smclLink /{ifin}/
syn match smclLink /{weight}/

" Comment
syn region smclComment start=/{\*/ end=/}/ oneline

" Strings
syn region smclString  matchgroup=Nothing start=/"/ end=/"/   oneline
syn region smclEString matchgroup=Nothing start=/`"/ end=/"'/ oneline contains=smclEString

" assign highlight groups

hi def link smclEString		smclString

hi def link smclCCLword		Statement
hi def link smclCCL		Type
hi def link smclFormat		Statement
hi def link smclLink		Underlined
hi def link smclComment		Comment
hi def link smclString		String

let b:current_syntax = "smcl"

" vim: ts=8
