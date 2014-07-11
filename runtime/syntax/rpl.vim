" Vim syntax file
" Language:	RPL/2
" Version:	0.15.15 against RPL/2 version 4.00pre7i
" Last Change:	2012 Feb 03 by Thilo Six
" Maintainer:	Joël BERTRAND <rpl2@free.fr>
" URL:		http://www.makalis.fr/~bertrand/rpl2/download/vim/indent/rpl.vim
" Credits:	Nothing

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Keyword characters (not used)
" set iskeyword=33-127

" Case sensitive
syntax case match

" Constants
syntax match rplConstant	   "\(^\|\s\+\)\(e\|i\)\ze\($\|\s\+\)"

" Any binary number
syntax match rplBinaryError	   "\(^\|\s\+\)#\s*\S\+b\ze"
syntax match rplBinary		   "\(^\|\s\+\)#\s*[01]\+b\ze\($\|\s\+\)"
syntax match rplOctalError	   "\(^\|\s\+\)#\s*\S\+o\ze"
syntax match rplOctal		   "\(^\|\s\+\)#\s*\o\+o\ze\($\|\s\+\)"
syntax match rplDecimalError	   "\(^\|\s\+\)#\s*\S\+d\ze"
syntax match rplDecimal		   "\(^\|\s\+\)#\s*\d\+d\ze\($\|\s\+\)"
syntax match rplHexadecimalError   "\(^\|\s\+\)#\s*\S\+h\ze"
syntax match rplHexadecimal	   "\(^\|\s\+\)#\s*\x\+h\ze\($\|\s\+\)"

" Case unsensitive
syntax case ignore

syntax match rplControl		   "\(^\|\s\+\)abort\ze\($\|\s\+\)"
syntax match rplControl		   "\(^\|\s\+\)kill\ze\($\|\s\+\)"
syntax match rplControl		   "\(^\|\s\+\)cont\ze\($\|\s\+\)"
syntax match rplControl		   "\(^\|\s\+\)halt\ze\($\|\s\+\)"
syntax match rplControl		   "\(^\|\s\+\)cmlf\ze\($\|\s\+\)"
syntax match rplControl		   "\(^\|\s\+\)sst\ze\($\|\s\+\)"

syntax match rplConstant	   "\(^\|\s\+\)pi\ze\($\|\s\+\)"

syntax match rplStatement	   "\(^\|\s\+\)return\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)last\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)syzeval\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)wait\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)type\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)kind\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)eval\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)use\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)remove\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)external\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)dup\([2n]\|\)\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)drop\([2n]\|\)\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)depth\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)roll\(d\|\)\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)pick\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)rot\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)swap\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)over\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)clear\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)warranty\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)copyright\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)convert\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)date\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)time\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)mem\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)clmf\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)->num\ze\($\|\s\+\)"
syntax match rplStatement	   "\(^\|\s\+\)help\ze\($\|\s\+\)"

syntax match rplStorage		   "\(^\|\s\+\)get\(i\|r\|c\|\)\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)put\(i\|r\|c\|\)\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)rcl\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)purge\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)sinv\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)sneg\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)sconj\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)steq\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)rceq\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)vars\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)clusr\ze\($\|\s\+\)"
syntax match rplStorage		   "\(^\|\s\+\)sto\([+-/\*]\|\)\ze\($\|\s\+\)"

syntax match rplAlgConditional	   "\(^\|\s\+\)ift\(e\|\)\ze\($\|\s\+\)"

syntax match rplOperator	   "\(^\|\s\+\)and\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)\(x\|\)or\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)not\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)same\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)==\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)<=\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)=<\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)=>\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)>=\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)<>\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)>\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)<\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)[+-]\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)[/\*]\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)\^\ze\($\|\s\+\)"
syntax match rplOperator	   "\(^\|\s\+\)\*\*\ze\($\|\s\+\)"

syntax match rplBoolean		   "\(^\|\s\+\)true\ze\($\|\s\+\)"
syntax match rplBoolean		   "\(^\|\s\+\)false\ze\($\|\s\+\)"

