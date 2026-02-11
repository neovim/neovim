" Vim compiler file
" Compiler:	Maven
" Maintainer:	D. Ben Knoble <ben.knoble+vim@gmail.com>
" Maintainer:	Konfekt
" Original Source:	https://github.com/JalaiAmitahl/maven-compiler.vim/blob/master/compiler/mvn.vim
"                   (Copyright Dan Taylor, distributed under the same terms as LICENSE)
" Original Source:	https://github.com/mikelue/vim-maven-plugin/blob/master/compiler/maven.vim
"                   (distributed under same terms as LICENSE per
"                   https://github.com/mikelue/vim-maven-plugin/issues/13)
" Last Change:	2025 Nov 18

if exists("current_compiler")
  finish
endif
let current_compiler = "maven"

" CompilerSet makeprg=mvn
execute $'CompilerSet makeprg=mvn\ --batch-mode\ {escape(get(b:, 'maven_makeprg_params', get(g:, 'maven_makeprg_params', '')), ' \|"')}'

" Error message for POM
CompilerSet errorformat=[FATAL]\ Non-parseable\ POM\ %f:\ %m%\\s%\\+@%.%#line\ %l\\,\ column\ %c%.%#,
CompilerSet errorformat+=[%tRROR]\ Malformed\ POM\ %f:\ %m%\\s%\\+@%.%#line\ %l\\,\ column\ %c%.%#
" Handle Non-parseable POM with '@<line>:<col>' embedded in the 'position:' clause.
CompilerSet errorformat+=[FATAL]\ Non-parseable\ POM\ %f:\ %m%\\s%\\+%.%#@%l:%c%.%#,
CompilerSet errorformat+=[%tRROR]\ Malformed\ POM\ %f:\ %m%\\s%\\+%.%#@%l:%c%.%#,

" JavaC messages with paths relative to module root:
" With column:
CompilerSet errorformat+=[%tARNING]\ %f:[%l\\,%c]\ %m
CompilerSet errorformat+=[%tRROR]\ %f:[%l\\,%c]\ %m
CompilerSet errorformat+=%A[%t%[A-Z]%#]\ %f:[%l\\,%c]\ %m,%Z
CompilerSet errorformat+=%A%f:[%l\\,%c]\ %m,%Z
" Without column:
CompilerSet errorformat+=[%tARNING]\ %f:[%l]\ %m
CompilerSet errorformat+=[%tRROR]\ %f:[%l]\ %m
CompilerSet errorformat+=%A[%t%[A-Z]%#]\ %f:[%l]\ %m,%Z
CompilerSet errorformat+=%A%f:[%l]\ %m,%Z

" Plug-in messages with absolute paths:
" with column:
CompilerSet errorformat+=[%tARNING]\ %f:%l:%c:\ %m
CompilerSet errorformat+=[%tRROR]\ %f:%l:%c:\ %m
CompilerSet errorformat+=%A[%t%[A-Z]%#]\ %f:%l:%c:\ %m,%Z
CompilerSet errorformat+=%A%f:%l:%c:\ %m,%Z
" without column:
CompilerSet errorformat+=[%tARNING]\ %f:%l:\ %m
CompilerSet errorformat+=[%tRROR]\ %f:%l:\ %m
CompilerSet errorformat+=%A[%t%[A-Z]%#]\ %f:%l:\ %m,%Z
CompilerSet errorformat+=%A%f:%l:\ %m,%Z

" SpotBugs
CompilerSet errorformat+=[%tRROR]\ %m%\\s%\\+\[%*[^]]]%\\s%\\+In\ %f\ %.%#,
CompilerSet errorformat+=[%tARNING]\ %m%\\s%\\+\[%*[^]]]%\\s%\\+In\ %f\ %.%#,
CompilerSet errorformat+=[%tRROR]\ %.%#\ [aA]t\ %f:\[lines\ %l-%\\d\\+]\ %.%#,
CompilerSet errorformat+=[%tARNING]\ %.%#\ [aA]t\ %f:\[lines\ %l-%\\d\\+]\ %.%#,
CompilerSet errorformat+=[%tRROR]\ %.%#\ [aA]t\ %f:\[line\ %l]\ %.%#,
CompilerSet errorformat+=[%tARNING]\ %.%#\ [aA]t\ %f:\[line\ %l]\ %.%#,

" jUnit related build messages
CompilerSet errorformat+=%+E\ \ %#test%m,%Z
CompilerSet errorformat+=%+E[ERROR]\ Please\ refer\ to\ %f\ for\ the\ individual\ test\ results.
" Message from JUnit 5(5.3.X), TestNG(6.14.X), JMockit(1.43), and AssertJ(3.11.X)
CompilerSet errorformat+=%+E%>[ERROR]\ %.%\\+Time\ elapsed:%.%\\+<<<\ FAILURE!,
CompilerSet errorformat+=%+E%>[ERROR]\ %.%\\+Time\ elapsed:%.%\\+<<<\ ERROR!,
CompilerSet errorformat+=%+Z%\\s%#at\ %f(%\\f%\\+:%l),
CompilerSet errorformat+=%+C%.%#

" Misc message removal
" CompilerSet errorformat+=%-GPicked\ up\ _JAVA_OPTIONS\ %.%#,
CompilerSet errorformat+=%-GAudit\ done.,
CompilerSet errorformat+=%-G[INFO]\ %.%#,
CompilerSet errorformat+=%-G[debug]\ %.%#
