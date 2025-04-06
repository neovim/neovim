" Vim syntax file
" Language: ChucK
" Maintainer: Andrea Callea
" URL: https://github.com/gacallea/chuck.vim
" Last Change: 2024 Jan 21 by Andrea Callea

" Sources used for this syntax
" https://chuck.cs.princeton.edu/doc/language/
" https://chuck.cs.princeton.edu/doc/reference/

" HISTORY:
" 2024 Jan 21 - Initial revision

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" https://chuck.cs.princeton.edu/doc/language/type.html
syn keyword chuckPrimitiveType int float time dur void vec3 vec4
syn keyword chuckComplexType complex polar
syn keyword chuckReferenceType Object Event UGen array string
syn keyword chuckBoolean true false maybe
syn keyword chuckBoolean null NULL

" https://chuck.cs.princeton.edu/doc/language/oper.html
syn match chuckOperator "=>"
syn match chuckOperator "@=>"

syn match chuckOperator "=^"

syn match chuckOperator "+"
syn match chuckOperator "-"
syn match chuckOperator "*"
syn match chuckOperator "/"
syn match chuckOperator "%"
syn match chuckOperator "!"
syn match chuckOperator "&"
syn match chuckOperator "|"
syn match chuckOperator "\^"

syn match chuckOperator "+=>"
syn match chuckOperator "-=>"
syn match chuckOperator "*=>"
syn match chuckOperator "/=>"
syn match chuckOperator "%=>"
syn match chuckOperator "!=>"
syn match chuckOperator "&=>"
syn match chuckOperator "|=>"
syn match chuckOperator "\^=>"

syn match chuckOperator "&&"
syn match chuckOperator "||"
syn match chuckOperator "=="
syn match chuckOperator "!="
syn match chuckOperator ">"
syn match chuckOperator ">="
syn match chuckOperator "<"
syn match chuckOperator "<="

syn match chuckOperator ">>"
syn match chuckOperator "<<"

syn match chuckOperator "++"
syn match chuckOperator "--"
syn match chuckOperator "<<<"
syn match chuckOperator ">>>"

syn keyword chuckOperator new

" https://chuck.cs.princeton.edu/doc/language/ctrl.html
syn keyword chuckConditional if else
syn keyword chuckRepeat while do until for each

" https://chuck.cs.princeton.edu/doc/language/time.html
syn keyword chuckTimeAndDuration samp ms second minute hour day week
syn keyword chuckTimeAndDuration now later

" these may need some additional keywords I missed, for a future revision
syn keyword chuckKeyword dac adc
syn keyword chuckKeyword fun function
syn keyword chuckKeyword return
syn keyword chuckKeyword const
syn match chuckKeyword "@"
syn keyword chuckKeyword pi
syn keyword chuckKeyword me
syn keyword chuckKeyword repeat break continue
syn keyword chuckKeyword class extends public private static pure this
syn keyword chuckKeyword spork
syn keyword chuckKeyword cherr chout

" https://chuck.cs.princeton.edu/doc/reference/
syn keyword chuckBaseClasses Shred Math Machine Std

" https://chuck.cs.princeton.edu/doc/reference/
syn keyword chuckBasicUGen Gain Impulse Step SndBuf SndBuf2
syn keyword chuckBasicUGen ADSR Envelope Delay DelayL DelayA Echo
syn keyword chuckBasicUGen Noise CNoise Osc SinOsc TriOsc SawOsc PulseOsc SqrOsc
syn keyword chuckBasicUGen Phasor HalfRect FullRect
syn keyword chuckBasicUGen Chugraph Chugen UGen_Multi UGen_Stereo Mix2 Pan2

" https://chuck.cs.princeton.edu/doc/reference/
syn keyword chuckFilterUGen FilterBasic LPF HPF BPF BRF BiQuad ResonZ
syn keyword chuckFilterUGen OnePole OneZero TwoPole TwoZero PoleZero

" https://chuck.cs.princeton.edu/doc/reference/
syn keyword chuckSTKUGen JCRev NRev PRCRev
syn keyword chuckSTKUGen Chorus Modulate PitShift SubNoise
syn keyword chuckSTKUGen BLT Blit BlitSaw BlitSquare FilterStk
syn keyword chuckSTKUGen WvIn WaveLoop WvOut WvOut2 StkInstrument
syn keyword chuckSTKUGen BandedWG BlowBotl BlowHole
syn keyword chuckSTKUGen Bowed Brass Clarinet Flute Mandolin
syn keyword chuckSTKUGen ModalBar Moog Saxofony Shakers Sitar StifKarp
syn keyword chuckSTKUGen VoicForm KrstlChr FM BeeThree FMVoices
syn keyword chuckSTKUGen HevyMetl HnkyTonk FrencHrn PercFlut Rhodey TubeBell Wurley

