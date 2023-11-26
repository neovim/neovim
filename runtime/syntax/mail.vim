" Vim syntax file
" Language:		Mail file
" Previous Maintainer:	Felix von Leitner <leitner@math.fu-berlin.de>
" Maintainer:		GI <a@b.c>, where a='gi1242+vim', b='gmail', c='com'
" Last Change:		Wed 14 Aug 2013 08:24:52 AM PDT

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" The mail header is recognized starting with a "keyword:" line and ending
" with an empty line or other line that can't be in the header. All lines of
" the header are highlighted. Headers of quoted messages (quoted with >) are
" also highlighted.

" Syntax clusters
syn cluster mailHeaderFields	contains=mailHeaderKey,mailSubject,mailHeaderEmail,@mailLinks
syn cluster mailLinks		contains=mailURL,mailEmail
syn cluster mailQuoteExps	contains=mailQuoteExp1,mailQuoteExp2,mailQuoteExp3,mailQuoteExp4,mailQuoteExp5,mailQuoteExp6

syn case match
" For "From " matching case is required. The "From " is not matched in quoted
" emails
" According to RFC 2822 any printable ASCII character can appear in a field
" name, except ':'.
syn region	mailHeader	contains=@mailHeaderFields,@NoSpell start="^From .*\d\d\d\d$" skip="^\s" end="\v^[!-9;-~]*([^!-~]|$)"me=s-1 fold
syn match	mailHeaderKey	contained contains=mailEmail,@NoSpell "^From\s.*\d\d\d\d$"

" Nothing else depends on case. 
syn case ignore

" Headers in properly quoted (with "> " or ">") emails are matched
syn region	mailHeader	keepend contains=@mailHeaderFields,@mailQuoteExps,@NoSpell start="^\z(\(> \?\)*\)\v(newsgroups|x-([a-z\-])*|path|xref|message-id|from|((in-)?reply-)?to|b?cc|subject|return-path|received|date|replied):" skip="^\z1\s" end="\v^\z1[!-9;-~]*([^!-~]|$)"me=s-1 end="\v^\z1@!"me=s-1 end="\v^\z1(\> ?)+"me=s-1 fold

" Usenet headers
syn match	mailHeaderKey	contained contains=mailHeaderEmail,mailEmail,@NoSpell "\v(^(\> ?)*)@<=(Newsgroups|Followup-To|Message-ID|Supersedes|Control):.*$"


syn region	mailHeaderKey	contained contains=mailHeaderEmail,mailEmail,@mailQuoteExps,@NoSpell start="\v(^(\> ?)*)@<=(to|b?cc):" skip=",$" end="$"
syn match	mailHeaderKey	contained contains=mailHeaderEmail,mailEmail,@NoSpell "\v(^(\> ?)*)@<=(from|reply-to):.*$" fold
syn match	mailHeaderKey	contained contains=@NoSpell "\v(^(\> ?)*)@<=date:"
syn match	mailSubject	contained "\v^subject:.*$" fold
syn match	mailSubject	contained contains=@NoSpell "\v(^(\> ?)+)@<=subject:.*$"

" Anything in the header between < and > is an email address
syn match	mailHeaderEmail	contained contains=@NoSpell "<.\{-}>"

" Mail Signatures. (Begin with "-- ", end with change in quote level)
syn region	mailSignature	keepend contains=@mailLinks,@mailQuoteExps start="^--\s$" end="^$" end="^\(> \?\)\+"me=s-1 fold
syn region	mailSignature	keepend contains=@mailLinks,@mailQuoteExps,@NoSpell start="^\z(\(> \?\)\+\)--\s$" end="^\z1$" end="^\z1\@!"me=s-1 end="^\z1\(> \?\)\+"me=s-1 fold

" Treat verbatim Text special.
syn region	mailVerbatim	contains=@NoSpell keepend start="^#v+$" end="^#v-$" fold 
syn region	mailVerbatim	contains=@mailQuoteExps,@NoSpell keepend start="^\z(\(> \?\)\+\)#v+$" end="\z1#v-$" fold 

