" Vim syntax file
"
" Language:        Moodle GIFT (General Import Format Template)
" Maintainer:      Selim Temizer (http://selimtemizer.com)
" Creation:        November 28, 2020
" Latest Revision: December 21, 2020
" Note:            The order of entities in this file is important!

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif


setlocal conceallevel=1

"-----------------------------------------------
" GIFT entities

syn match giftS        "\~"          contained                    "GIFT special characters
syn match giftS         "="          contained
syn match giftS         "#"          contained
syn match giftS         "{"          contained
syn match giftS         "}"          contained
syn match giftS         ":"          contained

syn match giftES     "\\\~"          contained  conceal  cchar=~  "GIFT escaped special characters
syn match giftES      "\\="          contained  conceal  cchar==
syn match giftES      "\\#"          contained  conceal  cchar=#
syn match giftES      "\\{"          contained  conceal  cchar={
syn match giftES      "\\}"          contained  conceal  cchar=}
syn match giftES      "\\:"          contained  conceal  cchar=:

syn match giftEN      "\\n"          contained  conceal  cchar=n  "GIFT escaped newline

syn match giftFormat  "\[html]"      contained                    "GIFT formats
syn match giftFormat  "\[plain]"     contained
syn match giftFormat  "\[moodle]"    contained
syn match giftFormat  "\[markdown]"  contained

"--------------------------------------------------------
" HTML entities

syn match giftH            "<"       contained                    "HTML characters that might need to be handled/escaped
syn match giftH            ">"       contained
syn match giftH            "&"       contained

syn match giftEH        "&lt;"       contained  conceal  cchar=<  "HTML escaped characters
syn match giftEH        "&gt;"       contained  conceal  cchar=>
syn match giftEH       "&amp;"       contained  conceal  cchar=&
syn match giftEH      "&nbsp;"       contained  conceal  cchar=_

"-------------------------------------------------------
" Answer components: Feedback and general feedback

syn match giftFB           "#\_.\{-}\(\_^\|[^\\]\)\ze\(=\|\~\|#\|####\|}\)"           contained  contains=giftF       "Feedback block
syn match giftF         "#\zs\_.\{-}\(\_^\|[^\\]\)\ze\(=\|\~\|#\|####\|}\)"           contained  contains=@giftCEF    "Feedback

syn match giftGFB          "####\_.\{-}\(\_^\|[^\\]\)\ze}"                            contained  contains=giftGF      "General feedback block
syn match giftGF        "####\zs\_.\{-}\(\_^\|[^\\]\)\ze}"                            contained  contains=@giftCEF    "General feedback

"------------------------------------------------------
" Answer components: Other components

syn keyword giftTF      T TRUE F FALSE                                                contained

syn match   giftNum1    "[-+]\=[.0-9]\+"                                              contained                       "Something matching a number

syn match   giftNum2    "[-+]\=[.0-9]\+\s*:\s*[-+]\=[.0-9]\+"                         contained  contains=giftNum2D   "Number with error margin
syn match   giftNum2D                    ":"                                          contained                       "Associated delimiter

syn match   giftNum3    "[-+]\=[.0-9]\+\s*\.\.\s*[-+]\=[.0-9]\+"                      contained  contains=giftNum3D   "Number as min/max range
syn match   giftNum3D                    "\.\."                                       contained                       "Associated delimiter

syn match   giftWeightB    "%-*[0-9]\{1,2}\.\?[0-9]*%"                                contained  contains=giftWeight  "Weight block
syn match   giftWeight  "%\zs-*[0-9]\{1,2}\.\?[0-9]*\ze%"                             contained                       "Weight

"-----------------------------------------------------
" Answer choices

syn match giftWrongNum  "\~\zs\_.\{-}\(\_^\|[^\\]\)\ze\(####\|}\)"                    contained  contains=@giftCEFF             "Wrong numeric choice
syn match giftRightNum   "=\zs\_.\{-}\(\_^\|[^\\]\)\ze\(=\|\~\|####\|}\)"             contained  contains=@giftCEFFW,@giftNums  "Right numeric choice

syn match giftWrong     "\~\zs\_.\{-}\(\_^\|[^\\]\)\ze\(=\|\~\|####\|}\)"             contained  contains=@giftCEFFW            "Wrong choice
syn match giftRight      "=\zs\_.\{-}\(\ze->\|\(\_^\|[^\\]\)\ze\(=\|\~\|####\|}\)\)"  contained  contains=@giftCEFFW            "Right choice
syn match giftMatchB                "->\_.\{-}\(\_^\|[^\\]\)\ze\(=\|\~\|####\|}\)"    contained  contains=giftMatch             "Match choice block
syn match giftMatch              "->\zs\_.\{-}\(\_^\|[^\\]\)\ze\(=\|\~\|####\|}\)"    contained  contains=@giftCE               "Match choice

"----------------------------------------------------
" Answer

syn match giftAnswer      "{\_.\{-}\(\_^\|[^\\]\)}"                                   contained  keepend  contains=@giftA     "General answer
syn match giftAnswer      "{}"                                                        contained                               "Minimal answer