" https://chuck.cs.princeton.edu/doc/reference/
syn keyword chuckAdvancedUGen LiSa LiSa2 LiSa6 LiSa8 LiSa10
syn keyword chuckAdvancedUGen LiSa16 GenX Gen5 Gen7 Gen9 Gen10 Gen17
syn keyword chuckAdvancedUGen CurveTable WarpTable Dyno

" https://chuck.cs.princeton.edu/doc/reference/
syn keyword chuckChugin ABSaturator AmbPan3 Bitcrusher Elliptic ExpDelay ExpEnv FIR
syn keyword chuckChugin FoldbackSaturator GVerb KasFilter MagicSine Mesh2D
syn keyword chuckChugin Multicomb Pan4 Pan8 Pan16 PitchTrack PowerADSR RegEx
syn keyword chuckChugin Sigmund Spectacle WinFuncEnv WPDiodeLadder WPKorg35

" https://chuck.cs.princeton.edu/doc/reference/
syn keyword chuckUnitAnalyzer UAna UAnaBlob Windowing
syn keyword chuckUnitAnalyzer FFT IFFT DCT IDCT
syn keyword chuckUnitAnalyzer Centroid Flux RMS RollOff
syn keyword chuckUnitAnalyzer Flip UnFlip XCorr
syn keyword chuckUnitAnalyzer Chroma Kurtosis MFCC SFM ZeroX AutoCorr FeatureCollector

" https://chuck.cs.princeton.edu/doc/reference/
syn keyword chuckChAI MLP KNN KNN2 HMM SVM Word2Vec PCA Wekinator AI

" https://chuck.cs.princeton.edu/doc/reference/
syn keyword chuckInputOutput IO FileIO OscIn OscOut OscMsg
syn keyword chuckInputOutput Hid HidMsg KBHit SerialIO
syn keyword chuckInputOutput MidiIn MidiOut MidiMsg MidiFileIn

" https://chuck.cs.princeton.edu/doc/reference/
syn keyword chuckUtilities CKDoc StringTokenizer ConsoleInput

" https://github.com/wilsaj/chuck.vim/blob/master/syntax/chuck.vim
syn match chuckNumber /\%(\i\|\$\)\@<![-]\?\d\+/ display
syn match chuckHex /\<0[xX]\x\+[lL]\=\>/ display
syn match chuckFloat /\%(\i\|\$\)\@<![-]\?\%(\d*\.\d\+\|\d\+\.\)/ display

" this may need fixing/improvements
syn match chuckComment "//.*$"
syn region chuckComment start="/\*" end="\*/"
syn match chuckSpecialChar contained "\\n"
syn match chuckSpecialChar contained "\\t"
syn match chuckSpecialChar contained "\\a"
syn match chuckSpecialChar contained /\\"/
syn match chuckSpecialChar contained "\\0"
syn region chuckString start=/"/ end=/"/ display contains=chuckSpecialChar

hi def link chuckPrimitiveType Type
hi def link chuckComplexType Type
hi def link chuckReferenceType Type
hi def link chuckBoolean Boolean
hi def link chuckOperator Operator
hi def link chuckConditional Conditional
hi def link chuckRepeat Repeat
hi def link chuckTimeAndDuration Keyword
hi def link chuckKeyword Keyword
hi def link chuckBaseClasses Special
hi def link chuckBasicUGen Structure
hi def link chuckFilterUGen Structure
hi def link chuckSTKUGen Structure
hi def link chuckAdvancedUGen Structure
hi def link chuckChugin Structure
hi def link chuckUnitAnalyzer Structure
hi def link chuckChAI Structure
hi def link chuckInputOutput Special
hi def link chuckUtilities Special
hi def link chuckNumber Number
hi def link chuckHex Number
hi def link chuckFloat Float
hi def link chuckComment Comment
hi def link chuckSpecialChar SpecialChar
hi def link chuckString String

let b:current_syntax = "chuck"
