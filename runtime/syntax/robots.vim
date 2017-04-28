" Vim syntax file
" Language:	"Robots.txt" files
" Robots.txt files indicate to WWW robots which parts of a web site should not be accessed.
" Maintainer:	Dominique Stéphan (dominique@mggen.com)
" URL: http://www.mggen.com/vim/syntax/robots.zip
" Last change:	2001 May 09

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif


" shut case off
syn case ignore

" Comment
syn match  robotsComment	"#.*$" contains=robotsUrl,robotsMail,robotsString

" Star * (means all spiders)
syn match  robotsStar		"\*"

" :
syn match  robotsDelimiter	":"


" The keywords
" User-agent
syn match  robotsAgent		"^[Uu][Ss][Ee][Rr]\-[Aa][Gg][Ee][Nn][Tt]"
" Disallow
syn match  robotsDisallow	"^[Dd][Ii][Ss][Aa][Ll][Ll][Oo][Ww]"

" Disallow: or User-Agent: and the rest of the line before an eventual comment
synt match robotsLine		"\(^[Uu][Ss][Ee][Rr]\-[Aa][Gg][Ee][Nn][Tt]\|^[Dd][Ii][Ss][Aa][Ll][Ll][Oo][Ww]\):[^#]*"	contains=robotsAgent,robotsDisallow,robotsStar,robotsDelimiter

" Some frequent things in comments
syn match  robotsUrl		"http[s]\=://\S*"
syn match  robotsMail		"\S*@\S*"
syn region robotsString		start=+L\="+ skip=+\\\\\|\\"+ end=+"+

command -nargs=+ HiLink hi def link <args>

HiLink robotsComment		Comment
HiLink robotsAgent		Type
HiLink robotsDisallow		Statement
HiLink robotsLine		Special
HiLink robotsStar		Operator
HiLink robotsDelimiter	Delimiter
HiLink robotsUrl		String
HiLink robotsMail		String
HiLink robotsString		String

delcommand HiLink


let b:current_syntax = "robots"

" vim: ts=8 sw=2