syntax match rplReadWrite	   "\(^\|\s\+\)store\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)recall\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)\(\|wf\|un\)lock\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)open\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)close\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)delete\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)create\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)format\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)rewind\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)backspace\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)\(\|re\)write\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)read\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)inquire\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)sync\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)append\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)suppress\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)seek\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)pr\(1\|int\|st\|stc\|lcd\|var\|usr\|md\)\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)paper\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)cr\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)erase\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)disp\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)input\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)prompt\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)key\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)cllcd\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)\(\|re\)draw\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)drax\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)indep\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)depnd\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)res\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)axes\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)label\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)pmin\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)pmax\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)centr\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)persist\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)title\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)\(slice\|auto\|log\|\)scale\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)eyept\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)\(p\|s\)par\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)function\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)polar\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)scatter\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)plotter\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)wireframe\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)parametric\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)slice\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)\*w\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)\*h\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)\*d\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)\*s\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)->lcd\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)lcd->\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)edit\ze\($\|\s\+\)"
syntax match rplReadWrite	   "\(^\|\s\+\)visit\ze\($\|\s\+\)"

syntax match rplIntrinsic	   "\(^\|\s\+\)abs\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)arg\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)conj\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)re\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)im\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)mant\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)xpon\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)ceil\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)fact\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)fp\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)floor\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)inv\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)ip\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)max\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)min\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)mod\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)neg\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)relax\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)sign\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)sq\(\|rt\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)xroot\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)cos\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)sin\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)tan\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)tg\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)a\(\|rc\)cos\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)a\(\|rc\)sin\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)atan\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)arctg\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|a\)cosh\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|a\)sinh\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|a\)tanh\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|arg\)th\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)arg[cst]h\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|a\)log\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)ln\(\|1\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)exp\(\|m\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)trn\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)con\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)idn\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)rdm\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)rsd\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)cnrm\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)cross\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)d[eo]t\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)[cr]swp\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)rci\(j\|\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(in\|de\)cr\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)bessel\ze\($\|\s\+\)"

syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|g\)egvl\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|g\)\(\|l\|r\)egv\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)rnrm\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(std\|fix\|sci\|eng\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(rad\|deg\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|n\)rand\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)rdz\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|i\)fft\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(dec\|bin\|oct\|hex\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)rclf\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)stof\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)[cs]f\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)chr\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)num\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)pos\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)sub\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)size\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(st\|rc\)ws\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(r\|s\)\(r\|l\)\(\|b\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)as\(r\|l\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(int\|der\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)stos\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|r\)cls\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)drws\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)scls\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)ns\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)tot\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)mean\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|p\)sdev\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|p\)var\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)maxs\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)mins\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|p\)cov\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)cols\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)s\(x\(\|y\|2\)\|y\(\|2\)\)\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(x\|y\)col\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)corr\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)utp[cfnt]\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)comb\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)perm\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)\(\|p\)lu\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)[lu]chol\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)schur\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)%\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)%ch\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)%t\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)hms->\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)->hms\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)hms+\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)hms-\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)d->r\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)r->d\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)b->r\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)r->b\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)c->r\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)r->c\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)r->p\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)p->r\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)str->\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)->str\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)array->\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)->array\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)list->\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)->list\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)s+\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)s-\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)col-\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)col+\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)row-\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)row+\ze\($\|\s\+\)"
syntax match rplIntrinsic	   "\(^\|\s\+\)->q\ze\($\|\s\+\)"

syntax match rplObsolete	   "\(^\|\s\+\)arry->\ze\($\|\s\+\)"hs=e-5
syntax match rplObsolete	   "\(^\|\s\+\)->arry\ze\($\|\s\+\)"hs=e-5

" Conditional structures
syntax match rplConditionalError   "\(^\|\s\+\)case\ze\($\|\s\+\)"hs=e-3
syntax match rplConditionalError   "\(^\|\s\+\)then\ze\($\|\s\+\)"hs=e-3
syntax match rplConditionalError   "\(^\|\s\+\)else\ze\($\|\s\+\)"hs=e-3
syntax match rplConditionalError   "\(^\|\s\+\)elseif\ze\($\|\s\+\)"hs=e-5
syntax match rplConditionalError   "\(^\|\s\+\)end\ze\($\|\s\+\)"hs=e-2
syntax match rplConditionalError   "\(^\|\s\+\)\(step\|next\)\ze\($\|\s\+\)"hs=e-3
syntax match rplConditionalError   "\(^\|\s\+\)until\ze\($\|\s\+\)"hs=e-4
syntax match rplConditionalError   "\(^\|\s\+\)repeat\ze\($\|\s\+\)"hs=e-5
syntax match rplConditionalError   "\(^\|\s\+\)default\ze\($\|\s\+\)"hs=e-6

