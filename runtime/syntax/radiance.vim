" Vim syntax file
" Language:     Radiance Scene Description
" Maintainer:   Georg Mischler <schorsch@schorsch.com>
" Last change:  26. April. 2001

" Radiance is a lighting simulation software package written
" by Gregory Ward-Larson ("the computer artist formerly known
" as Greg Ward"), then at LBNL.
"
" http://radsite.lbl.gov/radiance/HOME.html
"
" Of course, there is also information available about it
" from http://www.schorsch.com/


" We take a minimalist approach here, highlighting just the
" essential properties of each object, its type and ID, as well as
" comments, external command names and the null-modifier "void".


" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" all printing characters except '#' and '!' are valid in names.
setlocal iskeyword=\",$-~

" The null-modifier
syn keyword radianceKeyword void

" The different kinds of scene description object types
" Reference types
syn keyword radianceExtraType contained alias instance
" Surface types
syn keyword radianceSurfType contained ring polygon sphere bubble
syn keyword radianceSurfType contained cone cup cylinder tube source
" Emitting material types
syn keyword radianceLightType contained light glow illum spotlight
" Material types
syn keyword radianceMatType contained mirror mist prism1 prism2
syn keyword radianceMatType contained metal plastic trans
syn keyword radianceMatType contained metal2 plastic2 trans2
syn keyword radianceMatType contained metfunc plasfunc transfunc
syn keyword radianceMatType contained metdata plasdata transdata
syn keyword radianceMatType contained dielectric interface glass
syn keyword radianceMatType contained BRTDfunc antimatter
" Pattern modifier types
syn keyword radiancePatType contained colorfunc brightfunc
syn keyword radiancePatType contained colordata colorpict brightdata
syn keyword radiancePatType contained colortext brighttext
" Texture modifier types
syn keyword radianceTexType contained texfunc texdata
" Mixture types
syn keyword radianceMixType contained mixfunc mixdata mixpict mixtext


" Each type name is followed by an ID.
" This doesn't work correctly if the id is one of the type names of the
" same class (which is legal for radiance), in which case the id will get
" type color as well, and the int count (or alias reference) gets id color.

syn region radianceID start="\<alias\>"      end="\<\k*\>" contains=radianceExtraType
syn region radianceID start="\<instance\>"   end="\<\k*\>" contains=radianceExtraType

syn region radianceID start="\<source\>"     end="\<\k*\>" contains=radianceSurfType
syn region radianceID start="\<ring\>"	     end="\<\k*\>" contains=radianceSurfType
syn region radianceID start="\<polygon\>"    end="\<\k*\>" contains=radianceSurfType
syn region radianceID start="\<sphere\>"     end="\<\k*\>" contains=radianceSurfType
syn region radianceID start="\<bubble\>"     end="\<\k*\>" contains=radianceSurfType
syn region radianceID start="\<cone\>"	     end="\<\k*\>" contains=radianceSurfType
syn region radianceID start="\<cup\>"	     end="\<\k*\>" contains=radianceSurfType
syn region radianceID start="\<cylinder\>"   end="\<\k*\>" contains=radianceSurfType
syn region radianceID start="\<tube\>"	     end="\<\k*\>" contains=radianceSurfType

syn region radianceID start="\<light\>"      end="\<\k*\>" contains=radianceLightType
syn region radianceID start="\<glow\>"	     end="\<\k*\>" contains=radianceLightType
syn region radianceID start="\<illum\>"      end="\<\k*\>" contains=radianceLightType
syn region radianceID start="\<spotlight\>"  end="\<\k*\>" contains=radianceLightType

syn region radianceID start="\<mirror\>"     end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<mist\>"	     end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<prism1\>"     end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<prism2\>"     end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<metal\>"      end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<plastic\>"    end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<trans\>"      end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<metal2\>"     end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<plastic2\>"   end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<trans2\>"     end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<metfunc\>"    end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<plasfunc\>"   end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<transfunc\>"  end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<metdata\>"    end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<plasdata\>"   end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<transdata\>"  end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<dielectric\>" end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<interface\>"  end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<glass\>"      end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<BRTDfunc\>"   end="\<\k*\>" contains=radianceMatType
syn region radianceID start="\<antimatter\>" end="\<\k*\>" contains=radianceMatType

syn region radianceID start="\<colorfunc\>"  end="\<\k*\>" contains=radiancePatType
syn region radianceID start="\<brightfunc\>" end="\<\k*\>" contains=radiancePatType
syn region radianceID start="\<colordata\>"  end="\<\k*\>" contains=radiancePatType
syn region radianceID start="\<brightdata\>" end="\<\k*\>" contains=radiancePatType
syn region radianceID start="\<colorpict\>"  end="\<\k*\>" contains=radiancePatType
syn region radianceID start="\<colortext\>"  end="\<\k*\>" contains=radiancePatType
syn region radianceID start="\<brighttext\>" end="\<\k*\>" contains=radiancePatType

syn region radianceID start="\<texfunc\>"    end="\<\k*\>" contains=radianceTexType
syn region radianceID start="\<texdata\>"    end="\<\k*\>" contains=radianceTexType

syn region radianceID start="\<mixfunc\>"    end="\<\k*\>" contains=radianceMixType
syn region radianceID start="\<mixdata\>"    end="\<\k*\>" contains=radianceMixType
syn region radianceID start="\<mixtext\>"    end="\<\k*\>" contains=radianceMixType

" external commands (generators, xform et al.)
syn match radianceCommand "^\s*!\s*[^\s]\+\>"

" The usual suspects
syn keyword radianceTodo contained TODO XXX
syn match radianceComment "#.*$" contains=radianceTodo

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
hi def link radianceKeyword	Keyword
hi def link radianceExtraType	Type
hi def link radianceSurfType	Type
hi def link radianceLightType	Type
hi def link radianceMatType	Type
hi def link radiancePatType	Type
hi def link radianceTexType	Type
hi def link radianceMixType	Type
hi def link radianceComment	Comment
hi def link radianceCommand	Function
hi def link radianceID		String
hi def link radianceTodo		Todo

let b:current_syntax = "radiance"

" vim: ts=8 sw=2