" URLs start with a known protocol or www,web,w3.
syn match mailURL contains=@NoSpell `\v<(((https?|ftp|gopher)://|(mailto|file|news):)[^' 	<>"]+|(www|web|w3)[a-z0-9_-]*\.[a-z0-9._-]+\.[^' 	<>"]+)[a-z0-9/]`
syn match mailEmail contains=@NoSpell "\v[_=a-z\./+0-9-]+\@[a-z0-9._-]+\a{2}"

" Make sure quote markers in regions (header / signature) have correct color
syn match mailQuoteExp1	contained "\v^(\> ?)"
syn match mailQuoteExp2	contained "\v^(\> ?){2}"
syn match mailQuoteExp3	contained "\v^(\> ?){3}"
syn match mailQuoteExp4	contained "\v^(\> ?){4}"
syn match mailQuoteExp5	contained "\v^(\> ?){5}"
syn match mailQuoteExp6	contained "\v^(\> ?){6}"

" Even and odd quoted lines. Order is important here!
syn region	mailQuoted6	keepend contains=mailVerbatim,mailHeader,@mailLinks,mailSignature,@NoSpell start="^\z(\(\([a-z]\+>\|[]|}>]\)[ \t]*\)\{5}\([a-z]\+>\|[]|}>]\)\)" end="^\z1\@!" fold
syn region	mailQuoted5	keepend contains=mailQuoted6,mailVerbatim,mailHeader,@mailLinks,mailSignature,@NoSpell start="^\z(\(\([a-z]\+>\|[]|}>]\)[ \t]*\)\{4}\([a-z]\+>\|[]|}>]\)\)" end="^\z1\@!" fold
syn region	mailQuoted4	keepend contains=mailQuoted5,mailQuoted6,mailVerbatim,mailHeader,@mailLinks,mailSignature,@NoSpell start="^\z(\(\([a-z]\+>\|[]|}>]\)[ \t]*\)\{3}\([a-z]\+>\|[]|}>]\)\)" end="^\z1\@!" fold
syn region	mailQuoted3	keepend contains=mailQuoted4,mailQuoted5,mailQuoted6,mailVerbatim,mailHeader,@mailLinks,mailSignature,@NoSpell start="^\z(\(\([a-z]\+>\|[]|}>]\)[ \t]*\)\{2}\([a-z]\+>\|[]|}>]\)\)" end="^\z1\@!" fold
syn region	mailQuoted2	keepend contains=mailQuoted3,mailQuoted4,mailQuoted5,mailQuoted6,mailVerbatim,mailHeader,@mailLinks,mailSignature,@NoSpell start="^\z(\(\([a-z]\+>\|[]|}>]\)[ \t]*\)\{1}\([a-z]\+>\|[]|}>]\)\)" end="^\z1\@!" fold
syn region	mailQuoted1	keepend contains=mailQuoted2,mailQuoted3,mailQuoted4,mailQuoted5,mailQuoted6,mailVerbatim,mailHeader,@mailLinks,mailSignature,@NoSpell start="^\z([a-z]\+>\|[]|}>]\)" end="^\z1\@!" fold

" Need to sync on the header. Assume we can do that within 100 lines
if exists("mail_minlines")
    exec "syn sync minlines=" . mail_minlines
else
    syn sync minlines=100
endif

" Define the default highlighting.
hi def link mailVerbatim	Special
hi def link mailHeader		Statement
hi def link mailHeaderKey	Type
hi def link mailSignature	PreProc
hi def link mailHeaderEmail	mailEmail
hi def link mailEmail		Special
hi def link mailURL		String
hi def link mailSubject		Title
hi def link mailQuoted1		Comment
hi def link mailQuoted3		mailQuoted1
hi def link mailQuoted5		mailQuoted1
hi def link mailQuoted2		Identifier
hi def link mailQuoted4		mailQuoted2
hi def link mailQuoted6		mailQuoted2
hi def link mailQuoteExp1	mailQuoted1
hi def link mailQuoteExp2	mailQuoted2
hi def link mailQuoteExp3	mailQuoted3
hi def link mailQuoteExp4	mailQuoted4
hi def link mailQuoteExp5	mailQuoted5
hi def link mailQuoteExp6	mailQuoted6

let b:current_syntax = "mail"

let &cpo = s:cpo_save
unlet s:cpo_save