" FOR/(CYCLE)/(EXIT)/NEXT
" FOR/(CYCLE)/(EXIT)/STEP
" START/(CYCLE)/(EXIT)/NEXT
" START/(CYCLE)/(EXIT)/STEP
syntax match rplCycle              "\(^\|\s\+\)\(cycle\|exit\)\ze\($\|\s\+\)"
syntax region rplForNext matchgroup=rplRepeat start="\(^\|\s\+\)\(for\|start\)\ze\($\|\s\+\)" end="\(^\|\s\+\)\(next\|step\)\ze\($\|\s\+\)" contains=ALL keepend extend

" ELSEIF/END
syntax region rplElseifEnd matchgroup=rplConditional start="\(^\|\s\+\)elseif\ze\($\|\s\+\)" end="\(^\|\s\+\)end\ze\($\|\s\+\)" contained contains=ALLBUT,rplElseEnd keepend

" ELSE/END
syntax region rplElseEnd matchgroup=rplConditional start="\(^\|\s\+\)else\ze\($\|\s\+\)" end="\(^\|\s\+\)end\ze\($\|\s\+\)" contained contains=ALLBUT,rplElseEnd,rplThenEnd,rplElseifEnd keepend

" THEN/END
syntax region rplThenEnd matchgroup=rplConditional start="\(^\|\s\+\)then\ze\($\|\s\+\)" end="\(^\|\s\+\)end\ze\($\|\s\+\)" contained containedin=rplIfEnd contains=ALLBUT,rplThenEnd keepend

" IF/END
syntax region rplIfEnd matchgroup=rplConditional start="\(^\|\s\+\)if\(err\|\)\ze\($\|\s\+\)" end="\(^\|\s\+\)end\ze\($\|\s\+\)" contains=ALLBUT,rplElseEnd,rplElseifEnd keepend extend
" if end is accepted !
" select end too !

" CASE/THEN
syntax region rplCaseThen matchgroup=rplConditional start="\(^\|\s\+\)case\ze\($\|\s\+\)" end="\(^\|\s\+\)then\ze\($\|\s\+\)" contains=ALLBUT,rplCaseThen,rplCaseEnd,rplThenEnd keepend extend contained containedin=rplCaseEnd

" CASE/END
syntax region rplCaseEnd matchgroup=rplConditional start="\(^\|\s\+\)case\ze\($\|\s\+\)" end="\(^\|\s\+\)end\ze\($\|\s\+\)" contains=ALLBUT,rplCaseEnd,rplThenEnd,rplElseEnd keepend extend contained containedin=rplSelectEnd

" DEFAULT/END
syntax region rplDefaultEnd matchgroup=rplConditional start="\(^\|\s\+\)default\ze\($\|\s\+\)" end="\(^\|\s\+\)end\ze\($\|\s\+\)" contains=ALLBUT,rplDefaultEnd keepend contained containedin=rplSelectEnd

" SELECT/END
syntax region rplSelectEnd matchgroup=rplConditional start="\(^\|\s\+\)select\ze\($\|\s\+\)" end="\(^\|\s\+\)end\ze\($\|\s\+\)" contains=ALLBUT,rplThenEnd keepend extend
" select end is accepted !

" DO/UNTIL/END
syntax region rplUntilEnd matchgroup=rplConditional start="\(^\|\s\+\)until\ze\($\|\s\+\)" end="\(^\|\s\+\)\zsend\ze\($\|\s\+\)" contains=ALLBUT,rplUntilEnd contained containedin=rplDoUntil extend keepend
syntax region rplDoUntil matchgroup=rplConditional start="\(^\|\s\+\)do\ze\($\|\s\+\)" end="\(^\|\s\+\)until\ze\($\|\s\+\)" contains=ALL keepend extend

