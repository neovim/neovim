" Vim syntax file
" Language:	PoE item filter
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	*.filter
" Last Change:	2023 Feb 10

if exists('b:current_syntax')
    finish
endif

let s:cpo_save = &cpoptions
set cpoptions&vim

" Comment
syn keyword poefilterTodo TODO NOTE XXX contained
syn match poefilterCommentTag /\[[0-9A-Z\[\]]\+\]/ contained
syn match poefilterComment /#.*$/ contains=poefilterTodo,poefilterCommentTag,@Spell

" Blocks
syn keyword poefilterBlock Show Hide Minimal

" Conditions
syn keyword poefilterCondition
            \ AlternateQuality
            \ AnyEnchantment
            \ BlightedMap
            \ Corrupted
            \ ElderItem
            \ ElderMap
            \ FracturedItem
            \ Identified
            \ Mirrored
            \ Replica
            \ Scourged
            \ ShapedMap
            \ ShaperItem
            \ SynthesisedItem
            \ UberBlightedMap
            \ skipwhite nextgroup=poefilterBoolean
syn keyword poefilterCondition
            \ ArchnemesisMod
            \ BaseType
            \ Class
            \ EnchantmentPassiveNode
            \ HasEnchantment
            \ HasExplicitMod
            \ ItemLevel
            \ SocketGroup
            \ Sockets
            \ skipwhite nextgroup=poefilterOperator,poefilterString
syn keyword poefilterCondition
            \ AreaLevel
            \ BaseArmour
            \ BaseDefencePercentile
            \ BaseEnergyShield
            \ BaseEvasion
            \ BaseWard
            \ CorruptedMods
            \ DropLevel
            \ EnchantmentPassiveNum
            \ GemLevel
            \ HasEaterOfWorldsImplicit
            \ HasSearingExarchImplicit
            \ Height
            \ LinkedSockets
            \ MapTier
            \ Quality
            \ StackSize
            \ Width
            \ skipwhite nextgroup=poefilterOperator,poefilterNumber
syn keyword poefilterCondition
            \ GemQualityType
            \ skipwhite nextgroup=poefilterString,poefilterQuality
syn keyword poefilterCondition
            \ HasInfluence
            \ skipwhite nextgroup=poefilterString,poefilterInfluence
syn keyword poefilterCondition
            \ Rarity
            \ skipwhite nextgroup=poefilterString,poefilterRarity

" Actions
syn keyword poefilterAction
            \ PlayAlertSound
            \ PlayAlertSoundPositional
            \ skipwhite nextgroup=poefilterNumber,poefilterDisable
syn keyword poefilterAction
            \ CustomAlertSound
            \ CustomAlertSoundOptional
            \ skipwhite nextgroup=poefilterString
syn keyword poefilterAction
            \ DisableDropSound
            \ EnableDropSound
            \ DisableDropSoundIfAlertSound
            \ EnableDropSoundIfAlertSound
            \ skipwhite nextgroup=poefilterBoolean
syn keyword poefilterAction
            \ MinimapIcon
            \ SetBackgroundColor
            \ SetBorderColor
            \ SetFontSize
            \ SetTextColor
            \ skipwhite nextgroup=poefilterNumber
syn keyword poefilterAction
            \ PlayEffect
            \ skipwhite nextgroup=poefilterColour

" Operators
syn match poefilterOperator /!\|[<>=]=\?/ contained
            \ skipwhite nextgroup=poefilterString,poefilterNumber,
            \ poefilterQuality,poefilterRarity,poefilterInfluence

" Arguments
syn match poefilterString /[-a-zA-Z0-9:,']/ contained contains=@Spell
            \ skipwhite nextgroup=poefilterString,poefilterNumber,
            \ poefilterQuality,poefilterRarity,poefilterInfluence
syn region poefilterString matchgroup=poefilterQuote keepend
            \ start=/"/ end=/"/ concealends contained contains=@Spell
            \ skipwhite nextgroup=poefilterString,poefilterNumber,
            \ poefilterQuality,poefilterRarity,poefilterInfluence
syn match poefilterNumber /-1\|0\|[1-9][0-9]*/ contained
            \ skipwhite nextgroup=poefilterString,poefilterNumber,
            \ poefilterQuality,poefilterRarity,poefilterInfluence,poefilterColour
syn keyword poefilterBoolean True False contained

" Special arguments (conditions)
syn keyword poefilterQuality Superior Divergent Anomalous Phantasmal
            \ contained skipwhite nextgroup=poefilterString,poefilterQuality
syn keyword poefilterRarity Normal Magic Rare Unique
            \ contained skipwhite nextgroup=poefilterString,poefilterRarity
syn keyword poefilterInfluence Shaper Elder
            \ Crusader Hunter Redeemer Warlord None
            \ contained skipwhite nextgroup=poefilterString,poefilterInfluence

" Special arguments (actions)
syn keyword poefilterColour Red Green Blue Brown
            \ White Yellow Cyan Grey Orange Pink Purple
            \ contained skipwhite nextgroup=poefilterShape,poefilterTemp
syn keyword poefilterShape Circle Diamond Hecagon Square Star Triangle
            \ Cross Moon Raindrop Kite Pentagon UpsideDownHouse contained
syn keyword poefilterDisable None contained
syn keyword poefilterTemp Temp contained

" Colours

hi def link poefilterAction Statement
hi def link poefilterBlock Structure
hi def link poefilterBoolean Boolean
hi def link poefilterColour Special
hi def link poefilterComment Comment
hi def link poefilterCommentTag SpecialComment
hi def link poefilterCondition Conditional
hi def link poefilterDisable Constant
hi def link poefilterInfluence Special
hi def link poefilterNumber Number
hi def link poefilterOperator Operator
hi def link poefilterQuality Special
hi def link poefilterQuote Delimiter
hi def link poefilterRarity Special
hi def link poefilterShape Special
hi def link poefilterString String
hi def link poefilterTemp StorageClass
hi def link poefilterTodo Todo

let b:current_syntax = 'poefilter'

let &cpoptions = s:cpo_save
unlet s:cpo_save
