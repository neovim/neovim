" Vim syntax file
" Language:	Nushell
" Maintainer:	El Kasztano
" URL:		https://github.com/elkasztano/nushell-syntax-vim
" License:	MIT <https://opensource.org/license/mit>
" Last Change:	2025 Sep 05

if exists("b:current_syntax")
  finish
endif

syn iskeyword @,192-255,-,_

syn match nuCmd "\<alias\>" display
syn match nuCmd "\<all\>" display
syn match nuCmd "\<ansi\>" display
syn match nuCmd "\<ansi gradient\>" display
syn match nuCmd "\<ansi link\>" display
syn match nuCmd "\<ansi strip\>" display
syn match nuCmd "\<any\>" display
syn match nuCmd "\<append\>" display
syn match nuCmd "\<ast\>" display
syn match nuCmd "\<banner\>" display
syn match nuCmd "\<bits\>" display
syn match nuCmd "\<bits and\>" display
syn match nuCmd "\<bits not\>" display
syn match nuCmd "\<bits or\>" display
syn match nuCmd "\<bits rol\>" display
syn match nuCmd "\<bits ror\>" display
syn match nuCmd "\<bits shl\>" display
syn match nuCmd "\<bits shr\>" display
syn match nuCmd "\<bits xor\>" display
syn match nuCmd "\<break\>" display
syn match nuCmd "\<bytes\>" display
syn match nuCmd "\<bytes add\>" display
syn match nuCmd "\<bytes at\>" display
syn match nuCmd "\<bytes build\>" display
syn match nuCmd "\<bytes collect\>" display
syn match nuCmd "\<bytes ends-with\>" display
syn match nuCmd "\<bytes index-of\>" display
syn match nuCmd "\<bytes length\>" display
syn match nuCmd "\<bytes remove\>" display
syn match nuCmd "\<bytes replace\>" display
syn match nuCmd "\<bytes reverse\>" display
syn match nuCmd "\<bytes starts-with\>" display
syn match nuCmd "\<cal\>" display
syn match nuCmd "\<cd\>" display
syn match nuCmd "\<char\>" display
syn match nuCmd "\<clear\>" display
syn match nuCmd "\<collect\>" display
syn match nuCmd "\<columns\>" display
syn match nuCmd "\<commandline\>" display
syn match nuCmd "\<compact\>" display
syn match nuCmd "\<complete\>" display
syn match nuCmd "\<config\>" display
syn match nuCmd "\<config env\>" display
syn match nuCmd "\<config nu\>" display
syn match nuCmd "\<config reset\>" display
syn match nuCmd "\<const\>" nextgroup=nuIdtfr,nuSubCmd,nuDefflag skipwhite display
syn match nuCmd "\<continue\>" display
syn match nuCmd "\<cp\>" display
syn match nuCmd "\<cp-old\>" display
syn match nuCmd "\<create_left_prompt\>" display
syn match nuCmd "\<create_right_prompt\>" display
syn match nuCmd "\<date\>" display
syn match nuCmd "\<date format\>" display
syn match nuCmd "\<date humanize\>" display
syn match nuCmd "\<date list-timezone\>" display
syn match nuCmd "\<date now\>" display
syn match nuCmd "\<date to-record\>" display
syn match nuCmd "\<date to-table\>" display
syn match nuCmd "\<date to-timezone\>" display
syn match nuCmd "\<debug\>" display
syn match nuCmd "\<debug info\>" display
syn match nuCmd "\<decode\>" display
syn match nuCmd "\<decode base64\>" display
syn match nuCmd "\<decode hex\>" display
syn match nuCmd "\<def\>" nextgroup=nuIdtfr,nuSubCmd,nuDefflag skipwhite display
syn match nuCmd "\<def-env\>" nextgroup=nuIdtfr,nuSubCmd,nuDefflag skipwhite display
syn match nuCmd "\<default\>" display
syn match nuCmd "\<describe\>" display
syn match nuCmd "\<detect columns\>" display
syn match nuCmd "\<drop\>" display
syn match nuCmd "\<dfr\>" display
syn match nuCmd "\<dfr agg\>" display
syn match nuCmd "\<dfr agg-groups\>" display
syn match nuCmd "\<dfr all-false\>" display
syn match nuCmd "\<dfr all-true\>" display
syn match nuCmd "\<dfr append\>" display
syn match nuCmd "\<dfr arg-max\>" display
syn match nuCmd "\<dfr arg-min\>" display
syn match nuCmd "\<dfr arg-sort\>" display
syn match nuCmd "\<dfr arg-true\>" display
syn match nuCmd "\<dfr arg-unique\>" display
syn match nuCmd "\<dfr arg-where\>" display
syn match nuCmd "\<dfr as\>" display
syn match nuCmd "\<dfr as-date\>" display
syn match nuCmd "\<dfr as-datetime\>" display
syn match nuCmd "\<dfr cache\>" display
syn match nuCmd "\<dfr col\>" display
syn match nuCmd "\<dfr collect\>" display
syn match nuCmd "\<dfr columns\>" display
syn match nuCmd "\<dfr concat-str\>" display
syn match nuCmd "\<dfr concatenate\>" display
syn match nuCmd "\<dfr contains\>" display
syn match nuCmd "\<dfr count\>" display
syn match nuCmd "\<dfr count-null\>" display
syn match nuCmd "\<dfr cumulative\>" display
syn match nuCmd "\<dfr datepart\>" display
syn match nuCmd "\<dfr drop\>" display
syn match nuCmd "\<dfr drop-duplicates\>" display
syn match nuCmd "\<dfr drop-nulls\>" display
syn match nuCmd "\<dfr dtypes\>" display
syn match nuCmd "\<dfr dummies\>" display
syn match nuCmd "\<dfr explode\>" display
syn match nuCmd "\<dfr expr-not\>" display
syn match nuCmd "\<dfr fetch\>" display
syn match nuCmd "\<dfr fill-nan\>" display
syn match nuCmd "\<dfr fill-null\>" display
syn match nuCmd "\<dfr filter\>" display
syn match nuCmd "\<dfr filter-with\>" display
syn match nuCmd "\<dfr first\>" display
syn match nuCmd "\<dfr flatten\>" display
syn match nuCmd "\<dfr get\>" display
syn match nuCmd "\<dfr get-day\>" display
syn match nuCmd "\<dfr get-hour\>" display
syn match nuCmd "\<dfr get-minute\>" display
syn match nuCmd "\<dfr get-month\>" display
syn match nuCmd "\<dfr get-nanosecond\>" display
syn match nuCmd "\<dfr get-ordinal\>" display
syn match nuCmd "\<dfr get-second\>" display
syn match nuCmd "\<dfr get-week\>" display
syn match nuCmd "\<dfr get-weekday\>" display
syn match nuCmd "\<dfr get-year\>" display
syn match nuCmd "\<dfr group-by\>" display
syn match nuCmd "\<dfr implode\>" display
syn match nuCmd "\<dfr into-df\>" display
syn match nuCmd "\<dfr into-lazy\>" display
syn match nuCmd "\<dfr into-nu\>" display
syn match nuCmd "\<dfr is-duplicated\>" display
syn match nuCmd "\<dfr is-in\>" display
syn match nuCmd "\<dfr is-not-null\>" display
syn match nuCmd "\<dfr is-null\>" display
syn match nuCmd "\<dfr is-unique\>" display
syn match nuCmd "\<dfr join\>" display
syn match nuCmd "\<dfr last\>" display
syn match nuCmd "\<dfr lit\>" display
syn match nuCmd "\<dfr lowercase\>" display
syn match nuCmd "\<dfr ls\>" display
syn match nuCmd "\<dfr max\>" display
syn match nuCmd "\<dfr mean\>" display
syn match nuCmd "\<dfr median\>" display
syn match nuCmd "\<dfr melt\>" display
syn match nuCmd "\<dfr min\>" display
syn match nuCmd "\<dfr n-unique\>" display
syn match nuCmd "\<dfr not\>" display
syn match nuCmd "\<dfr open\>" display
syn match nuCmd "\<dfr otherwise\>" display
syn match nuCmd "\<dfr quantile\>" display
syn match nuCmd "\<dfr query\>" display
syn match nuCmd "\<dfr rename\>" display
syn match nuCmd "\<dfr replace\>" display
syn match nuCmd "\<dfr replace-all\>" display
syn match nuCmd "\<dfr reverse\>" display
syn match nuCmd "\<dfr rolling\>" display
syn match nuCmd "\<dfr sample\>" display
syn match nuCmd "\<dfr select\>" display
syn match nuCmd "\<dfr set\>" display
syn match nuCmd "\<dfr set-with-idx\>" display
syn match nuCmd "\<dfr shape\>" display
syn match nuCmd "\<dfr shift\>" display
syn match nuCmd "\<dfr slice\>" display
syn match nuCmd "\<dfr sort-by\>" display
syn match nuCmd "\<dfr std\>" display
syn match nuCmd "\<dfr str-lengths\>" display
syn match nuCmd "\<dfr str-slice\>" display
syn match nuCmd "\<dfr strftime\>" display
syn match nuCmd "\<dfr sum\>" display
syn match nuCmd "\<dfr summary\>" display
syn match nuCmd "\<dfr take\>" display
syn match nuCmd "\<dfr to-arrow\>" display
syn match nuCmd "\<dfr to-avro\>" display
syn match nuCmd "\<dfr to-csv\>" display
syn match nuCmd "\<dfr to-jsonl\>" display
syn match nuCmd "\<dfr to-parquet\>" display
syn match nuCmd "\<dfr unique\>" display
syn match nuCmd "\<dfr uppercase\>" display
syn match nuCmd "\<dfr value-counts\>" display
syn match nuCmd "\<dfr var\>" display
syn match nuCmd "\<dfr when\>" display
syn match nuCmd "\<dfr with-column\>" display
syn match nuCmd "\<do\>" display
syn match nuCmd "\<drop\>" display
syn match nuCmd "\<drop column\>" display
syn match nuCmd "\<drop nth\>" display
syn match nuCmd "\<du\>" display
syn match nuCmd "\<each\>" display
syn match nuCmd "\<each while\>" display
syn match nuCmd "\<echo\>" display
syn match nuCmd "\<encode\>" display
syn match nuCmd "\<encode base64\>" display
syn match nuCmd "\<encode hex\>" display
syn match nuCmd "\<add\>" display
syn match nuCmd "\<enumerate\>" display
syn match nuCmd "\<error make\>" display
syn match nuCmd "\<every\>" display
syn match nuCmd "\<exec\>" display
syn match nuCmd "\<exit\>" display
syn match nuCmd "\<explain\>" display
syn match nuCmd "\<explore\>" display
syn match nuCmd "\<export\>" display
syn match nuCmd "\<export alias\>" display
syn match nuCmd "\<export const\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<export def\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<export def-env\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<export extern\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<export extern-wrapped\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<export module\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<export use\>" display
syn match nuCmd "\<export-env\>" display
syn match nuCmd "\<extern\>" display
syn match nuCmd "\<extern-wrapped\>" display
syn match nuCmd "\<fill\>" display
syn match nuCmd "\<filter\>" display
syn match nuCmd "\<find\>" display
syn match nuCmd "\<first\>" display
syn match nuCmd "\<flatten\>" display
syn match nuCmd "\<fmt\>" display
syn match nuCmd "\<for\>" display
syn match nuCmd "\<format\>" display
syn match nuCmd "\<format date\>" display
syn match nuCmd "\<format duration\>" display
syn match nuCmd "\<format filesize\>" display
syn match nuCmd "\<from\>" nextgroup=nuPrpty skipwhite display
syn match nuCmd "\<from csv\>" display
syn match nuCmd "\<from json\>" display
syn match nuCmd "\<from nuon\>" display
syn match nuCmd "\<from ods\>" display
syn match nuCmd "\<from ssv\>" display
syn match nuCmd "\<from toml\>" display
syn match nuCmd "\<from tsv\>" display
syn match nuCmd "\<from url\>" display
syn match nuCmd "\<from xlsx\>" display
syn match nuCmd "\<from xml\>" display
syn match nuCmd "\<from yaml\>" display
syn match nuCmd "\<from yml\>" display
syn match nuCmd "\<goto\>" display
syn match nuCmd "\<get\>" nextgroup=nuPrpty skipwhite display
syn match nuCmd "\<glob\>" display
syn match nuCmd "\<grid\>" display
syn match nuCmd "\<group\>" display
syn match nuCmd "\<group-by\>" nextgroup=nuPrpty skipwhite display
syn match nuCmd "\<hash\>" display
syn match nuCmd "\<hash md5\>" display
syn match nuCmd "\<hash sha256\>" display
syn match nuCmd "\<headers\>" display
syn match nuCmd "\<help\>" display
syn match nuCmd "\<help aliases\>" display
syn match nuCmd "\<help commands\>" display
syn match nuCmd "\<help escapes\>" display
syn match nuCmd "\<help externs\>" display
syn match nuCmd "\<help modules\>" display
syn match nuCmd "\<help operators\>" display
syn match nuCmd "\<hide\>" display
syn match nuCmd "\<hide-env\>" display
syn match nuCmd "\<histogram\>" display
syn match nuCmd "\<history\>" display
syn match nuCmd "\<history session\>" display
syn match nuCmd "\<http\> " display
syn match nuCmd "\<http delete\>" display
syn match nuCmd "\<http get\>" display
syn match nuCmd "\<http head\>" display
syn match nuCmd "\<http options\>" display
syn match nuCmd "\<http patch\>" display
syn match nuCmd "\<http post\>" display
syn match nuCmd "\<http put\>" display
syn match nuCmd "\<if\>" display
syn match nuCmd "\<ignore\>" display
syn match nuCmd "\<input\>" display
syn match nuCmd "\<input list\>" display
syn match nuCmd "\<input listen\>" display
syn match nuCmd "\<insert\>" display
syn match nuCmd "\<inspect\>" display
syn match nuCmd "\<into\>" display
syn match nuCmd "\<into binary\>" display
syn match nuCmd "\<into bits\>" display
syn match nuCmd "\<into bool\>" display
syn match nuCmd "\<into datetime\>" display
syn match nuCmd "\<into duration\>" display
syn match nuCmd "\<into filesize\>" display
syn match nuCmd "\<into float\>" display
syn match nuCmd "\<into int\>" display
syn match nuCmd "\<into record\>" display
syn match nuCmd "\<into sqlite\>" display
syn match nuCmd "\<into string\>" display
syn match nuCmd "\<into value\>" display
syn match nuCmd "\<is-admin\>" display
syn match nuCmd "\<is-empty\>" display
syn match nuCmd "\<items\>" display
syn match nuCmd "\<join\>" display
syn match nuCmd "\<keybindings\>" display
syn match nuCmd "\<keybindings default\>" display
syn match nuCmd "\<keybindings list\>" display
syn match nuCmd "\<keybindings listen\>" display
syn match nuCmd "\<kill\>" display
syn match nuCmd "\<last\>" display
syn match nuCmd "\<lazy make\>" display
syn match nuCmd "\<length\>" display
syn match nuCmd "\<let\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<let-env\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<lines\>" display
syn match nuCmd "\<load-env\>" display
syn match nuCmd "\<loop\>" display
syn match nuCmd "\<ls\>" display
syn match nuCmd "\<match\>" display
syn match nuCmd "\<math\>" display
syn match nuCmd "\<math abs\>" display
syn match nuCmd "\<math arccos\>" display
syn match nuCmd "\<math arccosh\>" display
syn match nuCmd "\<math arcsin\>" display
syn match nuCmd "\<math arcsinh\>" display
syn match nuCmd "\<math arctan\>" display
syn match nuCmd "\<math arctanh\>" display
syn match nuCmd "\<math avg\>" display
syn match nuCmd "\<math ceil\>" display
syn match nuCmd "\<math cos\>" display
syn match nuCmd "\<math cosh\>" display
syn match nuCmd "\<math exp\>" display
syn match nuCmd "\<math floor\>" display
syn match nuCmd "\<math ln\>" display
syn match nuCmd "\<math log\>" display
syn match nuCmd "\<math max\>" display
syn match nuCmd "\<math median\>" display
syn match nuCmd "\<math min\>" display
syn match nuCmd "\<math mode\>" display
syn match nuCmd "\<math product\>" display
syn match nuCmd "\<math round\>" display
syn match nuCmd "\<math sin\>" display
syn match nuCmd "\<math sinh\>" display
syn match nuCmd "\<math sqrt\>" display
syn match nuCmd "\<math stddev\>" display
syn match nuCmd "\<math sum\>" display
syn match nuCmd "\<math tan\>" display
syn match nuCmd "\<math tanh\>" display
syn match nuCmd "\<math variance\>" display
syn match nuCmd "\<merge\>" display
syn match nuCmd "\<metadata\>" display
syn match nuCmd "\<mkdir\>" display
syn match nuCmd "\<module\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<move\>" display
syn match nuCmd "\<mut\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<mv\>" display
syn match nuCmd "\<next\>" display
syn match nuCmd "\<nu-check\>" display
syn match nuCmd "\<nu-highlight\>" display
syn match nuCmd "\<open\>" display
syn match nuCmd "\<overlay\>" display
syn match nuCmd "\<overlay hide\>" display
syn match nuCmd "\<overlay list\>" display
syn match nuCmd "\<overlay new\>" display
syn match nuCmd "\<overlay use\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<prev\>" display
syn match nuCmd "\<par-each\>" display
syn match nuCmd "\<parse\>" display
syn match nuCmd "\<path\>" display
syn match nuCmd "\<path basename\>" display
syn match nuCmd "\<path dirname\>" display
syn match nuCmd "\<path exists\>" display
syn match nuCmd "\<path expand\>" display
syn match nuCmd "\<path join\>" display
syn match nuCmd "\<path parse\>" display
syn match nuCmd "\<path relative-to\>" display
syn match nuCmd "\<path split\>" display
syn match nuCmd "\<path type\>" display
syn match nuCmd "\<port\>" display
syn match nuCmd "\<prepend\>" display
syn match nuCmd "\<print\>" display
syn match nuCmd "\<profile\>" display
syn match nuCmd "\<ps\>" display
syn match nuCmd "\<pwd\>" display
syn match nuCmd "\<query db\>" display
syn match nuCmd "\<random\>" display
syn match nuCmd "\<random bool\>" display
syn match nuCmd "\<random chars\>" display
syn match nuCmd "\<random dice\>" display
syn match nuCmd "\<random float\>" display
syn match nuCmd "\<random int\>" display
syn match nuCmd "\<random integer\>" display
syn match nuCmd "\<random uuid\>" display
syn match nuCmd "\<range\>" display
syn match nuCmd "\<reduce\>" display
syn match nuCmd "\<register\>" display
syn match nuCmd "\<reject\>" display
syn match nuCmd "\<rename\>" display
syn match nuCmd "\<return\>" display
syn match nuCmd "\<reverse\>" display
syn match nuCmd "\<rm\>" display
syn match nuCmd "\<roll\>" display
syn match nuCmd "\<roll down\>" display
syn match nuCmd "\<roll left\>" display
syn match nuCmd "\<roll right\>" display
syn match nuCmd "\<roll up\>" display
syn match nuCmd "\<rotate\>" display
syn match nuCmd "\<run-external\>" display
syn match nuCmd "\<save\>" display
syn match nuCmd "\<schema\>" display
syn match nuCmd "\<scope\>" display
syn match nuCmd "\<scope aliases\>" display
syn match nuCmd "\<scope commands\>" display
syn match nuCmd "\<scope engine-stats\>" display
syn match nuCmd "\<scope externs\>" display
syn match nuCmd "\<scope modules\>" display
syn match nuCmd "\<scope variables\>" display
syn match nuCmd "\<select\>" display
syn match nuCmd "\<seq\>" display
syn match nuCmd "\<seq char\>" display
syn match nuCmd "\<seq date\>" display
syn match nuCmd "\<show\>" display
syn match nuCmd "\<shuffle\>" display
syn match nuCmd "\<size\>" display
syn match nuCmd "\<skip\>" display
syn match nuCmd "\<skip until\>" display
syn match nuCmd "\<skip while\>" display
syn match nuCmd "\<sleep\>" display
syn match nuCmd "\<sort\>" display
syn match nuCmd "\<sort-by\>" nextgroup=nuPrpty skipwhite display
syn match nuCmd "\<source\>" display
syn match nuCmd "\<source-env\>" display
syn match nuCmd "\<split\>" display
syn match nuCmd "\<split chars\>" display
syn match nuCmd "\<split column\>" display
syn match nuCmd "\<split list\>" display
syn match nuCmd "\<split row\>" display
syn match nuCmd "\<split words\>" display
syn match nuCmd "\<split-by\>" nextgroup=nuPrpty skipwhite display
syn match nuCmd "\<start\>" display
syn match nuCmd "\<str\>" display
syn match nuCmd "\<str camel-case\>" display
syn match nuCmd "\<str capitalize\>" display
syn match nuCmd "\<str contains\>" display
syn match nuCmd "\<str distance\>" display
syn match nuCmd "\<str downcase\>" display
syn match nuCmd "\<str ends-with\>" display
syn match nuCmd "\<str expand\>" display
syn match nuCmd "\<str index-of\>" display
syn match nuCmd "\<str join\>" display
syn match nuCmd "\<str kebab-case\>" display
syn match nuCmd "\<str length\>" display
syn match nuCmd "\<str pascal-case\>" display
syn match nuCmd "\<str replace\>" display
syn match nuCmd "\<str reverse\>" display
syn match nuCmd "\<str screaming-snake-case\>" display
syn match nuCmd "\<str snake-case\>" display
syn match nuCmd "\<str starts-with\>" display
syn match nuCmd "\<str substring\>" display
syn match nuCmd "\<str title-case\>" display
syn match nuCmd "\<str trim\>" display
syn match nuCmd "\<str upcase\>" display
syn match nuCmd "\<sys\>" display
syn match nuCmd "\<sys cpu\>" display
syn match nuCmd "\<sys disks\>" display
syn match nuCmd "\<sys host\>" display
syn match nuCmd "\<sys mem\>" display
syn match nuCmd "\<sys net\>" display
syn match nuCmd "\<sys temp\>" display
syn match nuCmd "\<sys users\>" display
syn match nuCmd "\<table\>" display
syn match nuCmd "\<take\>" display
syn match nuCmd "\<take until\>" display
syn match nuCmd "\<take while\>" display
syn match nuCmd "\<term size\>" display
syn match nuCmd "\<timeit\>" display
syn match nuCmd "\<to\>" display
syn match nuCmd "\<to csv\>" display
syn match nuCmd "\<to html\>" display
syn match nuCmd "\<to json\>" display
syn match nuCmd "\<to md\>" display
syn match nuCmd "\<to nuon\>" display
syn match nuCmd "\<to text\>" display
syn match nuCmd "\<to toml\>" display
syn match nuCmd "\<to tsv\>" display
syn match nuCmd "\<to xml\>" display
syn match nuCmd "\<to yaml\>" display
syn match nuCmd "\<touch\>" display
syn match nuCmd "\<transpose\>" display
syn match nuCmd "\<try\>" display
syn match nuCmd "\<tutor\>" display
syn match nuCmd "\<unfold\>" display
syn match nuCmd "\<uniq\>" display
syn match nuCmd "\<uniq-by\>" nextgroup=nuPrpty skipwhite display
syn match nuCmd "\<update\>" display
syn match nuCmd "\<update cells\>" display
syn match nuCmd "\<upsert\>" display
syn match nuCmd "\<url\>" display
syn match nuCmd "\<url build-query\>" display
syn match nuCmd "\<url decode\>" display
syn match nuCmd "\<url encode\>" display
syn match nuCmd "\<url join\>" display
syn match nuCmd "\<url parse\>" display
syn match nuCmd "\<use\>" nextgroup=nuIdtfr skipwhite display
syn match nuCmd "\<values\>" display
syn match nuCmd "\<version\>" display
syn match nuCmd "\<view\>" display
syn match nuCmd "\<view files\>" display
syn match nuCmd "\<view source\>" display
syn match nuCmd "\<view span\>" display
syn match nuCmd "\<watch\>" display
syn match nuCmd "\<where\>" nextgroup=nuPrpty skipwhite display
syn match nuCmd "\<which\>" display
syn match nuCmd "\<while\>" display
syn match nuCmd "\<whoami\>" display
syn match nuCmd "\<window\>" display
syn match nuCmd "\<with-env\>" display
syn match nuCmd "\<wrap\>" display
syn match nuCmd "\<zip\>" display
syn match nuCmd "\<exists\>" display
syn match nuCmd "\<attr category\>" display
syn match nuCmd "\<attr example\>" display
syn match nuCmd "\<attr search-terms\>" display
syn match nuCmd "\<bytes split\>" display
syn match nuCmd "\<chunk-by\>" display
syn match nuCmd "\<chunks\>" display
syn match nuCmd "\<commandline edit\>" display
syn match nuCmd "\<commandline get-cursor\>" display
syn match nuCmd "\<commandline set-cursor\>" display
syn match nuCmd "\<config flatten\>" display
syn match nuCmd "\<config use-colors\>" display
syn match nuCmd "\<date from-human\>" display
syn match nuCmd "\<debug profile\>" display
syn match nuCmd "\<decode base32\>" display
syn match nuCmd "\<decode base32hex\>" display
syn match nuCmd "\<encode base32\>" display
syn match nuCmd "\<encode base32hex\>" display
syn match nuCmd "\<format bits\>" display
syn match nuCmd "\<format number\>" display
syn match nuCmd "\<format pattern\>" display
syn match nuCmd "\<from msgpack\>" display
syn match nuCmd "\<from msgpackz\>" display
syn match nuCmd "\<generate\>" display
syn match nuCmd "\<help pipe-and-redirect\>" display
syn match nuCmd "\<history import\>" display
syn match nuCmd "\<interleave\>" display
syn match nuCmd "\<into cell-path\>" display
syn match nuCmd "\<into glob\>" display
syn match nuCmd "\<is-not-empty\>" display
syn match nuCmd "\<is-terminal\>" display
syn match nuCmd "\<job\>" display
syn match nuCmd "\<job flush\>" display
syn match nuCmd "\<job id\>" display
syn match nuCmd "\<job kill\>" display
syn match nuCmd "\<job list\>" display
syn match nuCmd "\<job recv\>" display
syn match nuCmd "\<job send\>" display
syn match nuCmd "\<job spawn\>" display
syn match nuCmd "\<job tag\>" display
syn match nuCmd "\<job unfreeze\>" display
syn match nuCmd "\<merge deep\>" display
syn match nuCmd "\<metadata access\>" display
syn match nuCmd "\<metadata set\>" display
syn match nuCmd "\<mktemp\>" display
syn match nuCmd "\<panic\>" display
syn match nuCmd "\<path self\>" display
syn match nuCmd "\<plugin\>" display
syn match nuCmd "\<plugin add\>" display
syn match nuCmd "\<plugin list\>" display
syn match nuCmd "\<plugin rm\>" display
syn match nuCmd "\<plugin stop\>" display
syn match nuCmd "\<plugin use\>" display
syn match nuCmd "\<random binary\>" display
syn match nuCmd "\<split cell-path\>" display
syn match nuCmd "\<stor create\>" display
syn match nuCmd "\<stor delete\>" display
syn match nuCmd "\<stor export\>" display
syn match nuCmd "\<stor import\>" display
syn match nuCmd "\<stor insert\>" display
syn match nuCmd "\<stor open\>" display
syn match nuCmd "\<stor reset\>" display
syn match nuCmd "\<stor update\>" display
syn match nuCmd "\<str stats\>" display
syn match nuCmd "\<tee\>" display
syn match nuCmd "\<term query\>" display
syn match nuCmd "\<to msgpack\>" display
syn match nuCmd "\<to msgpackz\>" display
syn match nuCmd "\<to yml\>" display
syn match nuCmd "\<ulimit\>" display
syn match nuCmd "\<uname\>" display
syn match nuCmd "\<url split-query\>" display
syn match nuCmd "\<version check\>" display
syn match nuCmd "\<view blocks\>" display
syn match nuCmd "\<view ir\>" display