" WHILE/REPEAT/END
syntax region rplRepeatEnd matchgroup=rplConditional start="\(^\|\s\+\)repeat\ze\($\|\s\+\)" end="\(^\|\s\+\)\zsend\ze\($\|\s\+\)" contains=ALLBUT,rplRepeatEnd contained containedin=rplWhileRepeat extend keepend
syntax region rplWhileRepeat matchgroup=rplConditional start="\(^\|\s\+\)while\ze\($\|\s\+\)" end="\(^\|\s\+\)repeat\ze\($\|\s\+\)" contains=ALL keepend extend

" Comments
syntax match rplCommentError "\*/"
syntax region rplCommentString contained start=+"+ end=+"+ end=+\*/+me=s-1
syntax region rplCommentLine start="\(^\|\s\+\)//\ze" skip="\\$" end="$" contains=NONE keepend extend
syntax region rplComment start="\(^\|\s\+\)/\*\ze" end="\*/" contains=rplCommentString keepend extend

" Catch errors caused by too many right parentheses
syntax region rplParen transparent start="(" end=")" contains=ALLBUT,rplParenError,rplComplex,rplIncluded keepend extend
syntax match rplParenError ")"

" Subroutines
" Catch errors caused by too many right '>>'
syntax match rplSubError "\(^\|\s\+\)>>\ze\($\|\s\+\)"hs=e-1
syntax region rplSub matchgroup=rplSubDelimitor start="\(^\|\s\+\)<<\ze\($\|\s\+\)" end="\(^\|\s\+\)>>\ze\($\|\s\+\)" contains=ALLBUT,rplSubError,rplIncluded,rplDefaultEnd,rplStorageSub keepend extend

" Expressions
syntax region rplExpr start="\(^\|\s\+\)'" end="'\ze\($\|\s\+\)" contains=rplParen,rplParenError

" Local variables
syntax match rplStorageError "\(^\|\s\+\)->\ze\($\|\s\+\)"hs=e-1
syntax region rplStorageSub matchgroup=rplStorage start="\(^\|\s\+\)<<\ze\($\|\s\+\)" end="\(^\|\s\+\)>>\ze\($\|\s\+\)" contains=ALLBUT,rplSubError,rplIncluded,rplDefaultEnd,rplStorageExpr contained containedin=rplLocalStorage keepend extend
syntax region rplStorageExpr matchgroup=rplStorage start="\(^\|\s\+\)'" end="'\ze\($\|\s\+\)" contains=rplParen,rplParenError extend contained containedin=rplLocalStorage
syntax region rplLocalStorage matchgroup=rplStorage start="\(^\|\s\+\)->\ze\($\|\s\+\)" end="\(^\|\s\+\)\(<<\ze\($\|\s\+\)\|'\)" contains=rplStorageSub,rplStorageExpr,rplComment,rplCommentLine keepend extend

" Catch errors caused by too many right brackets
syntax match rplArrayError "\]"
syntax match rplArray "\]" contained containedin=rplArray
syntax region rplArray matchgroup=rplArray start="\[" end="\]" contains=ALLBUT,rplArrayError keepend extend

" Catch errors caused by too many right '}'
syntax match rplListError "}"
syntax match rplList "}" contained containedin=rplList
syntax region rplList matchgroup=rplList start="{" end="}" contains=ALLBUT,rplListError,rplIncluded keepend extend

" cpp is used by RPL/2
syntax match rplPreProc   "\_^#\s*\(define\|undef\)\>"
syntax match rplPreProc   "\_^#\s*\(warning\|error\)\>"
syntax match rplPreCondit "\_^#\s*\(if\|ifdef\|ifndef\|elif\|else\|endif\)\>"
syntax match rplIncluded contained "\<<\s*\S*\s*>\>"
syntax match rplInclude   "\_^#\s*include\>\s*["<]" contains=rplIncluded,rplString
"syntax match rplExecPath  "\%^\_^#!\s*\S*"
syntax match rplExecPath  "\%^\_^#!\p*\_$"

" Any integer
syntax match rplInteger    "\(^\|\s\+\)[-+]\=\d\+\ze\($\|\s\+\)"

