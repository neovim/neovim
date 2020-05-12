" Vim syntax file
" Language:     Objective-C
" Maintainer:   Kazunobu Kuriyama <kazunobu.kuriyama@gmail.com>
" Last Change:  2015 Dec 14

""" Preparation for loading ObjC stuff
if exists("b:current_syntax")
  finish
endif
if &filetype != 'objcpp'
  syn clear
  runtime! syntax/c.vim
endif
let s:cpo_save = &cpo
set cpo&vim

""" ObjC proper stuff follows...

syn keyword objcPreProcMacro __OBJC__ __OBJC2__ __clang__

" Defined Types
syn keyword objcPrincipalType id Class SEL IMP BOOL instancetype
syn keyword objcUsefulTerm nil Nil NO YES

" Preprocessor Directives
syn region objcImported display contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match objcImported display contained "\(<\h[-a-zA-Z0-9_/]*\.h>\|<[a-z0-9]\+>\)"
syn match objcImport display "^\s*\(%:\|#\)\s*import\>\s*["<]" contains=objcImported

" ObjC Compiler Directives
syn match objcObjDef display /@interface\>\|@implementation\>\|@end\>\|@class\>/
syn match objcProtocol display /@protocol\>\|@optional\>\|@required\>/
syn match objcProperty display /@property\>\|@synthesize\>\|@dynamic\>/
syn match objcIvarScope display /@private\>\|@protected\>\|@public\>\|@package\>/
syn match objcInternalRep display /@selector\>\|@encode\>/
syn match objcException display /@try\>\|@throw\>\|@catch\|@finally\>/
syn match objcThread display /@synchronized\>/
syn match objcPool display /@autoreleasepool\>/
syn match objcModuleImport display /@import\>/

" ObjC Constant Strings
syn match objcSpecial display contained "%@"
syn region objcString start=+\(@"\|"\)+ skip=+\\\\\|\\"+ end=+"+ contains=cFormat,cSpecial,objcSpecial

" ObjC Hidden Arguments
syn keyword objcHiddenArgument self _cmd super

" ObjC Type Qualifiers for Blocks
syn keyword objcBlocksQualifier __block
" ObjC Type Qualifiers for Object Lifetime
syn keyword objcObjectLifetimeQualifier __strong __weak __unsafe_unretained __autoreleasing
" ObjC Type Qualifiers for Toll-Free Bridge
syn keyword objcTollFreeBridgeQualifier __bridge __bridge_retained __bridge_transfer