syn match nuNumber "\([a-zA-Z_\.]\+\d*\)\@<!\d\+" nextgroup=nuUnit,nuDur
syn match nuNumber "\([a-zA-Z]\)\@<!\.\d\+" nextgroup=nuUnit,nuDur
syn match nuNumber "\([a-zA-Z]\)\@<!_\d\+" nextgroup=nuUnit,nuDur,nuNumber
syn match nuNumber "\d\+[eE][+-]\?\d\+" nextgroup=nuUnit,nuDur
syn match nuNumber "\d\+\.\d\+[eE]\?[+-]\d\+" nextgroup=nuUnit,nuDur

syn keyword nuTodo contained TODO FIXME NOTE
syn match nuComment "#.*$" contains=nuTodo

syn match nuOp "=" display
syn match nuOp "-" display
syn match nuOp "?" display
syn match nuOp "<" display
syn match nuOp ">" display
syn match nuOp "+" display
syn match nuOp "/" display
syn match nuOp "\*" display
syn match nuOp "!=" display
syn match nuOp "=\~" display
syn match nuOp "\!\~" display
syn match nuOp "\<in\>" nextgroup=nuPrpty skipwhite display
syn match nuOp "\<not-in\>" nextgroup=nuPrpty skipwhite display
syn match nuOp "\<not\>" display
syn match nuOp "\<and\>" nextgroup=nuPrpty skipwhite display
syn match nuOp "\<or\>" nextgroup=nuPrpty skipwhite display
syn match nuOp "\<xor\>" nextgroup=nuPrpty skipwhite display
syn match nuOp "\<bit-or\>" display
syn match nuOp "\<bit-xor\>" display
syn match nuOp "\<bit-and\>" display
syn match nuOp "\<bit-shl\>" display
syn match nuOp "\<bit-shr\>" display
syn match nuOp "\<starts-with\>" display
syn match nuOp "\<ends-with\>" display
syn match nuOp "\.\.\." display