" Floating point number
" [S][ip].[fp]
syntax match rplFloat       "\(^\|\s\+\)[-+]\=\(\d*\)\=[\.,]\(\d*\)\=\ze\($\|\s\+\)" contains=ALLBUT,rplPoint,rplSign
" [S]ip[.fp]E[S]exp
syntax match rplFloat       "\(^\|\s\+\)[-+]\=\d\+\([\.,]\d*\)\=[eE]\([-+]\)\=\d\+\ze\($\|\s\+\)" contains=ALLBUT,rplPoint,rplSign
" [S].fpE[S]exp
syntax match rplFloat       "\(^\|\s\+\)[-+]\=\(\d*\)\=[\.,]\d\+[eE]\([-+]\)\=\d\+\ze\($\|\s\+\)" contains=ALLBUT,rplPoint,rplSign
syntax match rplPoint      "\<[\.,]\>"
syntax match rplSign       "\<[+-]\>"

" Complex number
" (x,y)
syntax match rplComplex    "\(^\|\s\+\)([-+]\=\(\d*\)\=\.\=\d*\([eE][-+]\=\d\+\)\=\s*,\s*[-+]\=\(\d*\)\=\.\=\d*\([eE][-+]\=\d\+\)\=)\ze\($\|\s\+\)"
" (x.y)
syntax match rplComplex    "\(^\|\s\+\)([-+]\=\(\d*\)\=,\=\d*\([eE][-+]\=\d\+\)\=\s*\.\s*[-+]\=\(\d*\)\=,\=\d*\([eE][-+]\=\d\+\)\=)\ze\($\|\s\+\)"

" Strings
syntax match rplStringGuilles       "\\\""
syntax match rplStringAntislash     "\\\\"
syntax region rplString start=+\(^\|\s\+\)"+ end=+"\ze\($\|\s\+\)+ contains=rplStringGuilles,rplStringAntislash

syntax match rplTab "\t"  transparent

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_rpl_syntax_inits")
  if version < 508
    let did_rpl_syntax_inits = 1
    command -nargs=+ HiLink highlight link <args>
  else
    command -nargs=+ HiLink highlight default link <args>
  endif

  " The default highlighting.

  HiLink rplControl		Statement
  HiLink rplStatement		Statement
  HiLink rplAlgConditional	Conditional
  HiLink rplConditional		Repeat
  HiLink rplConditionalError	Error
  HiLink rplRepeat		Repeat
  HiLink rplCycle		Repeat
  HiLink rplUntil		Repeat
  HiLink rplIntrinsic		Special
  HiLink rplStorage		StorageClass
  HiLink rplStorageExpr		StorageClass
  HiLink rplStorageError	Error
  HiLink rplReadWrite		rplIntrinsic

  HiLink rplOperator		Operator

  HiLink rplList		Special
  HiLink rplArray		Special
  HiLink rplConstant		Identifier
  HiLink rplExpr		Type

  HiLink rplString		String
  HiLink rplStringGuilles	String
  HiLink rplStringAntislash	String

  HiLink rplBinary		Boolean
  HiLink rplOctal		Boolean
  HiLink rplDecimal		Boolean
  HiLink rplHexadecimal		Boolean
  HiLink rplInteger		Number
  HiLink rplFloat		Float
  HiLink rplComplex		Float
  HiLink rplBoolean		Identifier

  HiLink rplObsolete		Todo

  HiLink rplPreCondit		PreCondit
  HiLink rplInclude		Include
  HiLink rplIncluded		rplString
  HiLink rplInclude		Include
  HiLink rplExecPath		Include
  HiLink rplPreProc		PreProc
  HiLink rplComment		Comment
  HiLink rplCommentLine		Comment
  HiLink rplCommentString	Comment
  HiLink rplSubDelimitor	rplStorage
  HiLink rplCommentError	Error
  HiLink rplParenError		Error
  HiLink rplSubError		Error
  HiLink rplArrayError		Error
  HiLink rplListError		Error
  HiLink rplTab			Error
  HiLink rplBinaryError		Error
  HiLink rplOctalError		Error
  HiLink rplDecimalError	Error
  HiLink rplHexadecimalError	Error

  delcommand HiLink
endif

let b:current_syntax = "rpl"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8 tw=132