syn match giftAnswerNum      "{\_[[:space:]]*#\_[^#]\_.\{-}\(\_^\|[^\\]\)}"           contained  keepend  contains=@giftANum  "Numeric answer
syn match giftAnswerNumD  "{\zs\_[[:space:]]*#"                                       contained                               "Associated delimiter

"---------------------------------------------------
" Question

" The first pattern matches the last question at the end of the file (in case there is no empty line coming after).
" However, it slows down parsing (and especially scrolling up), therefore it is commented out.

"syn match giftQuestion  "[^{[:space:]]\_.\{-}\%$"                                               keepend  contains=@giftCEF,giftAnswer,giftAnswerNum
 syn match giftQuestion  "[^{[:space:]]\_.\{-}\n\(\s*\n\)\+"                                     keepend  contains=@giftCEF,giftAnswer,giftAnswerNum

"--------------------------------------------------
" Question name

syn match giftName       "::\_.\{-}::"                                                           contains=@giftCE,giftNameD  "Question name
syn match giftNameD      "::"                                                         contained                              "Associated delimiter

"-------------------------------------------------
" Category

syn match giftCategoryB  "^\s*\$CATEGORY:.*\n\+"                                                 contains=giftCategory       "Category block
syn match giftCategory   "^\s*\$CATEGORY:\zs.*\ze\n"                                  contained                              "Category

"------------------------------------------------
" Comments (may need to be the last entity)

syn keyword giftTodo     FIXME TODO NOTE FIX XXX                                      contained

syn match   giftIdB         "\[id:\(\\]\|[^][:cntrl:]]\)\+]"                          contained  contains=giftId             "Id block
syn match   giftId       "\[id:\zs\(\\]\|[^][:cntrl:]]\)\+\ze]"                       contained                              "Id

syn match   giftTagB        "\[tag:\(\\]\|[^]<>`[:cntrl:]]\)\+]"                      contained  contains=giftTag            "Tag block
syn match   giftTag      "\[tag:\zs\(\\]\|[^]<>`[:cntrl:]]\)\+\ze]"                   contained                              "Tag

syn match   giftComment  "^\s*//.*"                                                              contains=giftTodo,giftIdB,giftTagB

"-----------------------------------------------
" Clusters

"Comments and entities (to be escaped)
syn cluster giftCE    contains=giftComment,giftS,giftES,giftEN,giftH,giftEH

"The above plus format
syn cluster giftCEF   contains=@giftCE,giftFormat

"The above plus feedback block
syn cluster giftCEFF  contains=@giftCEF,giftFB

"The above plus weight block
syn cluster giftCEFFW contains=@giftCEFF,giftWeightB

"Possible numerical representations
syn cluster giftNums  contains=giftNum1,giftNum2,giftNum3

"Possible contents of answers
syn cluster giftA     contains=giftComment,giftTF,giftWrong,giftRight,giftMatchB,giftFB,giftGFB

"Possible contents of numerical answers
syn cluster giftANum  contains=giftAnswerNumD,giftComment,@giftNums,giftWrongNum,giftRightNum,giftFB,giftGFB

"-----------------------------------------------

let b:current_syntax = "gift"

"-----------------------------------------------

hi Conceal   ctermbg=NONE ctermfg=Blue       guibg=NONE guifg=Blue
hi Feedback  ctermbg=NONE ctermfg=DarkCyan   guibg=NONE guifg=DarkCyan
hi GFeedback ctermbg=NONE ctermfg=DarkGreen  guibg=NONE guifg=DarkGreen
hi WeightB   ctermbg=NONE ctermfg=DarkYellow guibg=NONE guifg=DarkYellow

"-----------------------------------------------

hi def link giftS          Error
hi def link giftES         Conceal
hi def link giftEN         Conceal
hi def link giftFormat     LineNr

hi def link giftH          Error
hi def link giftEH         Conceal

hi def link giftFB         PreProc
hi def link giftF          Feedback
hi def link giftGFB        Title
hi def link giftGF         GFeedback

hi def link giftTF         Question
hi def link giftNum1       Question
hi def link giftNum2       Question
hi def link giftNum2D      Special
hi def link giftNum3       Question
hi def link giftNum3D      Special
hi def link giftWeightB    WeightB
hi def link giftWeight     Identifier

hi def link giftWrongNum   Constant
hi def link giftRightNum   Question
hi def link giftWrong      Constant
hi def link giftRight      Question
hi def link giftMatchB     ModeMsg
hi def link giftMatch      Constant

hi def link giftAnswer     MoreMsg
hi def link giftAnswerNum  MoreMsg
hi def link giftAnswerNumD Identifier

hi def link giftQuestion   Identifier

hi def link giftName       PreProc
hi def link giftNameD      Directory

hi def link giftCategoryB  LineNr
hi def link giftCategory   Directory

hi def link giftTodo       Todo
hi def link giftIdB        LineNr
hi def link giftId         Title
hi def link giftTagB       LineNr
hi def link giftTag        Constant
hi def link giftComment    Comment