syn match nuVar "\$[^?\])} \t]\+"

syn match nuIdtfr :\(-\+\)\@![^? \t"=]\+: contained

syn region nuSubCmd start=/"/ skip=/\\./ end=/"/ contained

syn match nuPrpty '\w\+' contained

syn keyword nuType any binary bool cell-path closure datetime directory duration error filesize float glob int list nothing number path range record string table true false null

syn keyword nuCondi if then else

syn match nuUnit "b\>" contained
syn match nuUnit "kb\>" contained
syn match nuUnit "mb\>" contained
syn match nuUnit "gb\>" contained
syn match nuUnit "tb\>" contained
syn match nuUnit "pb\>" contained
syn match nuUnit "eb\>" contained
syn match nuUnit "kib\>" contained
syn match nuUnit "mib\>" contained
syn match nuUnit "gib\>" contained
syn match nuUnit "tib\>" contained
syn match nuUnit "pib\>" contained
syn match nuUnit "eib\>" contained

syn match nuDur "ns\>" contained
syn match nuDur "us\>" contained
syn match nuDur "ms\>" contained
syn match nuDur "sec\>" contained
syn match nuDur "min\>" contained
syn match nuDur "hr\>" contained
syn match nuDur "day\>" contained
syn match nuDur "wk\>" contained

syn match nuFlag "\<-\k\+"

syn match nuDefflag "\<--env\>" display contained nextgroup=nuIdtfr skipwhite
syn match nuDefflag "\<--wrapped\>" display contained nextgroup=nuIdtfr skipwhite

syn match nuSysEsc "\^\k\+" display

syn match nuSqrbr "\[" display
syn match nuSqrbr "\]" display
syn match nuSqrbr ":" display

syn region nuString start=/\v"/ skip=/\v\\./ end=/\v"/ contains=nuEscaped
syn region nuString start='\'' end='\''
syn region nuString start='`' end='`'
syn region nuString start=/r#\+'/ end=/#\+/ contains=nuString

syn region nuStrInt start=/$'/ end=/'/ contains=nuNested
syn region nuStrInt start=/$"/ skip=/\\./ end=/"/ contains=nuNested,nuEscaped

syn region nuNested start="("hs=s+1 end=")"he=e-1 contained contains=nuAnsi
syn match nuAnsi "ansi[a-zA-Z0-9;' -]\+)"me=e-1 contained

syn match nuClosure "|\(\w\|, \)\+|"

syn match nuDot ")\.\(\k\|\.\)\+"ms=s+1 display

syn match nuEscaped "\\\\" display
syn match nuEscaped :\\": display
syn match nuEscaped "\\n" display
syn match nuEscaped "\\t" display
syn match nuEscaped "\\r" display

hi def link nuCmd	Keyword
hi def link nuComment	Comment
hi def link nuTodo	Todo
hi def link nuString	Constant
hi def link nuChar	Constant
hi def link nuOp	Operator
hi def link nuVar	PreProc
hi def link nuSqrBr	Special
hi def link nuIdtfr	Identifier
hi def link nuType	Type
hi def link nuUnit	Type
hi def link nuDur	Type
hi def link nuPrpty	Special
hi def link nuSubCmd	Identifier
hi def link nuStrInt	Constant
hi def link nuNested	PreProc
hi def link nuFlag	Special
hi def link nuEscaped	Special
hi def link nuCondi	Type
hi def link nuClosure	Type
hi def link nuNumber	Number
hi def link nuDot	Special
hi def link nuSysEsc	PreProc
hi def link nuAnsi	Special
hi def link nuDefflag	Special

let b:current_syntax = "nu"