" ObjC Type Qualifiers for Remote Messaging
syn match objcRemoteMessagingQualifier display contained /\((\s*oneway\s\+\|(\s*in\s\+\|(\s*out\s\+\|(\s*inout\s\+\|(\s*bycopy\s\+\(in\(out\)\?\|out\)\?\|(\s*byref\s\+\(in\(out\)\?\|out\)\?\)/hs=s+1

" ObjC Storage Classes
syn keyword objcStorageClass _Nullable _Nonnull _Null_unspecified
syn keyword objcStorageClass __nullable __nonnull __null_unspecified
syn keyword objcStorageClass nullable nonnull null_unspecified

" ObjC type specifier
syn keyword objcTypeSpecifier __kindof __covariant

" ObjC Type Infomation Parameters
syn keyword objcTypeInfoParams ObjectType KeyType

" shorthand
syn cluster objcTypeQualifier contains=objcBlocksQualifier,objcObjectLifetimeQualifier,objcTollFreeBridgeQualifier,objcRemoteMessagingQualifier

" ObjC Fast Enumeration
syn match objcFastEnumKeyword display /\sin\(\s\|$\)/

" ObjC Literal Syntax
syn match objcLiteralSyntaxNumber display /@\(YES\>\|NO\>\|\d\|-\|+\)/ contains=cNumber,cFloat,cOctal
syn match objcLiteralSyntaxSpecialChar display /@'/ contains=cSpecialCharacter
syn match objcLiteralSyntaxChar display /@'[^\\]'/ 
syn match objcLiteralSyntaxOp display /@\((\|\[\|{\)/me=e-1,he=e-1

" ObjC Declared Property Attributes
syn match objDeclPropAccessorNameAssign display /\s*=\s*/ contained
syn region objcDeclPropAccessorName display start=/\(getter\|setter\)/ end=/\h\w*/ contains=objDeclPropAccessorNameAssign
syn keyword objcDeclPropAccessorType readonly readwrite contained
syn keyword objcDeclPropAssignSemantics assign retain copy contained
syn keyword objcDeclPropAtomicity nonatomic contained
syn keyword objcDeclPropARC strong weak contained
syn match objcDeclPropNullable /\((\|\s\)nullable\(,\|)\)/ms=s+1,hs=s+1,me=e-1,he=e-1 contained
syn match objcDeclPropNonnull /\((\|\s\)nonnull\(,\|)\)/ms=s+1,hs=s+1,me=e-1,he=e-1 contained
syn match objcDeclPropNullUnspecified /\((\|\s\)null_unspecified\(,\|)\)/ms=s+1,hs=s+1,me=e-1,he=e-1 contained
syn keyword objcDeclProcNullResettable null_resettable contained
syn region objcDeclProp display transparent keepend start=/@property\s*(/ end=/)/ contains=objcProperty,objcDeclPropAccessorName,objcDeclPropAccessorType,objcDeclPropAssignSemantics,objcDeclPropAtomicity,objcDeclPropARC,objcDeclPropNullable,objcDeclPropNonnull,objcDeclPropNullUnspecified,objcDeclProcNullResettable

" To distinguish colons in methods and dictionaries from those in C's labels.
syn match objcColon display /^\s*\h\w*\s*\:\(\s\|.\)/me=e-1,he=e-1

" To distinguish a protocol list from system header files
syn match objcProtocolList display /<\h\w*\(\s*,\s*\h\w*\)*>/ contains=objcPrincipalType,cType,Type,objcType,objcTypeInfoParams

" Type info for collection classes
syn match objcTypeInfo display /<\h\w*\s*<\(\h\w*\s*\**\|\h\w*\)>>/ contains=objcPrincipalType,cType,Type,objcType,objcTypeInfoParams

" shorthand
syn cluster objcCEntities contains=cType,cStructure,cStorageClass,cString,cCharacter,cSpecialCharacter,cNumbers,cConstant,cOperator,cComment,cCommentL,cStatement,cLabel,cConditional,cRepeat
syn cluster objcObjCEntities contains=objcHiddenArgument,objcPrincipalType,objcString,objcUsefulTerm,objcProtocol,objcInternalRep,objcException,objcThread,objcPool,objcModuleImport,@objcTypeQualifier,objcLiteralSyntaxNumber,objcLiteralSyntaxOp,objcLiteralSyntaxChar,objcLiteralSyntaxSpecialChar,objcProtocolList,objcColon,objcFastEnumKeyword,objcType,objcClass,objcMacro,objcEnum,objcEnumValue,objcExceptionValue,objcNotificationValue,objcConstVar,objcPreProcMacro,objcTypeInfo

" Objective-C Message Expressions
syn region objcMethodCall start=/\[/ end=/\]/ contains=objcMethodCall,objcBlocks,@objcObjCEntities,@objcCEntities

" To distinguish class method and instance method
syn match objcInstanceMethod display /^s*-\s*/
syn match objcClassMethod display /^s*+\s*/

" ObjC Blocks
syn region objcBlocks start=/\(\^\s*([^)]\+)\s*{\|\^\s*{\)/ end=/}/ contains=objcBlocks,objcMethodCall,@objcObjCEntities,@objcCEntities

syn cluster cParenGroup add=objcMethodCall
syn cluster cPreProcGroup add=objcMethodCall

""" Foundation Framework
syn match objcClass /Protocol\s*\*/me=s+8,he=s+8

"""""""""""""""""
" NSObjCRuntime.h
syn keyword objcType NSInteger NSUInteger NSComparator
syn keyword objcEnum NSComparisonResult
syn keyword objcEnumValue NSOrderedAscending NSOrderedSame NSOrderedDescending
syn keyword objcEnum NSEnumerationOptions
syn keyword objcEnumValue NSEnumerationConcurrent NSEnumerationReverse
syn keyword objcEnum NSSortOptions
syn keyword objcEnumValue NSSortConcurrent NSSortStable
syn keyword objcEnumValue NSNotFound
syn keyword objcMacro NSIntegerMax NSIntegerMin NSUIntegerMax
syn keyword objcMacro NS_INLINE NS_BLOCKS_AVAILABLE NS_NONATOMIC_IOSONLY NS_FORMAT_FUNCTION NS_FORMAT_ARGUMENT NS_RETURNS_RETAINED NS_RETURNS_NOT_RETAINED NS_RETURNS_INNER_POINTER NS_AUTOMATED_REFCOUNT_UNAVAILABLE NS_AUTOMATED_REFCOUNT_WEAK_UNAVAILABLE NS_REQUIRES_PROPERTY_DEFINITIONS NS_REPLACES_RECEIVER NS_RELEASES_ARGUMENT NS_VALID_UNTIL_END_OF_SCOPE NS_ROOT_CLASS NS_REQUIRES_SUPER NS_PROTOCOL_REQUIRES_EXPLICIT_IMPLEMENTATION NS_DESIGNATED_INITIALIZER NS_REQUIRES_NIL_TERMINATION
syn keyword objcEnum NSQualityOfService
syn keyword objcEnumValue NSQualityOfServiceUserInteractive NSQualityOfServiceUserInitiated NSQualityOfServiceUtility NSQualityOfServiceBackground NSQualityOfServiceDefault
" NSRange.h
syn keyword objcType NSRange NSRangePointer
" NSGeometry.h
syn keyword objcType NSPoint NSPointPointer NSPointArray NSSize NSSizePointer NSSizeArray NSRect NSRectPointer NSRectArray NSEdgeInsets
syn keyword objcEnum NSRectEdge
syn keyword objcEnumValue NSMinXEdge NSMinYEdge NSMaxXEdge NSMaxYEdge
syn keyword objcEnumValue NSRectEdgeMinX NSRectEdgeMinY NSRectEdgeMaxX NSRectEdgeMaxY
syn keyword objcConstVar NSZeroPoint NSZeroSize NSZeroRect NSEdgeInsetsZero
syn keyword cType CGFloat CGPoint CGSize CGRect
syn keyword objcEnum NSAlignmentOptions
syn keyword objcEnumValue NSAlignMinXInward NSAlignMinYInward NSAlignMaxXInward NSAlignMaxYInward NSAlignWidthInward NSAlignHeightInward NSAlignMinXOutward NSAlignMinYOutward NSAlignMaxXOutward NSAlignMaxYOutward NSAlignWidthOutward NSAlignHeightOutward NSAlignMinXNearest NSAlignMinYNearest NSAlignMaxXNearest NSAlignMaxYNearest NSAlignWidthNearest NSAlignHeightNearest NSAlignRectFlipped NSAlignAllEdgesInward NSAlignAllEdgesOutward NSAlignAllEdgesNearest
" NSDecimal.h
syn keyword objcType NSDecimal
syn keyword objcEnum  NSRoundingMode
syn keyword objcEnumValue NSRoundPlain NSRoundDown NSRoundUp NSRoundBankers
syn keyword objcEnum NSCalculationError
syn keyword objcEnumValue NSCalculationNoError NSCalculationLossOfPrecision NSCalculationUnderflow NSCalculationOverflow NSCalculationDivideByZero
syn keyword objcConstVar NSDecimalMaxSize NSDecimalNoScale
" NSDate.h
syn match objcClass /NSDate\s*\*/me=s+6,he=s+6
syn keyword objcType NSTimeInterval
syn keyword objcNotificationValue NSSystemClockDidChangeNotification
syn keyword objcMacro NSTimeIntervalSince1970
" NSZone.h
syn match objcType /NSZone\s*\*/me=s+6,he=s+6
syn keyword objcEnumValue NSScannedOption NSCollectorDisabledOption
" NSError.h
syn match objcClass /NSError\s*\*/me=s+7,he=s+7
syn keyword objcConstVar NSCocoaErrorDomain NSPOSIXErrorDomain NSOSStatusErrorDomain NSMachErrorDomain NSUnderlyingErrorKey NSLocalizedDescriptionKey NSLocalizedFailureReasonErrorKey NSLocalizedRecoverySuggestionErrorKey NSLocalizedRecoveryOptionsErrorKey NSRecoveryAttempterErrorKey NSHelpAnchorErrorKey NSStringEncodingErrorKey NSURLErrorKey NSFilePathErrorKey
" NSException.h
syn match objcClass /NSException\s*\*/me=s+11,he=s+11
syn match objcClass /NSAssertionHandler\s*\*/me=s+18,he=s+18
syn keyword objcType NSUncaughtExceptionHandler
syn keyword objcConstVar NSGenericException NSRangeException NSInvalidArgumentException NSInternalInconsistencyException NSMallocException NSObjectInaccessibleException NSObjectNotAvailableException NSDestinationInvalidException NSPortTimeoutException NSInvalidSendPortException NSInvalidReceivePortException NSPortSendException NSPortReceiveException NSOldStyleException
" NSNotification.h
syn match objcClass /NSNotification\s*\*/me=s+14,he=s+14
syn match objcClass /NSNotificationCenter\s*\*/me=s+20,he=s+20
" NSDistributedNotificationCenter.h
syn match objcClass /NSDistributedNotificationCenter\s*\*/me=s+31,he=s+31
syn keyword objcConstVar NSLocalNotificationCenterType
syn keyword objcEnum NSNotificationSuspensionBehavior
syn keyword objcEnumValue NSNotificationSuspensionBehaviorDrop NSNotificationSuspensionBehaviorCoalesce NSNotificationSuspensionBehaviorHold NSNotificationSuspensionBehaviorHold NSNotificationSuspensionBehaviorDeliverImmediately
syn keyword objcEnumValue NSNotificationDeliverImmediately NSNotificationPostToAllSessions
syn keyword objcEnum NSDistributedNotificationOptions
syn keyword objcEnumValue NSDistributedNotificationDeliverImmediately NSDistributedNotificationPostToAllSessions
" NSNotificationQueue.h
syn match objcClass /NSNotificationQueue\s*\*/me=s+19,he=s+19
syn keyword objcEnum NSPostingStyle
syn keyword objcEnumValue NSPostWhenIdle NSPostASAP NSPostNow
syn keyword objcEnum NSNotificationCoalescing
syn keyword objcEnumValue NSNotificationNoCoalescing NSNotificationCoalescingOnName NSNotificationCoalescingOnSender
" NSEnumerator.h
syn match objcClass /NSEnumerator\s*\*/me=s+12,he=s+12
syn match objcClass /NSEnumerator<.*>\s*\*/me=s+12,he=s+12 contains=objcTypeInfoParams
syn keyword objcType NSFastEnumerationState
" NSIndexSet.h
syn match objcClass /NSIndexSet\s*\*/me=s+10,he=s+10
syn match objcClass /NSMutableIndexSet\s*\*/me=s+17,he=s+17
" NSCharecterSet.h
syn match objcClass /NSCharacterSet\s*\*/me=s+14,he=s+14
syn match objcClass /NSMutableCharacterSet\s*\*/me=s+21,he=s+21
syn keyword objcConstVar NSOpenStepUnicodeReservedBase
" NSURL.h
syn match objcClass /NSURL\s*\*/me=s+5,he=s+5
syn keyword objcEnum NSURLBookmarkCreationOptions
syn keyword objcEnumValue NSURLBookmarkCreationPreferFileIDResolution NSURLBookmarkCreationMinimalBookmark NSURLBookmarkCreationSuitableForBookmarkFile NSURLBookmarkCreationWithSecurityScope NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
syn keyword objcEnum NSURLBookmarkResolutionOptions
syn keyword objcEnumValue NSURLBookmarkResolutionWithoutUI NSURLBookmarkResolutionWithoutMounting NSURLBookmarkResolutionWithSecurityScope
syn keyword objcType NSURLBookmarkFileCreationOptions
syn keyword objcConstVar NSURLFileScheme NSURLKeysOfUnsetValuesKey
syn keyword objcConstVar NSURLNameKey NSURLLocalizedNameKey NSURLIsRegularFileKey NSURLIsDirectoryKey NSURLIsSymbolicLinkKey NSURLIsVolumeKey NSURLIsPackageKey NSURLIsApplicationKey NSURLApplicationIsScriptableKey NSURLIsSystemImmutableKey NSURLIsUserImmutableKey NSURLIsHiddenKey NSURLHasHiddenExtensionKey NSURLCreationDateKey NSURLContentAccessDateKey NSURLContentModificationDateKey NSURLAttributeModificationDateKey NSURLLinkCountKey NSURLParentDirectoryURLKey NSURLVolumeURLKey NSURLTypeIdentifierKey NSURLLocalizedTypeDescriptionKey NSURLLabelNumberKey NSURLLabelColorKey NSURLLocalizedLabelKey NSURLEffectiveIconKey NSURLCustomIconKey NSURLFileResourceIdentifierKey NSURLVolumeIdentifierKey NSURLPreferredIOBlockSizeKey NSURLIsReadableKey NSURLIsWritableKey NSURLIsExecutableKey NSURLFileSecurityKey NSURLIsExcludedFromBackupKey NSURLTagNamesKey NSURLPathKey NSURLIsMountTriggerKey NSURLGenerationIdentifierKey NSURLDocumentIdentifierKey NSURLAddedToDirectoryDateKey NSURLQuarantinePropertiesKey NSURLFileResourceTypeKey
syn keyword objcConstVar NSURLFileResourceTypeNamedPipe NSURLFileResourceTypeCharacterSpecial NSURLFileResourceTypeDirectory NSURLFileResourceTypeBlockSpecial NSURLFileResourceTypeRegular NSURLFileResourceTypeSymbolicLink NSURLFileResourceTypeSocket NSURLFileResourceTypeUnknown NSURLThumbnailDictionaryKey NSURLThumbnailKey NSThumbnail1024x1024SizeKey
syn keyword objcConstVar NSURLFileSizeKey NSURLFileAllocatedSizeKey NSURLTotalFileSizeKey NSURLTotalFileAllocatedSizeKey NSURLIsAliasFileKey NSURLFileProtectionKey NSURLFileProtectionNone NSURLFileProtectionComplete NSURLFileProtectionCompleteUnlessOpen NSURLFileProtectionCompleteUntilFirstUserAuthentication
syn keyword objcConstVar NSURLVolumeLocalizedFormatDescriptionKey NSURLVolumeTotalCapacityKey NSURLVolumeAvailableCapacityKey NSURLVolumeResourceCountKey NSURLVolumeSupportsPersistentIDsKey NSURLVolumeSupportsSymbolicLinksKey NSURLVolumeSupportsHardLinksKey NSURLVolumeSupportsJournalingKey NSURLVolumeIsJournalingKey NSURLVolumeSupportsSparseFilesKey NSURLVolumeSupportsZeroRunsKey NSURLVolumeSupportsCaseSensitiveNamesKey NSURLVolumeSupportsCasePreservedNamesKey NSURLVolumeSupportsRootDirectoryDatesKey NSURLVolumeSupportsVolumeSizesKey NSURLVolumeSupportsRenamingKey NSURLVolumeSupportsAdvisoryFileLockingKey NSURLVolumeSupportsExtendedSecurityKey NSURLVolumeIsBrowsableKey NSURLVolumeMaximumFileSizeKey NSURLVolumeIsEjectableKey NSURLVolumeIsRemovableKey NSURLVolumeIsInternalKey NSURLVolumeIsAutomountedKey NSURLVolumeIsLocalKey NSURLVolumeIsReadOnlyKey NSURLVolumeCreationDateKey NSURLVolumeURLForRemountingKey NSURLVolumeUUIDStringKey NSURLVolumeNameKey NSURLVolumeLocalizedNameKey
syn keyword objcConstVar NSURLIsUbiquitousItemKey NSURLUbiquitousItemHasUnresolvedConflictsKey NSURLUbiquitousItemIsDownloadedKey NSURLUbiquitousItemIsDownloadingKey NSURLUbiquitousItemIsUploadedKey NSURLUbiquitousItemIsUploadingKey NSURLUbiquitousItemPercentDownloadedKey NSURLUbiquitousItemPercentUploadedKey NSURLUbiquitousItemDownloadingStatusKey NSURLUbiquitousItemDownloadingErrorKey NSURLUbiquitousItemUploadingErrorKey NSURLUbiquitousItemDownloadRequestedKey NSURLUbiquitousItemContainerDisplayNameKey NSURLUbiquitousItemDownloadingStatusNotDownloaded NSURLUbiquitousItemDownloadingStatusDownloaded NSURLUbiquitousItemDownloadingStatusCurrent
""""""""""""
" NSString.h
syn match objcClass /NSString\s*\*/me=s+8,he=s+8
syn match objcClass /NSMutableString\s*\*/me=s+15,he=s+15
syn keyword objcType unichar
syn keyword objcExceptionValue NSParseErrorException NSCharacterConversionException
syn keyword objcMacro NSMaximumStringLength
syn keyword objcEnum NSStringCompareOptions
syn keyword objcEnumValue NSCaseInsensitiveSearch NSLiteralSearch NSBackwardsSearch NSAnchoredSearch NSNumericSearch NSDiacriticInsensitiveSearch NSWidthInsensitiveSearch NSForcedOrderingSearch NSRegularExpressionSearch 
syn keyword objcEnum NSStringEncoding
syn keyword objcEnumValue NSProprietaryStringEncoding
syn keyword objcEnumValue NSASCIIStringEncoding NSNEXTSTEPStringEncoding NSJapaneseEUCStringEncoding NSUTF8StringEncoding NSISOLatin1StringEncoding NSSymbolStringEncoding NSNonLossyASCIIStringEncoding NSShiftJISStringEncoding NSISOLatin2StringEncoding NSUnicodeStringEncoding NSWindowsCP1251StringEncoding NSWindowsCP1252StringEncoding NSWindowsCP1253StringEncoding NSWindowsCP1254StringEncoding NSWindowsCP1250StringEncoding NSISO2022JPStringEncoding NSMacOSRomanStringEncoding NSUTF16StringEncoding NSUTF16BigEndianStringEncoding NSUTF16LittleEndianStringEncoding NSUTF32StringEncoding NSUTF32BigEndianStringEncoding NSUTF32LittleEndianStringEncoding
syn keyword objcEnum NSStringEncodingConversionOptions
syn keyword objcEnumValue NSStringEncodingConversionAllowLossy NSStringEncodingConversionExternalRepresentation
syn keyword objcEnum NSStringEnumerationOptions
syn keyword objcEnumValue NSStringEnumerationByLines NSStringEnumerationByParagraphs NSStringEnumerationByComposedCharacterSequences NSStringEnumerationByWords NSStringEnumerationBySentences NSStringEnumerationReverse NSStringEnumerationSubstringNotRequired NSStringEnumerationLocalized
syn keyword objcConstVar NSStringTransformLatinToKatakana NSStringTransformLatinToHiragana NSStringTransformLatinToHangul NSStringTransformLatinToArabic NSStringTransformLatinToHebrew NSStringTransformLatinToThai NSStringTransformLatinToCyrillic NSStringTransformLatinToGreek NSStringTransformToLatin NSStringTransformMandarinToLatin NSStringTransformHiraganaToKatakana NSStringTransformFullwidthToHalfwidth NSStringTransformToXMLHex NSStringTransformToUnicodeName NSStringTransformStripCombiningMarks NSStringTransformStripDiacritics
syn keyword objcConstVar NSStringEncodingDetectionSuggestedEncodingsKey NSStringEncodingDetectionDisallowedEncodingsKey NSStringEncodingDetectionUseOnlySuggestedEncodingsKey NSStringEncodingDetectionAllowLossyKey NSStringEncodingDetectionFromWindowsKey NSStringEncodingDetectionLossySubstitutionKey NSStringEncodingDetectionLikelyLanguageKey
" NSAttributedString.h
syn match objcClass /NSAttributedString\s*\*/me=s+18,he=s+18
syn match objcClass /NSMutableAttributedString\s*\*/me=s+25,he=s+25
syn keyword objcEnum NSAttributedStringEnumerationOptions
syn keyword objcEnumValue NSAttributedStringEnumerationReverse NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
" NSValue.h
syn match objcClass /NSValue\s*\*/me=s+7,he=s+7
syn match objcClass /NSNumber\s*\*/me=s+8,he=s+8
" NSDecimalNumber.h
syn match objcClass /NSDecimalNumber\s*\*/me=s+15,he=s+15
syn match objcClass /NSDecimalNumberHandler\s*\*/me=s+22,he=s+22
syn keyword objcExceptionValue NSDecimalNumberExactnessException NSDecimalNumberOverflowException NSDecimalNumberUnderflowException NSDecimalNumberDivideByZeroException
" NSData.h
syn match objcClass /NSData\s*\*/me=s+6,he=s+6
syn match objcClass /NSMutableData\s*\*/me=s+13,he=s+13
syn keyword objcEnum NSDataReadingOptions
syn keyword objcEnumValue NSDataReadingMappedIfSafe NSDataReadingUncached NSDataReadingMappedAlways NSDataReadingMapped NSMappedRead NSUncachedRead
syn keyword objcEnum NSDataWritingOptions
syn keyword objcEnumValue NSDataWritingAtomic NSDataWritingWithoutOverwriting NSDataWritingFileProtectionNone NSDataWritingFileProtectionComplete NSDataWritingFileProtectionCompleteUnlessOpen NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication NSDataWritingFileProtectionMask NSAtomicWrite
syn keyword objcEnum NSDataSearchOptions
syn keyword objcEnumValue NSDataSearchBackwards NSDataSearchAnchored
syn keyword objcEnum NSDataBase64EncodingOptions NSDataBase64DecodingOptions
syn keyword objcEnumValue NSDataBase64Encoding64CharacterLineLength  NSDataBase64Encoding76CharacterLineLength NSDataBase64EncodingEndLineWithCarriageReturn NSDataBase64EncodingEndLineWithLineFeed NSDataBase64DecodingIgnoreUnknownCharacters
" NSArray.h
syn match objcClass /NSArray\s*\*/me=s+7,he=s+7
syn match objcClass /NSArray<.*>\s*\*/me=s+7,he=s+7 contains=objcTypeInfoParams
syn match objcClass /NSMutableArray\s*\*/me=s+14,he=s+14
syn match objcClass /NSMutableArray<.*>\s*\*/me=s+14,he=s+14 contains=objcTypeInfoParams
syn keyword objcEnum NSBinarySearchingOptions
syn keyword objcEnumValue NSBinarySearchingFirstEqual NSBinarySearchingLastEqual NSBinarySearchingInsertionIndex
" NSDictionary.h
syn match objcClass /NSDictionary\s*\*/me=s+12,he=s+12
syn match objcClass /NSDictionary<.*>\s*\*/me=s+12,he=s+12 contains=objcTypeInfoParams
syn match objcClass /NSMutableDictionary\s*\*/me=s+19,he=s+19
syn match objcClass /NSMutableDictionary<.*>\s*\*/me=s+19,he=s+19 contains=objcTypeInfoParams
" NSSet.h
syn match objcClass /NSSet\s*\*/me=s+5,me=s+5
syn match objcClass /NSSet<.*>\s*\*/me=s+5,me=s+5 contains=objcTypeInfoParams
syn match objcClass /NSMutableSet\s*\*/me=s+12,me=s+12
syn match objcClass /NSMutableSet<.*>\s*\*/me=s+12,me=s+12 contains=objcTypeInfoParams
syn match objcClass /NSCountedSet\s*\*/me=s+12,me=s+12
syn match objcClass /NSCountedSet<.*>\s*\*/me=s+12,me=s+12 contains=objcTypeInfoParams
" NSOrderedSet.h
syn match objcClass /NSOrderedSet\s*\*/me=s+12,me=s+12
syn match objcClass /NSOrderedSet<.*>\s*\*/me=s+12,me=s+12 contains=objcTypeInfoParams
syn match objcClass /NSMutableOrderedSet\s*\*/me=s+19,me=s+19
syn match objcClass /NSMutableOrderedSet<.*>\s*\*/me=s+19,me=s+19
"""""""""""""""""""
" NSPathUtilities.h
syn keyword objcEnum NSSearchPathDirectory
syn keyword objcEnumValue NSApplicationDirectory NSDemoApplicationDirectory NSDeveloperApplicationDirectory NSAdminApplicationDirectory NSLibraryDirectory NSDeveloperDirectory NSUserDirectory NSDocumentationDirectory NSDocumentDirectory NSCoreServiceDirectory NSAutosavedInformationDirectory NSDesktopDirectory NSCachesDirectory NSApplicationSupportDirectory NSDownloadsDirectory NSInputMethodsDirectory NSMoviesDirectory NSMusicDirectory NSPicturesDirectory NSPrinterDescriptionDirectory NSSharedPublicDirectory NSPreferencePanesDirectory NSApplicationScriptsDirectory NSItemReplacementDirectory NSAllApplicationsDirectory NSAllLibrariesDirectory NSTrashDirectory
syn keyword objcEnum NSSearchPathDomainMask
syn keyword objcEnumValue NSUserDomainMask NSLocalDomainMask NSNetworkDomainMask NSSystemDomainMask NSAllDomainsMask
" NSFileManger.h
syn match objcClass /NSFileManager\s*\*/me=s+13,he=s+13
syn match objcClass /NSDirectoryEnumerator\s*\*/me=s+21,he=s+21 contains=objcTypeInfoParams
syn match objcClass /NSDirectoryEnumerator<.*>\s*\*/me=s+21,he=s+21
syn keyword objcEnum NSVolumeEnumerationOptions
syn keyword objcEnumValue NSVolumeEnumerationSkipHiddenVolumes NSVolumeEnumerationProduceFileReferenceURLs 
syn keyword objcEnum NSURLRelationship
syn keyword objcEnumValue NSURLRelationshipContains NSURLRelationshipSame NSURLRelationshipOther
syn keyword objcEnum NSFileManagerUnmountOptions
syn keyword objcEnumValue NSFileManagerUnmountAllPartitionsAndEjectDisk NSFileManagerUnmountWithoutUI
syn keyword objcConstVar NSFileManagerUnmountDissentingProcessIdentifierErrorKey
syn keyword objcEnum NSDirectoryEnumerationOptions
syn keyword objcEnumValue NSDirectoryEnumerationSkipsSubdirectoryDescendants NSDirectoryEnumerationSkipsPackageDescendants NSDirectoryEnumerationSkipsHiddenFiles 
syn keyword objcEnum NSFileManagerItemReplacementOptions
syn keyword objcEnumValue NSFileManagerItemReplacementUsingNewMetadataOnly NSFileManagerItemReplacementWithoutDeletingBackupItem
syn keyword objcNotificationValue NSUbiquityIdentityDidChangeNotification
syn keyword objcConstVar NSFileType NSFileTypeDirectory NSFileTypeRegular NSFileTypeSymbolicLink NSFileTypeSocket NSFileTypeCharacterSpecial NSFileTypeBlockSpecial NSFileTypeUnknown NSFileSize NSFileModificationDate NSFileReferenceCount NSFileDeviceIdentifier NSFileOwnerAccountName NSFileGroupOwnerAccountName NSFilePosixPermissions NSFileSystemNumber NSFileSystemFileNumber NSFileExtensionHidden NSFileHFSCreatorCode NSFileHFSTypeCode NSFileImmutable NSFileAppendOnly NSFileCreationDate NSFileOwnerAccountID NSFileGroupOwnerAccountID NSFileBusy NSFileProtectionKey NSFileProtectionNone NSFileProtectionComplete NSFileProtectionCompleteUnlessOpen NSFileProtectionCompleteUntilFirstUserAuthentication NSFileSystemSize NSFileSystemFreeSize NSFileSystemNodes NSFileSystemFreeNodes
" NSFileHandle.h
syn match objcClass /NSFileHandle\s*\*/me=s+12,he=s+12
syn keyword objcExceptionValue NSFileHandleOperationException
syn keyword objcNotificationValue NSFileHandleReadCompletionNotification NSFileHandleReadToEndOfFileCompletionNotification NSFileHandleConnectionAcceptedNotification NSFileHandleDataAvailableNotification NSFileHandleNotificationDataItem NSFileHandleNotificationFileHandleItem NSFileHandleNotificationMonitorModes
syn match objcClass /NSPipe\s*\*/me=s+6,he=s+6
""""""""""""
" NSLocale.h
syn match objcClass /NSLocale\s*\*/me=s+8,he=s+8
syn keyword objcEnum NSLocaleLanguageDirection
syn keyword objcEnumValue NSLocaleLanguageDirectionUnknown NSLocaleLanguageDirectionLeftToRight NSLocaleLanguageDirectionRightToLeft NSLocaleLanguageDirectionTopToBottom NSLocaleLanguageDirectionBottomToTop
syn keyword objcNotificationValue NSCurrentLocaleDidChangeNotification
syn keyword objcConstVar NSLocaleIdentifier NSLocaleLanguageCode NSLocaleCountryCode NSLocaleScriptCode NSLocaleVariantCode NSLocaleExemplarCharacterSet NSLocaleCalendar NSLocaleCollationIdentifier NSLocaleUsesMetricSystem NSLocaleMeasurementSystem NSLocaleDecimalSeparator NSLocaleGroupingSeparator NSLocaleCurrencySymbol NSLocaleCurrencyCode NSLocaleCollatorIdentifier NSLocaleQuotationBeginDelimiterKey NSLocaleQuotationEndDelimiterKey NSLocaleAlternateQuotationBeginDelimiterKey NSLocaleAlternateQuotationEndDelimiterKey NSGregorianCalendar NSBuddhistCalendar NSChineseCalendar NSHebrewCalendar NSIslamicCalendar NSIslamicCivilCalendar NSJapaneseCalendar NSRepublicOfChinaCalendar NSPersianCalendar NSIndianCalendar NSISO8601Calendar 
" NSFormatter.h
syn match objcClass /NSFormatter\s*\*/me=s+11,he=s+11
syn keyword objcEnum NSFormattingContext NSFormattingUnitStyle
syn keyword objcEnumValue NSFormattingContextUnknown NSFormattingContextDynamic NSFormattingContextStandalone NSFormattingContextListItem NSFormattingContextBeginningOfSentence NSFormattingContextMiddleOfSentence NSFormattingUnitStyleShort NSFormattingUnitStyleMedium NSFormattingUnitStyleLong
" NSNumberFormatter.h
syn match objcClass /NSNumberFormatter\s*\*/me=s+17,he=s+17
syn keyword objcEnum NSNumberFormatterStyle
syn keyword objcEnumValue NSNumberFormatterNoStyle NSNumberFormatterDecimalStyle NSNumberFormatterCurrencyStyle NSNumberFormatterPercentStyle NSNumberFormatterScientificStyle NSNumberFormatterSpellOutStyle NSNumberFormatterOrdinalStyle NSNumberFormatterCurrencyISOCodeStyle NSNumberFormatterCurrencyPluralStyle NSNumberFormatterCurrencyAccountingStyle
syn keyword objcEnum NSNumberFormatterBehavior
syn keyword objcEnumValue NSNumberFormatterBehaviorDefault NSNumberFormatterBehavior10_0 NSNumberFormatterBehavior10_4
syn keyword objcEnum NSNumberFormatterPadPosition
syn keyword objcEnumValue NSNumberFormatterPadBeforePrefix NSNumberFormatterPadAfterPrefix NSNumberFormatterPadBeforeSuffix NSNumberFormatterPadAfterSuffix
syn keyword objcEnum NSNumberFormatterRoundingMode
syn keyword objcEnumValue NSNumberFormatterRoundCeiling NSNumberFormatterRoundFloor NSNumberFormatterRoundDown NSNumberFormatterRoundUp NSNumberFormatterRoundHalfEven NSNumberFormatterRoundHalfDown NSNumberFormatterRoundHalfUp
" NSDateFormatter.h
syn match objcClass /NSDateFormatter\s*\*/me=s+15,he=s+15
syn keyword objcEnum NSDateFormatterStyle
syn keyword objcEnumValue NSDateFormatterNoStyle NSDateFormatterShortStyle NSDateFormatterMediumStyle NSDateFormatterLongStyle NSDateFormatterFullStyle
syn keyword objcEnum NSDateFormatterBehavior
syn keyword objcEnumValue NSDateFormatterBehaviorDefault NSDateFormatterBehavior10_0 NSDateFormatterBehavior10_4
" NSCalendar.h
syn match objcClass /NSCalendar\s*\*/me=s+10,he=s+10
syn keyword objcConstVar NSCalendarIdentifierGregorian NSCalendarIdentifierBuddhist NSCalendarIdentifierChinese NSCalendarIdentifierCoptic NSCalendarIdentifierEthiopicAmeteMihret NSCalendarIdentifierEthiopicAmeteAlem NSCalendarIdentifierHebrew NSCalendarIdentifierISO8601 NSCalendarIdentifierIndian NSCalendarIdentifierIslamic NSCalendarIdentifierIslamicCivil NSCalendarIdentifierJapanese NSCalendarIdentifierPersian NSCalendarIdentifierRepublicOfChina NSCalendarIdentifierIslamicTabular NSCalendarIdentifierIslamicUmmAlQura
syn keyword objcEnum NSCalendarUnit
syn keyword objcEnumValue NSCalendarUnitEra NSCalendarUnitYear NSCalendarUnitMonth NSCalendarUnitDay NSCalendarUnitHour NSCalendarUnitMinute NSCalendarUnitSecond NSCalendarUnitWeekday NSCalendarUnitWeekdayOrdinal NSCalendarUnitQuarter NSCalendarUnitWeekOfMonth NSCalendarUnitWeekOfYear NSCalendarUnitYearForWeekOfYear NSCalendarUnitNanosecond NSCalendarUnitCalendar NSCalendarUnitTimeZone
syn keyword objcEnumValue NSEraCalendarUnit NSYearCalendarUnit NSMonthCalendarUnit NSDayCalendarUnit NSHourCalendarUnit NSMinuteCalendarUnit NSSecondCalendarUnit NSWeekCalendarUnit NSWeekdayCalendarUnit NSWeekdayOrdinalCalendarUnit NSQuarterCalendarUnit NSWeekOfMonthCalendarUnit NSWeekOfYearCalendarUnit NSYearForWeekOfYearCalendarUnit NSCalendarCalendarUnit NSTimeZoneCalendarUnit
syn keyword objcEnumValue NSWrapCalendarComponents NSUndefinedDateComponent NSDateComponentUndefined
syn match objcClass /NSDateComponents\s*\*/me=s+16,he=s+16
syn keyword objcEnum NSCalendarOptions
syn keyword objcEnumValue NSCalendarWrapComponents NSCalendarMatchStrictly NSCalendarSearchBackwards NSCalendarMatchPreviousTimePreservingSmallerUnits NSCalendarMatchNextTimePreservingSmallerUnits NSCalendarMatchNextTime NSCalendarMatchFirst NSCalendarMatchLast
syn keyword objcConstVar NSCalendarDayChangedNotification
" NSTimeZone.h
syn match objcClass /NSTimeZone\s*\*/me=s+10,he=s+10
syn keyword objcEnum NSTimeZoneNameStyle
syn keyword objcEnumValue NSTimeZoneNameStyleStandard NSTimeZoneNameStyleShortStandard NSTimeZoneNameStyleDaylightSaving NSTimeZoneNameStyleShortDaylightSaving NSTimeZoneNameStyleGeneric NSTimeZoneNameStyleShortGeneric
syn keyword objcNotificationValue NSSystemTimeZoneDidChangeNotification
"""""""""""
" NSCoder.h
syn match objcClass /NSCoder\s*\*/me=s+7,he=s+7
" NSArchiver.h
syn match objcClass /NSArchiver\s*\*/me=s+10,he=s+10
syn match objcClass /NSUnarchiver\s*\*/me=s+12,he=s+12
syn keyword objcExceptionValue NSInconsistentArchiveException
" NSKeyedArchiver.h
syn match objcClass /NSKeyedArchiver\s*\*/me=s+15,he=s+15
syn match objcClass /NSKeyedUnarchiver\s*\*/me=s+17,he=s+17
syn keyword objcExceptionValue NSInvalidArchiveOperationException NSInvalidUnarchiveOperationException
syn keyword objcConstVar NSKeyedArchiveRootObjectKey
""""""""""""""""""
" NSPropertyList.h
syn keyword objcEnum NSPropertyListMutabilityOptions
syn keyword objcEnumValue NSPropertyListImmutable NSPropertyListMutableContainers NSPropertyListMutableContainersAndLeaves
syn keyword objcEnum NSPropertyListFormat
syn keyword objcEnumValue NSPropertyListOpenStepFormat NSPropertyListXMLFormat_v1_0 NSPropertyListBinaryFormat_v1_0
syn keyword objcType NSPropertyListReadOptions NSPropertyListWriteOptions
" NSUserDefaults.h
syn match objcClass /NSUserDefaults\s*\*/me=s+14,he=s+14
syn keyword objcConstVar NSGlobalDomain NSArgumentDomain NSRegistrationDomain
syn keyword objcNotificationValue NSUserDefaultsDidChangeNotification
" NSBundle.h
syn match objcClass /NSBundle\s*\*/me=s+8,he=s+8
syn keyword objcEnumValue NSBundleExecutableArchitectureI386 NSBundleExecutableArchitecturePPC NSBundleExecutableArchitectureX86_64 NSBundleExecutableArchitecturePPC64
syn keyword objcNotificationValue NSBundleDidLoadNotification NSLoadedClasses NSBundleResourceRequestLowDiskSpaceNotification
syn keyword objcConstVar NSBundleResourceRequestLoadingPriorityUrgent
"""""""""""""""""
" NSProcessInfo.h
syn match objcClass /NSProcessInfo\s*\*/me=s+13,he=s+13
syn keyword objcEnumValue NSWindowsNTOperatingSystem NSWindows95OperatingSystem NSSolarisOperatingSystem NSHPUXOperatingSystem NSMACHOperatingSystem NSSunOSOperatingSystem NSOSF1OperatingSystem
syn keyword objcType NSOperatingSystemVersion
syn keyword objcEnum NSActivityOptions NSProcessInfoThermalState
syn keyword objcEnumValue NSActivityIdleDisplaySleepDisabled NSActivityIdleSystemSleepDisabled NSActivitySuddenTerminationDisabled NSActivityAutomaticTerminationDisabled NSActivityUserInitiated NSActivityUserInitiatedAllowingIdleSystemSleep NSActivityBackground NSActivityLatencyCritical NSProcessInfoThermalStateNominal NSProcessInfoThermalStateFair NSProcessInfoThermalStateSerious NSProcessInfoThermalStateCritical
syn keyword objcNotificationValue NSProcessInfoThermalStateDidChangeNotification NSProcessInfoPowerStateDidChangeNotification
" NSTask.h
syn match objcClass /NSTask\s*\*/me=s+6,he=s+6
syn keyword objcEnum NSTaskTerminationReason
syn keyword objcEnumValue NSTaskTerminationReasonExit NSTaskTerminationReasonUncaughtSignal
syn keyword objcNotificationValue NSTaskDidTerminateNotification
" NSThread.h
syn match objcClass /NSThread\s*\*/me=s+8,he=s+8
syn keyword objcNotificationValue NSWillBecomeMultiThreadedNotification NSDidBecomeSingleThreadedNotification NSThreadWillExitNotification
" NSLock.h
syn match objcClass /NSLock\s*\*/me=s+6,he=s+6
syn match objcClass /NSConditionLock\s*\*/me=s+15,he=s+15
syn match objcClass /NSRecursiveLock\s*\*/me=s+15,he=s+15
" NSDictributedLock
syn match objcClass /NSDistributedLock\s*\*/me=s+17,he=s+17
" NSOperation.h
""""""""""""""""
syn match objcClass /NSOperation\s*\*/me=s+11,he=s+11
syn keyword objcEnum NSOperationQueuePriority
syn keyword objcEnumValue NSOperationQueuePriorityVeryLow NSOperationQueuePriorityLow NSOperationQueuePriorityNormal NSOperationQueuePriorityHigh NSOperationQueuePriorityVeryHigh
syn match objcClass /NSBlockOperation\s*\*/me=s+16,he=s+16
syn match objcClass /NSInvocationOperation\s*\*/me=s+21,he=s+21
syn keyword objcExceptionValue NSInvocationOperationVoidResultException NSInvocationOperationCancelledException
syn match objcClass /NSOperationQueue\s*\*/me=s+16,he=s+16
syn keyword objcEnumValue NSOperationQueueDefaultMaxConcurrentOperationCount
" NSConnection.h
syn match objcClass /NSConnection\s*\*/me=s+12,he=s+12
syn keyword objcConstVar NSConnectionReplyMode
syn keyword objcNotificationValue NSConnectionDidDieNotification NSConnectionDidInitializeNotification
syn keyword objcExceptionValue NSFailedAuthenticationException
" NSPort.h
syn match objcClass /NSPort\s*\*/me=s+6,he=s+6
syn keyword objcType NSSocketNativeHandle
syn keyword objcNotificationValue NSPortDidBecomeInvalidNotification
syn match objcClass /NSMachPort\s*\*/me=s+10,he=s+10
syn keyword objcEnum NSMachPortOptions
syn keyword objcEnumValue NSMachPortDeallocateNone NSMachPortDeallocateSendRight NSMachPortDeallocateReceiveRight
syn match objcClass /NSMessagePort\s*\*/me=s+13,he=s+13
syn match objcClass /NSSocketPort\s*\*/me=s+12,he=s+12
" NSPortMessage.h
syn match objcClass /NSPortMessage\s*\*/me=s+13,he=s+13
" NSDistantObject.h
syn match objcClass /NSDistantObject\s*\*/me=s+15,he=s+15
" NSPortNameServer.h
syn match objcClass /NSPortNameServer\s*\*/me=s+16,he=s+16
syn match objcClass /NSMessagePortNameServer\s*\*/me=s+23,he=s+23
syn match objcClass /NSSocketPortNameServer\s*\*/me=s+22,he=s+22
" NSHost.h
syn match objcClass /NSHost\s*\*/me=s+6,he=s+6
" NSInvocation.h
syn match objcClass /NSInvocation\s*\*/me=s+12,he=s+12
" NSMethodSignature.h
syn match objcClass /NSMethodSignature\s*\*/me=s+17,he=s+17
"""""
" NSScanner.h
syn match objcClass /NSScanner\s*\*/me=s+9,he=s+9
" NSTimer.h
syn match objcClass /NSTimer\s*\*/me=s+7,he=s+7
" NSAutoreleasePool.h
syn match objcClass /NSAutoreleasePool\s*\*/me=s+17,he=s+17
" NSRunLoop.h
syn match objcClass /NSRunLoop\s*\*/me=s+9,he=s+9
syn keyword objcConstVar NSDefaultRunLoopMode NSRunLoopCommonModes
" NSNull.h
syn match objcClass /NSNull\s*\*/me=s+6,he=s+6
" NSProxy.h
syn match objcClass /NSProxy\s*\*/me=s+7,he=s+7
" NSObject.h
syn match objcClass /NSObject\s*\*/me=s+8,he=s+8


" NSCache.h
syn match objcClass /NSCache\s*\*/me=s+7,he=s+7
syn match objcClass /NSCache<.*>\s*\*/me=s+7,he=s+7 contains=objcTypeInfoParams
" NSHashTable.h
syn match objcClass /NSHashTable\s*\*/me=s+11,he=s+11
syn match objcClass /NSHashTable<.*>\s*\*/me=s+11,he=s+11 contains=objcTypeInfoParams
syn keyword objcConstVar NSHashTableStrongMemory NSHashTableZeroingWeakMemory NSHashTableCopyIn NSHashTableObjectPointerPersonality NSHashTableWeakMemory
syn keyword objcType NSHashTableOptions NSHashEnumerator NSHashTableCallBacks
syn keyword objcConstVar NSIntegerHashCallBacks NSNonOwnedPointerHashCallBacks NSNonRetainedObjectHashCallBacks NSObjectHashCallBacks NSOwnedObjectIdentityHashCallBacks NSOwnedPointerHashCallBacks NSPointerToStructHashCallBacks NSOwnedObjectIdentityHashCallBacks NSOwnedObjectIdentityHashCallBacks NSIntHashCallBacks
" NSMapTable.h
syn match objcClass /NSMapTable\s*\*/me=s+10,he=s+10
syn match objcClass /NSMapTable<.*>\s*\*/me=s+10,he=s+10 contains=objcTypeInfoParams
syn keyword objcConstVar NSPointerToStructHashCallBacks NSPointerToStructHashCallBacks NSPointerToStructHashCallBacks NSPointerToStructHashCallBacks NSPointerToStructHashCallBacks
syn keyword objcConstVar NSMapTableStrongMemory NSMapTableZeroingWeakMemory NSMapTableCopyIn NSMapTableObjectPointerPersonality NSMapTableWeakMemory
syn keyword objcType NSMapTableOptions NSMapEnumerator NSMapTableKeyCallBacks NSMapTableValueCallBacks
syn keyword objcMacro NSNotAnIntMapKey NSNotAnIntegerMapKey NSNotAPointerMapKey
syn keyword objcConstVar NSIntegerMapKeyCallBacks NSNonOwnedPointerMapKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks NSNonRetainedObjectMapKeyCallBacks NSObjectMapKeyCallBacks NSOwnedPointerMapKeyCallBacks NSIntMapKeyCallBacks NSIntegerMapValueCallBacks NSNonOwnedPointerMapValueCallBacks NSObjectMapValueCallBacks NSNonRetainedObjectMapValueCallBacks NSOwnedPointerMapValueCallBacks NSIntMapValueCallBacks

" NSPointerFunctions.h
syn match objcClass /NSPointerFunctions\s*\*/me=s+18,he=s+18
syn keyword objcEnum NSPointerFunctionsOptions
syn keyword objcEnumValue NSPointerFunctionsStrongMemory NSPointerFunctionsZeroingWeakMemory NSPointerFunctionsOpaqueMemory NSPointerFunctionsMallocMemory NSPointerFunctionsMachVirtualMemory NSPointerFunctionsWeakMemory NSPointerFunctionsObjectPersonality NSPointerFunctionsOpaquePersonality NSPointerFunctionsObjectPointerPersonality NSPointerFunctionsCStringPersonality NSPointerFunctionsStructPersonality NSPointerFunctionsIntegerPersonality NSPointerFunctionsCopyIn


""" Default Highlighting
hi def link objcPreProcMacro                cConstant
hi def link objcPrincipalType               cType
hi def link objcUsefulTerm                  cConstant
hi def link objcImport                      cInclude
hi def link objcImported                    cString
hi def link objcObjDef                      cOperator
hi def link objcProtocol                    cOperator
hi def link objcProperty                    cOperator
hi def link objcIvarScope                   cOperator
hi def link objcInternalRep                 cOperator
hi def link objcException                   cOperator
hi def link objcThread                      cOperator
hi def link objcPool                        cOperator
hi def link objcModuleImport                cOperator
hi def link objcSpecial                     cSpecial
hi def link objcString                      cString
hi def link objcHiddenArgument              cStatement
hi def link objcBlocksQualifier             cStorageClass
hi def link objcObjectLifetimeQualifier     cStorageClass
hi def link objcTollFreeBridgeQualifier     cStorageClass
hi def link objcRemoteMessagingQualifier    cStorageClass
hi def link objcStorageClass                cStorageClass
hi def link objcFastEnumKeyword             cStatement
hi def link objcLiteralSyntaxNumber         cNumber
hi def link objcLiteralSyntaxChar           cCharacter
hi def link objcLiteralSyntaxSpecialChar    cCharacter
hi def link objcLiteralSyntaxOp             cOperator
hi def link objcDeclPropAccessorName        cConstant
hi def link objcDeclPropAccessorType        cConstant
hi def link objcDeclPropAssignSemantics     cConstant
hi def link objcDeclPropAtomicity           cConstant
hi def link objcDeclPropARC                 cConstant
hi def link objcDeclPropNullable            cConstant
hi def link objcDeclPropNonnull             cConstant
hi def link objcDeclPropNullUnspecified     cConstant
hi def link objcDeclProcNullResettable      cConstant
hi def link objcInstanceMethod              Function
hi def link objcClassMethod                 Function
hi def link objcType                        cType
hi def link objcClass                       cType
hi def link objcTypeSpecifier               cType
hi def link objcMacro                       cConstant
hi def link objcEnum                        cType
hi def link objcEnumValue                   cConstant
hi def link objcExceptionValue              cConstant
hi def link objcNotificationValue           cConstant
hi def link objcConstVar                    cConstant
hi def link objcTypeInfoParams              Identifier

""" Final step
let b:current_syntax = "objc"
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=2 sts=2
