" Vim syntax file
" Language:          ReDIF
" Maintainer:        Axel Castellane <axel.castellane@polytechnique.edu>
" Last Change:       2013 April 17
" Original Author:   Axel Castellane
" Source:            http://openlib.org/acmes/root/docu/redif_1.html
" File Extension:    rdf
" Note:              The ReDIF format is used by RePEc.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" ReDIF is case-insensitive
syntax case ignore

" Structure: Some fields determine what fields can come next. For example:
"       Template-Type
"       *-Name
"       File-URL
"       *-Institution
" Those fields span a syntax region over several lines so that these regions
" can only contain their respective items.

" Any line which is not a correct template or part of an argument is an error.
" This comes at the very beginning, so it has the lowest priority and will
" only match if nothing else did.
syntax match redifWrongLine /^.\+/ display

highlight def link redifWrongLine redifError

" Comments must start with # and it must be the first character of the line,
" otherwise I believe that they are considered as part of an argument.
syntax match redifComment /^#.*/ containedin=ALL display

" Defines the 9 possible multi-lines regions of Template-Type and the fields
" they can contain.
syntax region redifRegionTemplatePaper start=/^Template-Type:\_s*ReDIF-Paper \d\+\.\d\+/ end=/^Template-Type:/me=s-1 contains=redifContainerFieldsPaper,redifWrongLine,redifRegionClusterAuthor,redifRegionClusterFile fold
syntax region redifRegionTemplateArticle start=/^Template-Type:\_s*ReDIF-Article \d\+\.\d\+/ end=/^Template-Type:/me=s-1 contains=redifContainerFieldsArticle,redifWrongLine,redifRegionClusterAuthor,redifRegionClusterFile fold
syntax region redifRegionTemplateChapter start=/^Template-Type:\_s*ReDIF-Chapter \d\+\.\d\+/ end=/^Template-Type:/me=s-1 contains=redifContainerFieldsChapter,redifWrongLine,redifRegionClusterAuthor,redifRegionClusterFile,redifRegionClusterProvider,redifRegionClusterPublisher,redifRegionClusterEditor fold
syntax region redifRegionTemplateBook start=/^Template-Type:\_s*ReDIF-Book \d\+\.\d\+/ end=/^Template-Type:/me=s-1 contains=redifContainerFieldsBook,redifWrongLine,redifRegionClusterAuthor,redifRegionClusterFile,redifRegionClusterProvider,redifRegionClusterPublisher,redifRegionClusterEditor fold
syntax region redifRegionTemplateSoftware start=/^Template-Type:\_s*ReDIF-Software \d\+\.\d\+/ end=/^Template-Type:/me=s-1 contains=redifContainerFieldsSoftware,redifWrongLine,redifRegionClusterAuthor,redifRegionClusterFile fold
syntax region redifRegionTemplateArchive start=/^Template-Type:\_s*ReDIF-Archive \d\+\.\d\+/ end=/^Template-Type:/me=s-1 contains=redifContainerFieldsArchive,redifWrongLine fold
syntax region redifRegionTemplateSeries start=/^Template-Type:\_s*ReDIF-Series \d\+\.\d\+/ end=/^Template-Type:/me=s-1 contains=redifContainerFieldsSeries,redifWrongLine,redifRegionClusterProvider,redifRegionClusterPublisher,redifRegionClusterEditor fold
syntax region redifRegionTemplateInstitution start=/^Template-Type:\_s*ReDIF-Institution \d\+\.\d\+/ end=/^Template-Type:/me=s-1 contains=redifContainerFieldsInstitution,redifWrongLine,redifRegionClusterPrimary,redifRegionClusterSecondary,redifRegionClusterTertiary,redifRegionClusterQuaternary fold
syntax region redifRegionTemplatePerson start=/^Template-Type:\_s*ReDIF-Person \d\+\.\d\+/ end=/^Template-Type:/me=s-1 contains=redifContainerFieldsPerson,redifWrongLine,redifRegionClusterWorkplace fold

" All fields are foldable (These come before clusters, so they have lower
" priority). So they are contained in a foldable syntax region.
syntax region redifContainerFieldsPaper start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldTitle,redifFieldHandleOfWork,redifFieldLanguage,redifFieldContactEmail,redifFieldAbstract,redifFieldClassificationJEL,redifFieldKeywords,redifFieldNumber,redifFieldCreationDate,redifFieldRevisionDate,redifFieldPublicationStatus,redifFieldNote,redifFieldLength,redifFieldSeries,redifFieldAvailability,redifFieldOrderURL,redifFieldArticleHandle,redifFieldBookHandle,redifFieldChapterHandle,redifFieldPaperHandle,redifFieldSoftwareHandle,redifFieldRestriction,redifFieldPrice,redifFieldNotification,redifFieldPublicationType,redifFieldTemplateType,redifWrongLine contained transparent fold
syntax region redifContainerFieldsArticle start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldTitle,redifFieldHandleOfWork,redifFieldLanguage,redifFieldContactEmail,redifFieldAbstract,redifFieldClassificationJEL,redifFieldKeywords,redifFieldNumber,redifFieldCreationDate,redifFieldPublicationStatus,redifFieldOrderURL,redifFieldArticleHandle,redifFieldBookHandle,redifFieldChapterHandle,redifFieldPaperHandle,redifFieldSoftwareHandle,redifFieldRestriction,redifFieldPrice,redifFieldNotification,redifFieldPublicationType,redifFieldJournal,redifFieldVolume,redifFieldYear,redifFieldIssue,redifFieldMonth,redifFieldPages,redifFieldNumber,redifFieldArticleHandle,redifFieldBookHandle,redifFieldChapterHandle,redifFieldPaperHandle,redifFieldSoftwareHandle,redifFieldTemplateType,redifWrongLine contained transparent fold
syntax region redifContainerFieldsChapter start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldHandleOfWork,redifFieldTitle,redifFieldContactEmail,redifFieldAbstract,redifFieldClassificationJEL,redifFieldKeywords,redifFieldBookTitle,redifFieldYear,redifFieldMonth,redifFieldPages,redifFieldChapter,redifFieldVolume,redifFieldEdition,redifFieldSeries,redifFieldISBN,redifFieldPublicationStatus,redifFieldNote,redifFieldInBook,redifFieldOrderURL,redifFieldArticleHandle,redifFieldBookHandle,redifFieldChapterHandle,redifFieldPaperHandle,redifFieldSoftwareHandle,redifFieldTemplateType,redifWrongLine contained transparent fold
syntax region redifContainerFieldsBook start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldTitle,redifFieldHandleOfWork,redifFieldContactEmail,redifFieldYear,redifFieldMonth,redifFieldVolume,redifFieldEdition,redifFieldSeries,redifFieldISBN,redifFieldPublicationStatus,redifFieldNote,redifFieldAbstract,redifFieldClassificationJEL,redifFieldKeywords,redifFieldHasChapter,redifFieldPrice,redifFieldOrderURL,redifFieldNumber,redifFieldCreationDate,redifFieldPublicationDate,redifFieldArticleHandle,redifFieldBookHandle,redifFieldChapterHandle,redifFieldPaperHandle,redifFieldSoftwareHandle,redifFieldTemplateType,redifWrongLine contained transparent fold
syntax region redifContainerFieldsSoftware start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldHandleOfWork,redifFieldTitle,redifFieldProgrammingLanguage,redifFieldAbstract,redifFieldNumber,redifFieldVersion,redifFieldClassificationJEL,redifFieldKeywords,redifFieldSize,redifFieldSeries,redifFieldCreationDate,redifFieldRevisionDate,redifFieldNote,redifFieldRequires,redifFieldArticleHandle,redifFieldBookHandle,redifFieldChapterHandle,redifFieldPaperHandle,redifFieldSoftwareHandle,redifFieldTemplateType,redifWrongLine contained transparent fold
syntax region redifContainerFieldsArchive start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldHandleOfArchive,redifFieldURL,redifFieldMaintainerEmail,redifFieldName,redifFieldMaintainerName,redifFieldMaintainerPhone,redifFieldMaintainerFax,redifFieldClassificationJEL,redifFieldHomepage,redifFieldDescription,redifFieldNotification,redifFieldRestriction,redifFieldTemplateType,redifWrongLine contained transparent fold
syntax region redifContainerFieldsSeries start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldName,redifFieldHandleOfSeries,redifFieldMaintainerEmail,redifFieldType,redifFieldOrderEmail,redifFieldOrderHomepage,redifFieldOrderPostal,redifFieldPrice,redifFieldRestriction,redifFieldMaintainerPhone,redifFieldMaintainerFax,redifFieldMaintainerName,redifFieldDescription,redifFieldClassificationJEL,redifFieldKeywords,redifFieldNotification,redifFieldISSN,redifFieldFollowup,redifFieldPredecessor,redifFieldTemplateType,redifWrongLine contained transparent fold
syntax region redifContainerFieldsInstitution start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldHandleOfInstitution,redifFieldPrimaryDefunct,redifFieldSecondaryDefunct,redifFieldTertiaryDefunct,redifFieldTemplateType,redifWrongLine contained transparent fold
syntax region redifContainerFieldsPerson start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldHandleOfPerson,redifFieldNameFull,redifFieldNameFirst,redifFieldNameLast,redifFieldNamePrefix,redifFieldNameMiddle,redifFieldNameSuffix,redifFieldNameASCII,redifFieldEmail,redifFieldHomepage,redifFieldFax,redifFieldPostal,redifFieldPhone,redifFieldWorkplaceOrganization,redifFieldAuthorPaper,redifFieldAuthorArticle,redifFieldAuthorSoftware,redifFieldAuthorBook,redifFieldAuthorChapter,redifFieldEditorBook,redifFieldEditorSeries,redifFieldClassificationJEL,redifFieldShortId,redifFieldLastLoginDate,redifFieldRegisteredDate,redifWrongLine contained transparent fold

" Defines the 10 possible clusters and what they can contain
" A field not in the cluster ends the cluster.
syntax region redifRegionClusterWorkplace start=/^Workplace-Name:/ skip=/^Workplace-\%(Name-English\|Homepage\|Postal\|Location\|Email\|Phone\|Fax\|Institution\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifContainerFieldsWorkplace fold
syntax region redifRegionClusterPrimary start=/^Primary-Name:/ skip=/^Primary-\%(Name-English\|Homepage\|Postal\|Location\|Email\|Phone\|Fax\|Institution\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifContainerFieldsPrimary fold
syntax region redifRegionClusterSecondary start=/^Secondary-Name:/ skip=/^Secondary-\%(Name-English\|Homepage\|Postal\|Location\|Email\|Phone\|Fax\|Institution\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifContainerFieldsSecondary fold
syntax region redifRegionClusterTertiary start=/^Tertiary-Name:/ skip=/^Tertiary-\%(Name-English\|Homepage\|Postal\|Location\|Email\|Phone\|Fax\|Institution\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifContainerFieldsTertiary fold
syntax region redifRegionClusterQuaternary start=/^Quaternary-Name:/ skip=/^Quaternary-\%(Name-English\|Homepage\|Postal\|Location\|Email\|Phone\|Fax\|Institution\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifContainerFieldsQuaternary fold
syntax region redifRegionClusterProvider start=/^Provider-Name:/ skip=/^Provider-\%(Name-English\|Homepage\|Postal\|Location\|Email\|Phone\|Fax\|Institution\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifContainerFieldsProvider fold
syntax region redifRegionClusterPublisher start=/^Publisher-Name:/ skip=/^Publisher-\%(Name-English\|Homepage\|Postal\|Location\|Email\|Phone\|Fax\|Institution\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifContainerFieldsPublisher fold
syntax region redifRegionClusterAuthor start=/^Author-Name:/ skip=/^Author-\%(Name\%(-First\|-Last\)\|Homepage\|Email\|Fax\|Postal\|Phone\|Person\|Workplace-Name\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifRegionClusterAuthorWorkplace,redifContainerFieldsAuthor fold
syntax region redifRegionClusterEditor start=/^Editor-Name:/ skip=/^Editor-\%(Name\%(-First\|-Last\)\|Homepage\|Email\|Fax\|Postal\|Phone\|Person\|Workplace-Name\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifRegionClusterEditorWorkplace,redifContainerFieldsEditor fold
syntax region redifRegionClusterFile start=/^File-URL:/ skip=/^File-\%(Format\|Function\|Size\|Restriction\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifContainerFieldsFile fold

" The foldable containers of the clusters.
syntax region redifContainerFieldsWorkplace start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldWorkplaceName,redifFieldWorkplaceHomepage,redifFieldWorkplaceNameEnglish,redifFieldWorkplacePostal,redifFieldWorkplaceLocation,redifFieldWorkplaceEmail,redifFieldWorkplacePhone,redifFieldWorkplaceFax,redifFieldWorkplaceInstitution,redifWrongLine contained transparent fold
syntax region redifContainerFieldsPrimary start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldPrimaryName,redifFieldPrimaryHomepage,redifFieldPrimaryNameEnglish,redifFieldPrimaryPostal,redifFieldPrimaryLocation,redifFieldPrimaryEmail,redifFieldPrimaryPhone,redifFieldPrimaryFax,redifFieldPrimaryInstitution,redifWrongLine contained transparent fold
syntax region redifContainerFieldsSecondary start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldSecondaryName,redifFieldSecondaryHomepage,redifFieldSecondaryNameEnglish,redifFieldSecondaryPostal,redifFieldSecondaryLocation,redifFieldSecondaryEmail,redifFieldSecondaryPhone,redifFieldSecondaryFax,redifFieldSecondaryInstitution,redifWrongLine contained transparent fold
syntax region redifContainerFieldsTertiary start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldTertiaryName,redifFieldTertiaryHomepage,redifFieldTertiaryNameEnglish,redifFieldTertiaryPostal,redifFieldTertiaryLocation,redifFieldTertiaryEmail,redifFieldTertiaryPhone,redifFieldTertiaryFax,redifFieldTertiaryInstitution,redifWrongLine contained transparent fold
syntax region redifContainerFieldsQuaternary start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldQuaternaryName,redifFieldQuaternaryHomepage,redifFieldQuaternaryNameEnglish,redifFieldQuaternaryPostal,redifFieldQuaternaryLocation,redifFieldQuaternaryEmail,redifFieldQuaternaryPhone,redifFieldQuaternaryFax,redifFieldQuaternaryInstitution,redifWrongLine contained transparent fold
syntax region redifContainerFieldsProvider start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldProviderName,redifFieldProviderHomepage,redifFieldProviderNameEnglish,redifFieldProviderPostal,redifFieldProviderLocation,redifFieldProviderEmail,redifFieldProviderPhone,redifFieldProviderFax,redifFieldProviderInstitution,redifWrongLine contained transparent fold
syntax region redifContainerFieldsPublisher start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldPublisherName,redifFieldPublisherHomepage,redifFieldPublisherNameEnglish,redifFieldPublisherPostal,redifFieldPublisherLocation,redifFieldPublisherEmail,redifFieldPublisherPhone,redifFieldPublisherFax,redifFieldPublisherInstitution,redifWrongLine contained transparent fold
syntax region redifContainerFieldsAuthor start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldAuthorName,redifFieldAuthorNameFirst,redifFieldAuthorNameLast,redifFieldAuthorHomepage,redifFieldAuthorEmail,redifFieldAuthorFax,redifFieldAuthorPostal,redifFieldAuthorPhone,redifFieldAuthorPerson,redifWrongLine contained transparent fold
syntax region redifContainerFieldsEditor start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldEditorName,redifFieldEditorNameFirst,redifFieldEditorNameLast,redifFieldEditorHomepage,redifFieldEditorEmail,redifFieldEditorFax,redifFieldEditorPostal,redifFieldEditorPhone,redifFieldEditorPerson,redifWrongLine contained transparent fold
syntax region redifContainerFieldsFile start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldFileURL,redifFieldFileFormat,redifFieldFileFunction,redifFieldFileSize,redifFieldFileRestriction,redifWrongLine contained transparent fold

" The two clusters in cluster (must be presented after to have priority over
" fields containers)
syntax region redifRegionClusterAuthorWorkplace start=/^Author-Workplace-Name:/ skip=/^Author-Workplace-\%(Name-English\|Homepage\|Postal\|Location\|Email\|Phone\|Fax\|Institution\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifContainerFieldsAuthorWorkplace fold
syntax region redifRegionClusterEditorWorkplace start=/^Editor-Workplace-Name:/ skip=/^Editor-Workplace-\%(Name-English\|Homepage\|Postal\|Location\|Email\|Phone\|Fax\|Institution\):/ end=/^\S\{-}:/me=s-1 contained contains=redifWrongLine,redifContainerFieldsEditorWorkplace fold

" Their foldable fields containers
syntax region redifContainerFieldsAuthorWorkplace start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldAuthorWorkplaceName,redifFieldAuthorWorkplaceHomepage,redifFieldAuthorWorkplaceNameEnglish,redifFieldAuthorWorkplacePostal,redifFieldAuthorWorkplaceLocation,redifFieldAuthorWorkplaceEmail,redifFieldAuthorWorkplacePhone,redifFieldAuthorWorkplaceFax,redifFieldAuthorWorkplaceInstitution,redifWrongLine contained transparent fold
syntax region redifContainerFieldsEditorWorkplace start=/^\S\{-}:/ end=/^\S\{-}:/me=s-1 contains=redifFieldEditorWorkplaceName,redifFieldEditorWorkplaceHomepage,redifFieldEditorWorkplaceNameEnglish,redifFieldEditorWorkplacePostal,redifFieldEditorWorkplaceLocation,redifFieldEditorWorkplaceEmail,redifFieldEditorWorkplacePhone,redifFieldEditorWorkplaceFax,redifFieldEditorWorkplaceInstitution,redifWrongLine contained transparent fold

" All the possible fields
"     Note: The "Handle" field is handled a little bit differently, because it
"     does not have the same meaning depending on the Template-Type. See:
" 	  /redifFieldHandleOf....
syntax match redifFieldAbstract /^Abstract:/ skipwhite skipempty nextgroup=redifArgumentAbstract contained
syntax match redifFieldArticleHandle /^Article-Handle:/ skipwhite skipempty nextgroup=redifArgumentArticleHandle contained
syntax match redifFieldAuthorArticle /^Author-Article:/ skipwhite skipempty nextgroup=redifArgumentAuthorArticle contained
syntax match redifFieldAuthorBook /^Author-Book:/ skipwhite skipempty nextgroup=redifArgumentAuthorBook contained
syntax match redifFieldAuthorChapter /^Author-Chapter:/ skipwhite skipempty nextgroup=redifArgumentAuthorChapter contained
syntax match redifFieldAuthorEmail /^Author-Email:/ skipwhite skipempty nextgroup=redifArgumentAuthorEmail contained
syntax match redifFieldAuthorFax /^Author-Fax:/ skipwhite skipempty nextgroup=redifArgumentAuthorFax contained
syntax match redifFieldAuthorHomepage /^Author-Homepage:/ skipwhite skipempty nextgroup=redifArgumentAuthorHomepage contained
syntax match redifFieldAuthorName /^Author-Name:/ skipwhite skipempty nextgroup=redifArgumentAuthorName contained
syntax match redifFieldAuthorNameFirst /^Author-Name-First:/ skipwhite skipempty nextgroup=redifArgumentAuthorNameFirst contained
syntax match redifFieldAuthorNameLast /^Author-Name-Last:/ skipwhite skipempty nextgroup=redifArgumentAuthorNameLast contained
syntax match redifFieldAuthorPaper /^Author-Paper:/ skipwhite skipempty nextgroup=redifArgumentAuthorPaper contained
syntax match redifFieldAuthorPerson /^Author-Person:/ skipwhite skipempty nextgroup=redifArgumentAuthorPerson contained
syntax match redifFieldAuthorPhone /^Author-Phone:/ skipwhite skipempty nextgroup=redifArgumentAuthorPhone contained
syntax match redifFieldAuthorPostal /^Author-Postal:/ skipwhite skipempty nextgroup=redifArgumentAuthorPostal contained
syntax match redifFieldAuthorSoftware /^Author-Software:/ skipwhite skipempty nextgroup=redifArgumentAuthorSoftware contained
syntax match redifFieldAuthorWorkplaceEmail /^Author-Workplace-Email:/ skipwhite skipempty nextgroup=redifArgumentAuthorWorkplaceEmail contained
syntax match redifFieldAuthorWorkplaceFax /^Author-Workplace-Fax:/ skipwhite skipempty nextgroup=redifArgumentAuthorWorkplaceFax contained
syntax match redifFieldAuthorWorkplaceHomepage /^Author-Workplace-Homepage:/ skipwhite skipempty nextgroup=redifArgumentAuthorWorkplaceHomepage contained
syntax match redifFieldAuthorWorkplaceInstitution /^Author-Workplace-Institution:/ skipwhite skipempty nextgroup=redifArgumentAuthorWorkplaceInstitution contained
syntax match redifFieldAuthorWorkplaceLocation /^Author-Workplace-Location:/ skipwhite skipempty nextgroup=redifArgumentAuthorWorkplaceLocation contained
syntax match redifFieldAuthorWorkplaceName /^Author-Workplace-Name:/ skipwhite skipempty nextgroup=redifArgumentAuthorWorkplaceName contained
syntax match redifFieldAuthorWorkplaceNameEnglish /^Author-Workplace-Name-English:/ skipwhite skipempty nextgroup=redifArgumentAuthorWorkplaceNameEnglish contained
syntax match redifFieldAuthorWorkplacePhone /^Author-Workplace-Phone:/ skipwhite skipempty nextgroup=redifArgumentAuthorWorkplacePhone contained
syntax match redifFieldAuthorWorkplacePostal /^Author-Workplace-Postal:/ skipwhite skipempty nextgroup=redifArgumentAuthorWorkplacePostal contained
syntax match redifFieldAvailability /^Availability:/ skipwhite skipempty nextgroup=redifArgumentAvailability contained
syntax match redifFieldBookHandle /^Book-Handle:/ skipwhite skipempty nextgroup=redifArgumentBookHandle contained
syntax match redifFieldBookTitle /^Book-Title:/ skipwhite skipempty nextgroup=redifArgumentBookTitle contained
syntax match redifFieldChapterHandle /^Chapter-Handle:/ skipwhite skipempty nextgroup=redifArgumentChapterHandle contained
syntax match redifFieldChapter /^Chapter:/ skipwhite skipempty nextgroup=redifArgumentChapter contained
syntax match redifFieldClassificationJEL /^Classification-JEL:/ skipwhite skipempty nextgroup=redifArgumentClassificationJEL contained
syntax match redifFieldContactEmail /^Contact-Email:/ skipwhite skipempty nextgroup=redifArgumentContactEmail contained
syntax match redifFieldCreationDate /^Creation-Date:/ skipwhite skipempty nextgroup=redifArgumentCreationDate contained
syntax match redifFieldDescription /^Description:/ skipwhite skipempty nextgroup=redifArgumentDescription contained
syntax match redifFieldEdition /^Edition:/ skipwhite skipempty nextgroup=redifArgumentEdition contained
syntax match redifFieldEditorBook /^Editor-Book:/ skipwhite skipempty nextgroup=redifArgumentEditorBook contained
syntax match redifFieldEditorEmail /^Editor-Email:/ skipwhite skipempty nextgroup=redifArgumentEditorEmail contained
syntax match redifFieldEditorFax /^Editor-Fax:/ skipwhite skipempty nextgroup=redifArgumentEditorFax contained
syntax match redifFieldEditorHomepage /^Editor-Homepage:/ skipwhite skipempty nextgroup=redifArgumentEditorHomepage contained
syntax match redifFieldEditorName /^Editor-Name:/ skipwhite skipempty nextgroup=redifArgumentEditorName contained
syntax match redifFieldEditorNameFirst /^Editor-Name-First:/ skipwhite skipempty nextgroup=redifArgumentEditorNameFirst contained
syntax match redifFieldEditorNameLast /^Editor-Name-Last:/ skipwhite skipempty nextgroup=redifArgumentEditorNameLast contained
syntax match redifFieldEditorPerson /^Editor-Person:/ skipwhite skipempty nextgroup=redifArgumentEditorPerson contained
syntax match redifFieldEditorPhone /^Editor-Phone:/ skipwhite skipempty nextgroup=redifArgumentEditorPhone contained
syntax match redifFieldEditorPostal /^Editor-Postal:/ skipwhite skipempty nextgroup=redifArgumentEditorPostal contained
syntax match redifFieldEditorSeries /^Editor-Series:/ skipwhite skipempty nextgroup=redifArgumentEditorSeries contained
syntax match redifFieldEditorWorkplaceEmail /^Editor-Workplace-Email:/ skipwhite skipempty nextgroup=redifArgumentEditorWorkplaceEmail contained
syntax match redifFieldEditorWorkplaceFax /^Editor-Workplace-Fax:/ skipwhite skipempty nextgroup=redifArgumentEditorWorkplaceFax contained
syntax match redifFieldEditorWorkplaceHomepage /^Editor-Workplace-Homepage:/ skipwhite skipempty nextgroup=redifArgumentEditorWorkplaceHomepage contained
syntax match redifFieldEditorWorkplaceInstitution /^Editor-Workplace-Institution:/ skipwhite skipempty nextgroup=redifArgumentEditorWorkplaceInstitution contained
syntax match redifFieldEditorWorkplaceLocation /^Editor-Workplace-Location:/ skipwhite skipempty nextgroup=redifArgumentEditorWorkplaceLocation contained
syntax match redifFieldEditorWorkplaceName /^Editor-Workplace-Name:/ skipwhite skipempty nextgroup=redifArgumentEditorWorkplaceName contained
syntax match redifFieldEditorWorkplaceNameEnglish /^Editor-Workplace-Name-English:/ skipwhite skipempty nextgroup=redifArgumentEditorWorkplaceNameEnglish contained
syntax match redifFieldEditorWorkplacePhone /^Editor-Workplace-Phone:/ skipwhite skipempty nextgroup=redifArgumentEditorWorkplacePhone contained
syntax match redifFieldEditorWorkplacePostal /^Editor-Workplace-Postal:/ skipwhite skipempty nextgroup=redifArgumentEditorWorkplacePostal contained
syntax match redifFieldEmail /^Email:/ skipwhite skipempty nextgroup=redifArgumentEmail contained
syntax match redifFieldFax /^Fax:/ skipwhite skipempty nextgroup=redifArgumentFax contained
syntax match redifFieldFileFormat /^File-Format:/ skipwhite skipempty nextgroup=redifArgumentFileFormat contained
syntax match redifFieldFileFunction /^File-Function:/ skipwhite skipempty nextgroup=redifArgumentFileFunction contained
syntax match redifFieldFileRestriction /^File-Restriction:/ skipwhite skipempty nextgroup=redifArgumentFileRestriction contained
syntax match redifFieldFileSize /^File-Size:/ skipwhite skipempty nextgroup=redifArgumentFileSize contained
syntax match redifFieldFileURL /^File-URL:/ skipwhite skipempty nextgroup=redifArgumentFileURL contained
syntax match redifFieldFollowup /^Followup:/ skipwhite skipempty nextgroup=redifArgumentFollowup contained
syntax match redifFieldHandleOfArchive /^Handle:/ skipwhite skipempty nextgroup=redifArgumentHandleOfArchive contained
syntax match redifFieldHandleOfInstitution /^Handle:/ skipwhite skipempty nextgroup=redifArgumentHandleOfInstitution contained
syntax match redifFieldHandleOfPerson /^Handle:/ skipwhite skipempty nextgroup=redifArgumentHandleOfPerson contained
syntax match redifFieldHandleOfSeries /^Handle:/ skipwhite skipempty nextgroup=redifArgumentHandleOfSeries contained
syntax match redifFieldHandleOfWork /^Handle:/ skipwhite skipempty nextgroup=redifArgumentHandleOfWork contained
syntax match redifFieldHasChapter /^HasChapter:/ skipwhite skipempty nextgroup=redifArgumentHasChapter contained
syntax match redifFieldHomepage /^Homepage:/ skipwhite skipempty nextgroup=redifArgumentHomepage contained
syntax match redifFieldInBook /^In-Book:/ skipwhite skipempty nextgroup=redifArgumentInBook contained
syntax match redifFieldISBN /^ISBN:/ skipwhite skipempty nextgroup=redifArgumentISBN contained
syntax match redifFieldISSN /^ISSN:/ skipwhite skipempty nextgroup=redifArgumentISSN contained
syntax match redifFieldIssue /^Issue:/ skipwhite skipempty nextgroup=redifArgumentIssue contained
syntax match redifFieldJournal /^Journal:/ skipwhite skipempty nextgroup=redifArgumentJournal contained
syntax match redifFieldKeywords /^Keywords:/ skipwhite skipempty nextgroup=redifArgumentKeywords contained
syntax match redifFieldKeywords /^Keywords:/ skipwhite skipempty nextgroup=redifArgumentKeywords contained
syntax match redifFieldLanguage /^Language:/ skipwhite skipempty nextgroup=redifArgumentLanguage contained
syntax match redifFieldLastLoginDate /^Last-Login-Date:/ skipwhite skipempty nextgroup=redifArgumentLastLoginDate contained
syntax match redifFieldLength /^Length:/ skipwhite skipempty nextgroup=redifArgumentLength contained
syntax match redifFieldMaintainerEmail /^Maintainer-Email:/ skipwhite skipempty nextgroup=redifArgumentMaintainerEmail contained
syntax match redifFieldMaintainerFax /^Maintainer-Fax:/ skipwhite skipempty nextgroup=redifArgumentMaintainerFax contained
syntax match redifFieldMaintainerName /^Maintainer-Name:/ skipwhite skipempty nextgroup=redifArgumentMaintainerName contained
syntax match redifFieldMaintainerPhone /^Maintainer-Phone:/ skipwhite skipempty nextgroup=redifArgumentMaintainerPhone contained
syntax match redifFieldMonth /^Month:/ skipwhite skipempty nextgroup=redifArgumentMonth contained
syntax match redifFieldNameASCII /^Name-ASCII:/ skipwhite skipempty nextgroup=redifArgumentNameASCII contained
syntax match redifFieldNameFirst /^Name-First:/ skipwhite skipempty nextgroup=redifArgumentNameFirst contained
syntax match redifFieldNameFull /^Name-Full:/ skipwhite skipempty nextgroup=redifArgumentNameFull contained
syntax match redifFieldNameLast /^Name-Last:/ skipwhite skipempty nextgroup=redifArgumentNameLast contained
syntax match redifFieldNameMiddle /^Name-Middle:/ skipwhite skipempty nextgroup=redifArgumentNameMiddle contained
syntax match redifFieldNamePrefix /^Name-Prefix:/ skipwhite skipempty nextgroup=redifArgumentNamePrefix contained
syntax match redifFieldNameSuffix /^Name-Suffix:/ skipwhite skipempty nextgroup=redifArgumentNameSuffix contained
syntax match redifFieldName /^Name:/ skipwhite skipempty nextgroup=redifArgumentName contained
syntax match redifFieldNote /^Note:/ skipwhite skipempty nextgroup=redifArgumentNote contained
syntax match redifFieldNotification /^Notification:/ skipwhite skipempty nextgroup=redifArgumentNotification contained
syntax match redifFieldNumber /^Number:/ skipwhite skipempty nextgroup=redifArgumentNumber contained
syntax match redifFieldOrderEmail /^Order-Email:/ skipwhite skipempty nextgroup=redifArgumentOrderEmail contained
syntax match redifFieldOrderHomepage /^Order-Homepage:/ skipwhite skipempty nextgroup=redifArgumentOrderHomepage contained
syntax match redifFieldOrderPostal /^Order-Postal:/ skipwhite skipempty nextgroup=redifArgumentOrderPostal contained
syntax match redifFieldOrderURL /^Order-URL:/ skipwhite skipempty nextgroup=redifArgumentOrderURL contained
syntax match redifFieldPages /^Pages:/ skipwhite skipempty nextgroup=redifArgumentPages contained
syntax match redifFieldPaperHandle /^Paper-Handle:/ skipwhite skipempty nextgroup=redifArgumentPaperHandle contained
syntax match redifFieldPhone /^Phone:/ skipwhite skipempty nextgroup=redifArgumentPhone contained
syntax match redifFieldPostal /^Postal:/ skipwhite skipempty nextgroup=redifArgumentPostal contained
syntax match redifFieldPredecessor /^Predecessor:/ skipwhite skipempty nextgroup=redifArgumentPredecessor contained
syntax match redifFieldPrice /^Price:/ skipwhite skipempty nextgroup=redifArgumentPrice contained
syntax match redifFieldPrimaryDefunct /^Primary-Defunct:/ skipwhite skipempty nextgroup=redifArgumentPrimaryDefunct contained
syntax match redifFieldPrimaryEmail /^Primary-Email:/ skipwhite skipempty nextgroup=redifArgumentPrimaryEmail contained
syntax match redifFieldPrimaryFax /^Primary-Fax:/ skipwhite skipempty nextgroup=redifArgumentPrimaryFax contained
syntax match redifFieldPrimaryHomepage /^Primary-Homepage:/ skipwhite skipempty nextgroup=redifArgumentPrimaryHomepage contained
syntax match redifFieldPrimaryInstitution /^Primary-Institution:/ skipwhite skipempty nextgroup=redifArgumentPrimaryInstitution contained
syntax match redifFieldPrimaryLocation /^Primary-Location:/ skipwhite skipempty nextgroup=redifArgumentPrimaryLocation contained
syntax match redifFieldPrimaryName /^Primary-Name:/ skipwhite skipempty nextgroup=redifArgumentPrimaryName contained
syntax match redifFieldPrimaryNameEnglish /^Primary-Name-English:/ skipwhite skipempty nextgroup=redifArgumentPrimaryNameEnglish contained
syntax match redifFieldPrimaryPhone /^Primary-Phone:/ skipwhite skipempty nextgroup=redifArgumentPrimaryPhone contained
syntax match redifFieldPrimaryPostal /^Primary-Postal:/ skipwhite skipempty nextgroup=redifArgumentPrimaryPostal contained
syntax match redifFieldProgrammingLanguage /^Programming-Language:/ skipwhite skipempty nextgroup=redifArgumentProgrammingLanguage contained
syntax match redifFieldProviderEmail /^Provider-Email:/ skipwhite skipempty nextgroup=redifArgumentProviderEmail contained
syntax match redifFieldProviderFax /^Provider-Fax:/ skipwhite skipempty nextgroup=redifArgumentProviderFax contained
syntax match redifFieldProviderHomepage /^Provider-Homepage:/ skipwhite skipempty nextgroup=redifArgumentProviderHomepage contained
syntax match redifFieldProviderInstitution /^Provider-Institution:/ skipwhite skipempty nextgroup=redifArgumentProviderInstitution contained
syntax match redifFieldProviderLocation /^Provider-Location:/ skipwhite skipempty nextgroup=redifArgumentProviderLocation contained
syntax match redifFieldProviderName /^Provider-Name:/ skipwhite skipempty nextgroup=redifArgumentProviderName contained
syntax match redifFieldProviderNameEnglish /^Provider-Name-English:/ skipwhite skipempty nextgroup=redifArgumentProviderNameEnglish contained
syntax match redifFieldProviderPhone /^Provider-Phone:/ skipwhite skipempty nextgroup=redifArgumentProviderPhone contained
syntax match redifFieldProviderPostal /^Provider-Postal:/ skipwhite skipempty nextgroup=redifArgumentProviderPostal contained
syntax match redifFieldPublicationDate /^Publication-Date:/ skipwhite skipempty nextgroup=redifArgumentPublicationDate contained
syntax match redifFieldPublicationStatus /^Publication-Status:/ skipwhite skipempty nextgroup=redifArgumentPublicationStatus contained
syntax match redifFieldPublicationType /^Publication-Type:/ skipwhite skipempty nextgroup=redifArgumentPublicationType contained
syntax match redifFieldQuaternaryEmail /^Quaternary-Email:/ skipwhite skipempty nextgroup=redifArgumentQuaternaryEmail contained
syntax match redifFieldQuaternaryFax /^Quaternary-Fax:/ skipwhite skipempty nextgroup=redifArgumentQuaternaryFax contained
syntax match redifFieldQuaternaryHomepage /^Quaternary-Homepage:/ skipwhite skipempty nextgroup=redifArgumentQuaternaryHomepage contained
syntax match redifFieldQuaternaryInstitution /^Quaternary-Institution:/ skipwhite skipempty nextgroup=redifArgumentQuaternaryInstitution contained
syntax match redifFieldQuaternaryLocation /^Quaternary-Location:/ skipwhite skipempty nextgroup=redifArgumentQuaternaryLocation contained
syntax match redifFieldQuaternaryName /^Quaternary-Name:/ skipwhite skipempty nextgroup=redifArgumentQuaternaryName contained
syntax match redifFieldQuaternaryNameEnglish /^Quaternary-Name-English:/ skipwhite skipempty nextgroup=redifArgumentQuaternaryNameEnglish contained
syntax match redifFieldQuaternaryPhone /^Quaternary-Phone:/ skipwhite skipempty nextgroup=redifArgumentQuaternaryPhone contained
syntax match redifFieldQuaternaryPostal /^Quaternary-Postal:/ skipwhite skipempty nextgroup=redifArgumentQuaternaryPostal contained
syntax match redifFieldRegisteredDate /^Registered-Date:/ skipwhite skipempty nextgroup=redifArgumentRegisteredDate contained
syntax match redifFieldRequires /^Requires:/ skipwhite skipempty nextgroup=redifArgumentRequires contained
syntax match redifFieldRestriction /^Restriction:/ skipwhite skipempty nextgroup=redifArgumentRestriction contained
syntax match redifFieldRevisionDate /^Revision-Date:/ skipwhite skipempty nextgroup=redifArgumentRevisionDate contained
syntax match redifFieldSecondaryDefunct /^Secondary-Defunct:/ skipwhite skipempty nextgroup=redifArgumentSecondaryDefunct contained
syntax match redifFieldSecondaryEmail /^Secondary-Email:/ skipwhite skipempty nextgroup=redifArgumentSecondaryEmail contained
syntax match redifFieldSecondaryFax /^Secondary-Fax:/ skipwhite skipempty nextgroup=redifArgumentSecondaryFax contained
syntax match redifFieldSecondaryHomepage /^Secondary-Homepage:/ skipwhite skipempty nextgroup=redifArgumentSecondaryHomepage contained
syntax match redifFieldSecondaryInstitution /^Secondary-Institution:/ skipwhite skipempty nextgroup=redifArgumentSecondaryInstitution contained
syntax match redifFieldSecondaryLocation /^Secondary-Location:/ skipwhite skipempty nextgroup=redifArgumentSecondaryLocation contained
syntax match redifFieldSecondaryName /^Secondary-Name:/ skipwhite skipempty nextgroup=redifArgumentSecondaryName contained
syntax match redifFieldSecondaryNameEnglish /^Secondary-Name-English:/ skipwhite skipempty nextgroup=redifArgumentSecondaryNameEnglish contained
syntax match redifFieldSecondaryPhone /^Secondary-Phone:/ skipwhite skipempty nextgroup=redifArgumentSecondaryPhone contained
syntax match redifFieldSecondaryPostal /^Secondary-Postal:/ skipwhite skipempty nextgroup=redifArgumentSecondaryPostal contained
syntax match redifFieldSeries /^Series:/ skipwhite skipempty nextgroup=redifArgumentSeries contained
syntax match redifFieldShortId /^Short-Id:/ skipwhite skipempty nextgroup=redifArgumentShortId contained
syntax match redifFieldSize /^Size:/ skipwhite skipempty nextgroup=redifArgumentSize contained
syntax match redifFieldSoftwareHandle /^Software-Handle:/ skipwhite skipempty nextgroup=redifArgumentSoftwareHandle contained
syntax match redifFieldTemplateType /^Template-Type:/ skipwhite skipempty nextgroup=redifArgumentTemplateType contained
syntax match redifFieldTertiaryDefunct /^Tertiary-Defunct:/ skipwhite skipempty nextgroup=redifArgumentTertiaryDefunct contained
syntax match redifFieldTertiaryEmail /^Tertiary-Email:/ skipwhite skipempty nextgroup=redifArgumentTertiaryEmail contained
syntax match redifFieldTertiaryFax /^Tertiary-Fax:/ skipwhite skipempty nextgroup=redifArgumentTertiaryFax contained
syntax match redifFieldTertiaryHomepage /^Tertiary-Homepage:/ skipwhite skipempty nextgroup=redifArgumentTertiaryHomepage contained
syntax match redifFieldTertiaryInstitution /^Tertiary-Institution:/ skipwhite skipempty nextgroup=redifArgumentTertiaryInstitution contained
syntax match redifFieldTertiaryLocation /^Tertiary-Location:/ skipwhite skipempty nextgroup=redifArgumentTertiaryLocation contained
syntax match redifFieldTertiaryName /^Tertiary-Name:/ skipwhite skipempty nextgroup=redifArgumentTertiaryName contained
syntax match redifFieldTertiaryNameEnglish /^Tertiary-Name-English:/ skipwhite skipempty nextgroup=redifArgumentTertiaryNameEnglish contained
syntax match redifFieldTertiaryPhone /^Tertiary-Phone:/ skipwhite skipempty nextgroup=redifArgumentTertiaryPhone contained
syntax match redifFieldTertiaryPostal /^Tertiary-Postal:/ skipwhite skipempty nextgroup=redifArgumentTertiaryPostal contained
syntax match redifFieldTitle /^Title:/ skipwhite skipempty nextgroup=redifArgumentTitle contained
syntax match redifFieldType /^Type:/ skipwhite skipempty nextgroup=redifArgumentType contained
syntax match redifFieldURL /^URL:/ skipwhite skipempty nextgroup=redifArgumentURL contained
syntax match redifFieldVersion /^Version:/ skipwhite skipempty nextgroup=redifArgumentVersion contained
syntax match redifFieldVolume /^Volume:/ skipwhite skipempty nextgroup=redifArgumentVolume contained
syntax match redifFieldWorkplaceEmail /^Workplace-Email:/ skipwhite skipempty nextgroup=redifArgumentWorkplaceEmail contained
syntax match redifFieldWorkplaceFax /^Workplace-Fax:/ skipwhite skipempty nextgroup=redifArgumentWorkplaceFax contained
syntax match redifFieldWorkplaceHomepage /^Workplace-Homepage:/ skipwhite skipempty nextgroup=redifArgumentWorkplaceHomepage contained
syntax match redifFieldWorkplaceInstitution /^Workplace-Institution:/ skipwhite skipempty nextgroup=redifArgumentWorkplaceInstitution contained
syntax match redifFieldWorkplaceLocation /^Workplace-Location:/ skipwhite skipempty nextgroup=redifArgumentWorkplaceLocation contained
syntax match redifFieldWorkplaceName /^Workplace-Name:/ skipwhite skipempty nextgroup=redifArgumentWorkplaceName contained
syntax match redifFieldWorkplaceNameEnglish /^Workplace-Name-English:/ skipwhite skipempty nextgroup=redifArgumentWorkplaceNameEnglish contained
syntax match redifFieldWorkplaceOrganization /^Workplace-Organization:/ skipwhite skipempty nextgroup=redifArgumentWorkplaceOrganization contained
syntax match redifFieldWorkplacePhone /^Workplace-Phone:/ skipwhite skipempty nextgroup=redifArgumentWorkplacePhone contained
syntax match redifFieldWorkplacePostal /^Workplace-Postal:/ skipwhite skipempty nextgroup=redifArgumentWorkplacePostal contained
syntax match redifFieldYear /^Year:/ skipwhite skipempty nextgroup=redifArgumentYear contained

highlight def link redifFieldAbstract redifField
highlight def link redifFieldArticleHandle redifField
highlight def link redifFieldAuthorArticle redifField
highlight def link redifFieldAuthorBook redifField
highlight def link redifFieldAuthorChapter redifField
highlight def link redifFieldAuthorEmail redifField
highlight def link redifFieldAuthorFax redifField
highlight def link redifFieldAuthorHomepage redifField
highlight def link redifFieldAuthorName redifField
highlight def link redifFieldAuthorNameFirst redifField
highlight def link redifFieldAuthorNameLast redifField
highlight def link redifFieldAuthorPaper redifField
highlight def link redifFieldAuthorPerson redifField
highlight def link redifFieldAuthorPhone redifField
highlight def link redifFieldAuthorPostal redifField
highlight def link redifFieldAuthorSoftware redifField
highlight def link redifFieldAuthorWorkplaceEmail redifField
highlight def link redifFieldAuthorWorkplaceFax redifField
highlight def link redifFieldAuthorWorkplaceHomepage redifField
highlight def link redifFieldAuthorWorkplaceInstitution redifField
highlight def link redifFieldAuthorWorkplaceLocation redifField
highlight def link redifFieldAuthorWorkplaceName redifField
highlight def link redifFieldAuthorWorkplaceNameEnglish redifField
highlight def link redifFieldAuthorWorkplacePhone redifField
highlight def link redifFieldAuthorWorkplacePostal redifField
highlight def link redifFieldAvailability redifField
highlight def link redifFieldBookHandle redifField
highlight def link redifFieldBookTitle redifField
highlight def link redifFieldChapterHandle redifField
highlight def link redifFieldChapter redifField
highlight def link redifFieldClassificationJEL redifField
highlight def link redifFieldContactEmail redifField
highlight def link redifFieldCreationDate redifField
highlight def link redifFieldDescription redifField
highlight def link redifFieldEdition redifField
highlight def link redifFieldEditorBook redifField
highlight def link redifFieldEditorEmail redifField
highlight def link redifFieldEditorFax redifField
highlight def link redifFieldEditorHomepage redifField
highlight def link redifFieldEditorName redifField
highlight def link redifFieldEditorNameFirst redifField
highlight def link redifFieldEditorNameLast redifField
highlight def link redifFieldEditorPerson redifField
highlight def link redifFieldEditorPhone redifField
highlight def link redifFieldEditorPostal redifField
highlight def link redifFieldEditorSeries redifField
highlight def link redifFieldEditorWorkplaceEmail redifField
highlight def link redifFieldEditorWorkplaceFax redifField
highlight def link redifFieldEditorWorkplaceHomepage redifField
highlight def link redifFieldEditorWorkplaceInstitution redifField
highlight def link redifFieldEditorWorkplaceLocation redifField
highlight def link redifFieldEditorWorkplaceName redifField
highlight def link redifFieldEditorWorkplaceNameEnglish redifField
highlight def link redifFieldEditorWorkplacePhone redifField
highlight def link redifFieldEditorWorkplacePostal redifField
highlight def link redifFieldEmail redifField
highlight def link redifFieldFax redifField
highlight def link redifFieldFileFormat redifField
highlight def link redifFieldFileFunction redifField
highlight def link redifFieldFileRestriction redifField
highlight def link redifFieldFileSize redifField
highlight def link redifFieldFileURL redifField
highlight def link redifFieldFollowup redifField
highlight def link redifFieldHandleOfArchive redifField
highlight def link redifFieldHandleOfInstitution redifField
highlight def link redifFieldHandleOfPerson redifField
highlight def link redifFieldHandleOfSeries redifField
highlight def link redifFieldHandleOfWork redifField
highlight def link redifFieldHasChapter redifField
highlight def link redifFieldHomepage redifField
highlight def link redifFieldInBook redifField
highlight def link redifFieldISBN redifField
highlight def link redifFieldISSN redifField
highlight def link redifFieldIssue redifField
highlight def link redifFieldJournal redifField
highlight def link redifFieldKeywords redifField
highlight def link redifFieldKeywords redifField
highlight def link redifFieldLanguage redifField
highlight def link redifFieldLastLoginDate redifField
highlight def link redifFieldLength redifField
highlight def link redifFieldMaintainerEmail redifField
highlight def link redifFieldMaintainerFax redifField
highlight def link redifFieldMaintainerName redifField
highlight def link redifFieldMaintainerPhone redifField
highlight def link redifFieldMonth redifField
highlight def link redifFieldNameASCII redifField
highlight def link redifFieldNameFirst redifField
highlight def link redifFieldNameFull redifField
highlight def link redifFieldNameLast redifField
highlight def link redifFieldNameMiddle redifField
highlight def link redifFieldNamePrefix redifField
highlight def link redifFieldNameSuffix redifField
highlight def link redifFieldName redifField
highlight def link redifFieldNote redifField
highlight def link redifFieldNotification redifField
highlight def link redifFieldNumber redifField
highlight def link redifFieldOrderEmail redifField
highlight def link redifFieldOrderHomepage redifField
highlight def link redifFieldOrderPostal redifField
highlight def link redifFieldOrderURL redifField
highlight def link redifFieldPages redifField
highlight def link redifFieldPaperHandle redifField
highlight def link redifFieldPhone redifField
highlight def link redifFieldPostal redifField
highlight def link redifFieldPredecessor redifField
highlight def link redifFieldPrice redifField
highlight def link redifFieldPrimaryDefunct redifField
highlight def link redifFieldPrimaryEmail redifField
highlight def link redifFieldPrimaryFax redifField
highlight def link redifFieldPrimaryHomepage redifField
highlight def link redifFieldPrimaryInstitution redifField
highlight def link redifFieldPrimaryLocation redifField
highlight def link redifFieldPrimaryName redifField
highlight def link redifFieldPrimaryNameEnglish redifField
highlight def link redifFieldPrimaryPhone redifField
highlight def link redifFieldPrimaryPostal redifField
highlight def link redifFieldProgrammingLanguage redifField
highlight def link redifFieldProviderEmail redifField
highlight def link redifFieldProviderFax redifField
highlight def link redifFieldProviderHomepage redifField
highlight def link redifFieldProviderInstitution redifField
highlight def link redifFieldProviderLocation redifField
highlight def link redifFieldProviderName redifField
highlight def link redifFieldProviderNameEnglish redifField
highlight def link redifFieldProviderPhone redifField
highlight def link redifFieldProviderPostal redifField
highlight def link redifFieldPublicationDate redifField
highlight def link redifFieldPublicationStatus redifField
highlight def link redifFieldPublicationType redifField
highlight def link redifFieldQuaternaryEmail redifField
highlight def link redifFieldQuaternaryFax redifField
highlight def link redifFieldQuaternaryHomepage redifField
highlight def link redifFieldQuaternaryInstitution redifField
highlight def link redifFieldQuaternaryLocation redifField
highlight def link redifFieldQuaternaryName redifField
highlight def link redifFieldQuaternaryNameEnglish redifField
highlight def link redifFieldQuaternaryPhone redifField
highlight def link redifFieldQuaternaryPostal redifField
highlight def link redifFieldRegisteredDate redifField
highlight def link redifFieldRequires redifField
highlight def link redifFieldRestriction redifField
highlight def link redifFieldRevisionDate redifField
highlight def link redifFieldSecondaryDefunct redifField
highlight def link redifFieldSecondaryEmail redifField
highlight def link redifFieldSecondaryFax redifField
highlight def link redifFieldSecondaryHomepage redifField
highlight def link redifFieldSecondaryInstitution redifField
highlight def link redifFieldSecondaryLocation redifField
highlight def link redifFieldSecondaryName redifField
highlight def link redifFieldSecondaryNameEnglish redifField
highlight def link redifFieldSecondaryPhone redifField
highlight def link redifFieldSecondaryPostal redifField
highlight def link redifFieldSeries redifField
highlight def link redifFieldShortId redifField
highlight def link redifFieldSize redifField
highlight def link redifFieldSoftwareHandle redifField
highlight def link redifFieldTemplateType redifField
highlight def link redifFieldTertiaryDefunct redifField
highlight def link redifFieldTertiaryEmail redifField
highlight def link redifFieldTertiaryFax redifField
highlight def link redifFieldTertiaryHomepage redifField
highlight def link redifFieldTertiaryInstitution redifField
highlight def link redifFieldTertiaryLocation redifField
highlight def link redifFieldTertiaryName redifField
highlight def link redifFieldTertiaryNameEnglish redifField
highlight def link redifFieldTertiaryPhone redifField
highlight def link redifFieldTertiaryPostal redifField
highlight def link redifFieldTitle redifField
highlight def link redifFieldTitle redifField
highlight def link redifFieldType redifField
highlight def link redifFieldURL redifField
highlight def link redifFieldVersion redifField
highlight def link redifFieldVolume redifField
highlight def link redifFieldWorkplaceEmail redifField
highlight def link redifFieldWorkplaceFax redifField
highlight def link redifFieldWorkplaceHomepage redifField
highlight def link redifFieldWorkplaceInstitution redifField
highlight def link redifFieldWorkplaceLocation redifField
highlight def link redifFieldWorkplaceName redifField
highlight def link redifFieldWorkplaceNameEnglish redifField
highlight def link redifFieldWorkplaceOrganization redifField
highlight def link redifFieldWorkplacePhone redifField
highlight def link redifFieldWorkplacePostal redifField
highlight def link redifFieldYear redifField

" Deprecated
"     same as Provider-*
"     nextgroup=redifArgumentProvider*
syntax match redifFieldPublisherEmail /^Publisher-Email:/ skipwhite skipempty nextgroup=redifArgumentProviderEmail contained
syntax match redifFieldPublisherFax /^Publisher-Fax:/ skipwhite skipempty nextgroup=redifArgumentProviderFax contained
syntax match redifFieldPublisherHomepage /^Publisher-Homepage:/ skipwhite skipempty nextgroup=redifArgumentProviderHomepage contained
syntax match redifFieldPublisherInstitution /^Publisher-Institution:/ skipwhite skipempty nextgroup=redifArgumentProviderInstitution contained
syntax match redifFieldPublisherLocation /^Publisher-Location:/ skipwhite skipempty nextgroup=redifArgumentProviderLocation contained
syntax match redifFieldPublisherName /^Publisher-Name:/ skipwhite skipempty nextgroup=redifArgumentProviderName contained
syntax match redifFieldPublisherNameEnglish /^Publisher-Name-English:/ skipwhite skipempty nextgroup=redifArgumentProviderNameEnglish contained
syntax match redifFieldPublisherPhone /^Publisher-Phone:/ skipwhite skipempty nextgroup=redifArgumentProviderPhone contained
syntax match redifFieldPublisherPostal /^Publisher-Postal:/ skipwhite skipempty nextgroup=redifArgumentProviderPostal contained

highlight def link redifFieldPublisherEmail redifFieldDeprecated
highlight def link redifFieldPublisherFax redifFieldDeprecated
highlight def link redifFieldPublisherHomepage redifFieldDeprecated
highlight def link redifFieldPublisherInstitution redifFieldDeprecated
highlight def link redifFieldPublisherLocation redifFieldDeprecated
highlight def link redifFieldPublisherName redifFieldDeprecated
highlight def link redifFieldPublisherNameEnglish redifFieldDeprecated
highlight def link redifFieldPublisherPhone redifFieldDeprecated
highlight def link redifFieldPublisherPostal redifFieldDeprecated

" Standard arguments
"    By default, they contain all the argument until another field is started:
"        start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1
"    For arguments that must not span more than one line, use a match:
"        /\%(^\S\{-}:\)\@!\S.*/
"        AND ADD "display"
"    This is faster.
"
"    Those arguments are not highlighted so far. They are here for future
"    extensions.
"    TODO Find more RegEx for these arguments
"    	TODO Fax, Phone
"    	TODO URL, Homepage
"    	TODO Keywords
"    	TODO Classification-JEL
"    	TODO Short-Id, Author-Person, Editor-Person
"
"    Arguments that may span several lines:
syntax region redifArgumentAuthorWorkplaceLocation start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorWorkplacePostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorPostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorWorkplacePostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentFileFunction start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentIssue start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentJournal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentOrderPostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentPostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentPrice start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentPrimaryLocation start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentPrimaryPostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentProviderLocation start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentProviderPostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentQuaternaryLocation start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentQuaternaryPostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentRequires start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentSecondaryLocation start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentSecondaryPostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentSize start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentTertiaryLocation start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentTertiaryPostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentVersion start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentWorkplaceLocation start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentWorkplacePhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentWorkplacePostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained

" Arguments that may not span several lines:
"    If you are sure that these arguments cannot span several lines, change
"    them to a match:
"        /\%(^\S\{-}:\)\@!\S.*/
"    AND ADD "display" after "contained"
"        You can use this command on each line that you want to change:
"        :s+\Vregion \(\w\+\) start=/\\%(^\\S\\{-}:\\)\\@!\\S/ end=/^\\S\\{-}:/me=s-1 contained+match \1 /\\%(^\\S\\{-}:\\)\\@!\\S.*/ contained display
syntax region redifArgumentAuthorFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorNameFirst start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorNameLast start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorPerson start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorPhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorPostal start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorWorkplaceFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorWorkplaceHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorWorkplaceName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorWorkplaceNameEnglish start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentAuthorWorkplacePhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorNameFirst start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorNameLast start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorPerson start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorPhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorWorkplaceFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorWorkplaceHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorWorkplaceLocation start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorWorkplaceName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorWorkplaceNameEnglish start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentEditorWorkplacePhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentFileURL start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentMaintainerFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentMaintainerName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentMaintainerPhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentNameFirst start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentNameFull start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentNameLast start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentNameMiddle start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentNamePrefix start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentNameSuffix start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentNumber start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentOrderHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentOrderURL start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentPhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentPrimaryFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentPrimaryHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentPrimaryName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentPrimaryNameEnglish start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentPrimaryPhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentProviderFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentProviderHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentProviderName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentProviderNameEnglish start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentProviderPhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentQuaternaryFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentQuaternaryHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentQuaternaryName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentQuaternaryNameEnglish start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentQuaternaryPhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentSecondaryFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentSecondaryHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentSecondaryName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentSecondaryNameEnglish start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentSecondaryPhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentSeries start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentShortId start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentTertiaryFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentTertiaryHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentTertiaryName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentTertiaryNameEnglish start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentTertiaryPhone start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentURL start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentWorkplaceFax start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentWorkplaceHomepage start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentWorkplaceName start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentWorkplaceNameEnglish start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained
syntax region redifArgumentWorkplaceOrganization start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contained

" Special arguments
"    Those arguments require special values
"    TODO Improve some RegEx
"    	TODO Improve Emails
"    	TODO Improve ISBN
"    	TODO Improve ISSN
"    	TODO Improve spell check (add words from economics.
"    	   expl=macroeconometrics, Schumpeterian, IS-LM, etc.)
"
"    Template-Type
syntax match redifArgumentTemplateType /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectTemplateType contained display
syntax match redifCorrectTemplateType /ReDIF-\%(Paper\|Article\|Chapter\|Book\|Software\|Archive\|Series\|Institution\|Person\)/ nextgroup=redifTemplateVersionNumberContainer contained display
syntax match redifTemplateVersionNumberContainer /.\+/ contains=redifTemplateVersionNumber contained display
syntax match redifTemplateVersionNumber / \d\+\.\d\+/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentTemplateType redifError
highlight def link redifCorrectTemplateType Constant
highlight def link redifTemplateVersionNumber Number
highlight def link redifTemplateVersionNumberContainer redifError

"    Handles:
"
"        Handles of Works:
syntax match redifArgumentHandleOfWork /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentAuthorArticle /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentAuthorBook /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentAuthorChapter /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentAuthorPaper /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentAuthorSoftware /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentEditorBook /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentEditorSeries /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentInBook /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentHasChapter /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentArticleHandle /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentBookHandle /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentChapterHandle /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentPaperHandle /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifArgumentSoftwareHandle /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfWork contained display
syntax match redifCorrectHandleOfWork /RePEc:\a\a\a:\%(_\@!\w\)\{6}:\S\+/ contains=redifForbiddenCharactersInHandle,redifBestPracticeInHandle nextgroup=redifWrongLineEnding contained display
" TODO Are those characters really forbidden???
syntax match redifForbiddenCharactersInHandle /[\/*?"<>|]/ contained display
syntax match redifBestPracticeInHandle /\<\%([vi]:[1-9]\d*\|y:[1-9]\d\{3}\|p:[1-9]\d*-[1-9]\d*\|i:\%(jan\|feb\|mar\|apr\|may\|jun\|jul\|aug\|sep\|oct\|nov\|dec\|spr\|sum\|aut\|win\|spe\|Q[1-4]\|\d\d-\d\d\)\|Q:[1-4]\)\>/ contained display

highlight def link redifArgumentHandleOfWork redifError
highlight def link redifArgumentAuthorArticle redifError
highlight def link redifArgumentAuthorBook redifError
highlight def link redifArgumentAuthorChapter redifError
highlight def link redifArgumentAuthorPaper redifError
highlight def link redifArgumentAuthorSoftware redifError
highlight def link redifArgumentEditorBook redifError
highlight def link redifArgumentEditorSeries redifError
highlight def link redifArgumentInBook redifError
highlight def link redifArgumentHasChapter redifError
highlight def link redifArgumentArticleHandle redifError
highlight def link redifArgumentBookHandle redifError
highlight def link redifArgumentChapterHandle redifError
highlight def link redifArgumentPaperHandle redifError
highlight def link redifArgumentSoftwareHandle redifError
highlight def link redifForbiddenCharactersInHandle redifError
highlight def link redifBestPracticeInHandle redifSpecial

"        Handles of Series:
syntax match redifArgumentHandleOfSeries /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfSeries contained display
syntax match redifArgumentFollowup /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfSeries contained display
syntax match redifArgumentPredecessor /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfSeries contained display
syntax match redifCorrectHandleOfSeries /RePEc:\a\a\a:\%(_\@!\w\)\{6}/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentHandleOfSeries redifError
highlight def link redifArgumentFollowup redifError
highlight def link redifArgumentPredecessor redifError

"        Handles of Archives:
syntax match redifArgumentHandleOfArchive /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfArchive contained display
syntax match redifCorrectHandleOfArchive /RePEc:\a\a\a/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentHandleOfArchive redifError

"        Handles of Person:
syntax match redifArgumentHandleOfPerson /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfPerson contained display
syntax match redifCorrectHandleOfPerson /\%(\%(:\@!\S\)\{-}:\)\{2}[1-9]\d\{3}\%(-02\%(-[12]\d\|-0[1-9]\)\|-\%(0[469]\|11\)\%(-30\|-[12]\d\|-0[1-9]\)\|-\%(0[13578]\|1[02]\)\%(-3[01]\|-[12]\d\|-0[1-9]\)\):\S\+/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentHandleOfPerson redifError

"        Handles of Institution:
syntax match redifArgumentAuthorWorkplaceInstitution /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentEditorWorkplaceInstitution /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentPrimaryInstitution /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentProviderInstitution /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentPublisherInstitution /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentQuaternaryInstitution /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentSecondaryInstitution /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentTertiaryInstitution /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentWorkplaceInstitution /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentHandleOfInstitution /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentPrimaryDefunct /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentSecondaryDefunct /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
syntax match redifArgumentTertiaryDefunct /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectHandleOfInstitution contained display
" TODO Are digits authorized? Apparently not.
" Country codes:
" http://www.iso.org/iso/country_codes/iso_3166_code_lists/country_names_and_code_elements.htm
syntax match redifCorrectHandleOfInstitution /RePEc:\a\a\a:\a\{5}\(ea\|af\|ax\|al\|dz\|as\|ad\|ao\|ai\|aq\|ag\|ar\|am\|aw\|au\|at\|az\|bs\|bh\|bd\|bb\|by\|be\|bz\|bj\|bm\|bt\|bo\|bq\|ba\|bw\|bv\|br\|io\|bn\|bg\|bf\|bi\|kh\|cm\|ca\|cv\|ky\|cf\|td\|cl\|cn\|cx\|cc\|co\|km\|cg\|cd\|ck\|cr\|ci\|hr\|cu\|cw\|cy\|cz\|dk\|dj\|dm\|do\|ec\|eg\|sv\|gq\|er\|ee\|et\|fk\|fo\|fj\|fi\|fr\|gf\|pf\|tf\|ga\|gm\|ge\|de\|gh\|gi\|gr\|gl\|gd\|gp\|gu\|gt\|gg\|gn\|gw\|gy\|ht\|hm\|va\|hn\|hk\|hu\|is\|in\|id\|ir\|iq\|ie\|im\|il\|it\|jm\|jp\|je\|jo\|kz\|ke\|ki\|kp\|kr\|kw\|kg\|la\|lv\|lb\|ls\|lr\|ly\|li\|lt\|lu\|mo\|mk\|mg\|mw\|my\|mv\|ml\|mt\|mh\|mq\|mr\|mu\|yt\|mx\|fm\|md\|mc\|mn\|me\|ms\|ma\|mz\|mm\|na\|nr\|np\|nl\|nc\|nz\|ni\|ne\|ng\|nu\|nf\|mp\|no\|om\|pk\|pw\|ps\|pa\|pg\|py\|pe\|ph\|pn\|pl\|pt\|pr\|qa\|re\|ro\|ru\|rw\|bl\|sh\|kn\|lc\|mf\|pm\|vc\|ws\|sm\|st\|sa\|sn\|rs\|sc\|sl\|sg\|sx\|sk\|si\|sb\|so\|za\|gs\|ss\|es\|lk\|sd\|sr\|sj\|sz\|se\|ch\|sy\|tw\|tj\|tz\|th\|tl\|tg\|tk\|to\|tt\|tn\|tr\|tm\|tc\|tv\|ug\|ua\|ae\|gb\|us\|um\|uy\|uz\|vu\|ve\|vn\|vg\|vi\|wf\|eh\|ye\|zm\|zw\)/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentHandleOfInstitution redifError
highlight def link redifArgumentPrimaryDefunct redifError
highlight def link redifArgumentSecondaryDefunct redifError
highlight def link redifArgumentTertiaryDefunct redifError

"    Emails:
syntax match redifArgumentAuthorEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentAuthorWorkplaceEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentContactEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentEditorEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentEditorWorkplaceEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentMaintainerEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentOrderEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentPrimaryEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentProviderEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentPublisherEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentQuaternaryEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentSecondaryEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentTertiaryEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifArgumentWorkplaceEmail /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectEmail contained display
syntax match redifCorrectEmail /\%(@\@!\S\)\+@\%(@\@!\S\)\+/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentAuthorEmail redifError
highlight def link redifArgumentAuthorWorkplaceEmail redifError
highlight def link redifArgumentContactEmail redifError
highlight def link redifArgumentEditorEmail redifError
highlight def link redifArgumentEditorWorkplaceEmail redifError
highlight def link redifArgumentEmail redifError
highlight def link redifArgumentMaintainerEmail redifError
highlight def link redifArgumentOrderEmail redifError
highlight def link redifArgumentPrimaryEmail redifError
highlight def link redifArgumentProviderEmail redifError
highlight def link redifArgumentPublisherEmail redifError
highlight def link redifArgumentQuaternaryEmail redifError
highlight def link redifArgumentSecondaryEmail redifError
highlight def link redifArgumentTertiaryEmail redifError
highlight def link redifArgumentWorkplaceEmail redifError

"    Language
"    Source: https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
syntax match redifArgumentLanguage /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectLanguage contained display
syntax match redifCorrectLanguage /\<\(aa\|ab\|af\|ak\|als\|am\|an\|ang\|ar\|arc\|as\|ast\|av\|ay\|az\|ba\|bar\|bat-smg\|bcl\|be\|be-x-old\|bg\|bh\|bi\|bm\|bn\|bo\|bpy\|br\|bs\|bug\|bxr\|ca\|ce\|ceb\|ch\|cho\|chr\|chy\|co\|cr\|cs\|csb\|cu\|cv\|cy\|da\|de\|diq\|dsb\|dv\|dz\|ee\|el\|en\|eo\|es\|et\|eu\|ext\|fa\|ff\|fi\|fiu-vro\|fj\|fo\|fr\|frp\|fur\|fy\|ga\|gd\|gil\|gl\|gn\|got\|gu\|gv\|ha\|haw\|he\|hi\|ho\|hr\|ht\|hu\|hy\|hz\|ia\|id\|ie\|ig\|ii\|ik\|ilo\|io\|is\|it\|iu\|ja\|jbo\|jv\|ka\|kg\|ki\|kj\|kk\|kl\|km\|kn\|khw\|ko\|kr\|ks\|ksh\|ku\|kv\|kw\|ky\|la\|lad\|lan\|lb\|lg\|li\|lij\|lmo\|ln\|lo\|lt\|lv\|map-bms\|mg\|mh\|mi\|mk\|ml\|mn\|mo\|mr\|ms\|mt\|mus\|my\|na\|nah\|nap\|nd\|nds\|nds-nl\|ne\|new\|ng\|nl\|nn\|no\|nr\|nso\|nrm\|nv\|ny\|oc\|oj\|om\|or\|os\|pa\|pag\|pam\|pap\|pdc\|pi\|pih\|pl\|pms\|ps\|pt\|qu\|rm\|rmy\|rn\|ro\|roa-rup\|ru\|rw\|sa\|sc\|scn\|sco\|sd\|se\|sg\|sh\|si\|simple\|sk\|sl\|sm\|sn\|so\|sq\|sr\|ss\|st\|su\|sv\|sw\|ta\|te\|tet\|tg\|th\|ti\|tk\|tl\|tlh\|tn\|to\|tpi\|tr\|ts\|tt\|tum\|tw\|ty\|udm\|ug\|uk\|ur\|uz\|ve\|vi\|vec\|vls\|vo\|wa\|war\|wo\|xal\|xh\|yi\|yo\|za\|zh\|zh-min-nan\|zh-yue\|zu\)\>/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentLanguage redifError
highlight def link redifCorrectLanguage redifSpecial

"    Length
"    Based on the example in the documentation. But apparently any field is
"    possible
syntax region redifArgumentLength start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=redifGoodLength contained
syntax match redifGoodLength /1 page\|[1-9]\d*\%( pages\)\=/ contained display

highlight def link redifGoodLength redifSpecial

"    Publication-Type
syntax match redifArgumentPublicationType /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectPublicationType contained display
syntax match redifCorrectPublicationType /\<\(journal article\|book\|book chapter\|working paper\|conference paper\|report\|other\)\>/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentPublicationType redifError
highlight def link redifCorrectPublicationType redifSpecial

"    Publication-Status
syntax region redifArgumentPublicationStatus start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=redifSpecialPublicationStatus contained
syntax match redifSpecialPublicationStatus /published\|forthcoming/ nextgroup=redifCorrectPublicationStatus contained display
syntax region redifCorrectPublicationStatus start=/./ end=/^\S\{-}:/me=s-1 contained

highlight def link redifArgumentPublicationStatus redifError
highlight def link redifSpecialPublicationStatus redifSpecial

"    Month
"    TODO Are numbers also allowed?
syntax match redifArgumentMonth /\%(^\S\{-}:\)\@!\S.*/ contains=redifGoodMonth contained display
syntax match redifGoodMonth /\<\(Jan\%(uary\)\=\|Feb\%(ruary\)\=\|Mar\%(ch\)\=\|Apr\%(il\)\=\|May\|June\=\|July\=\|Aug\%(ust\)\=\|Sep\%(tember\)\=\|Oct\%(ober\)\=\|Nov\%(ember\)\=\|Dec\%(ember\)\=\)\>/ contained display

highlight def link redifGoodMonth redifSpecial

"    Integers: Volume, Chapter
syntax match redifArgumentVolume /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectInteger contained display
syntax match redifArgumentChapter /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectInteger contained display
syntax match redifCorrectInteger /[1-9]\d*/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentVolume redifError
highlight def link redifArgumentChapter redifError

"    Year
syntax match redifArgumentYear /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectYear contained display
syntax match redifCorrectYear /[1-9]\d\{3}/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentYear redifError

"    Edition
"    Based on the example in the documentation.
syntax match redifArgumentEdition /\%(^\S\{-}:\)\@!\S.*/ contains=redifGoodEdition contained display
syntax match redifGoodEdition /1st\|2nd\|3rd\|[4-9]th\|[1-9]\d*\%(1st\|2nd\|3rd\|[4-9]th\)\|[1-9]\d*/ contained display

highlight def link redifGoodEdition redifSpecial

"    ISBN
syntax match redifArgumentISBN /\%(^\S\{-}:\)\@!\S.*/ contains=redifGoodISBN contained display
syntax match redifGoodISBN /\d[0-9-]\{8,15}\d/ contained display

highlight def link redifGoodISBN redifSpecial

"    ISSN
syntax match redifArgumentISSN /\%(^\S\{-}:\)\@!\S.*/ contains=redifGoodISSN contained display
syntax match redifGoodISSN /\d\{4}-\d\{3}[0-9X]/ contained display

highlight def link redifGoodISSN redifSpecial

"    File-Size
"    Based on the example in the documentation.
syntax region redifArgumentFileSize start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=redifGoodSize contained
syntax match redifGoodSize /kb\|bytes/ contained display

highlight def link redifGoodSize redifSpecial

"    Type
syntax match redifArgumentType /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectType contained display
syntax match redifCorrectType /ReDIF-Paper\|ReDIF-Software\|ReDIF-Article\|ReDIF-Chapter\|ReDIF-Book/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentType redifError
highlight def link redifCorrectType redifSpecial

"    Dates: Publication-Date, Creation-Date, Revision-Date,
"    Last-Login-Date, Registration-Date
syntax match redifArgumentCreationDate /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectDate contained display
syntax match redifArgumentLastLoginDate /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectDate contained display
syntax match redifArgumentPublicationDate /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectDate contained display
syntax match redifArgumentRegisteredDate /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectDate contained display
syntax match redifArgumentRevisionDate /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectDate contained display
syntax match redifCorrectDate /[1-9]\d\{3}\%(-02\%(-[12]\d\|-0[1-9]\)\=\|-\%(0[469]\|11\)\%(-30\|-[12]\d\|-0[1-9]\)\=\|-\%(0[13578]\|1[02]\)\%(-3[01]\|-[12]\d\|-0[1-9]\)\=\)\=/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentCreationDate redifError
highlight def link redifArgumentLastLoginDate redifError
highlight def link redifArgumentPublicationDate redifError
highlight def link redifArgumentRegisteredDate redifError
highlight def link redifArgumentRevisionDate redifError

"    Classification-JEL
syntax match redifArgumentClassificationJEL /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectJEL contained display
syntax match redifCorrectJEL /\<\%(\u\d\{,2}[,; \t]\s*\)*\u\d\{,2}/ contains=redifSpecialJEL nextgroup=redifWrongLineEnding contained display
syntax match redifSpecialJEL /\<\u\d\{,2}/ contained display

highlight def link redifArgumentClassificationJEL redifError
highlight def link redifSpecialJEL redifSpecial

"    Pages
syntax match redifArgumentPages /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectPages contained display
syntax match redifCorrectPages /[1-9]\d*-[1-9]\d*/ nextgroup=redifWrongLineEnding contained display

highlight def link redifArgumentPages redifError

"    Name-ASCII
syntax match redifArgumentNameASCII /\%(^\S\{-}:\)\@!\S.*/ contains=redifCorrectNameASCII contained display
syntax match redifCorrectNameASCII /[ -~]/ contained display

highlight def link redifArgumentNameASCII redifError

"    Programming-Language
syntax match redifArgumentProgrammingLanguage /\%(^\S\{-}:\)\@!\S.*/ contains=redifGoodProgrammingLanguage contained display
syntax match redifGoodProgrammingLanguage /\<c++\|\<\%(c\|dos executable\|executable\|fortran\|gauss\|gretl\|java\|mathematica\|matlab\|octave\|ox\|perl\|python\|rats\|r\|shazam\|s-plus\|stata\|tsp international\)\>/ nextgroup=redifWrongLineEnding contained display

highlight def link redifGoodProgrammingLanguage redifSpecial

"    File-Format
"    TODO The link in the documentation that gives the list of possible formats is broken.
"    ftp://ftp.isi.edu/in-notes/iana/assignments/media-types/media-types
"    These are based on the examples in the documentation.
syntax match redifArgumentFileFormat /\%(^\S\{-}:\)\@!\S.*/ contains=redifGoodFormat contained display
syntax match redifGoodFormat "\a\+/[[:alpha:]+-]\+" nextgroup=redifWrongLineEnding contains=redifSpecialFormat contained display
syntax match redifSpecialFormat "application/atom+xml\|application/ecmascript\|application/EDI-X12\|application/EDIFACT\|application/json\|application/javascript\|application/octet-stream\|application/ogg\|application/pdf\|application/postscript\|application/rdf+xml\|application/rss+xml\|application/soap+xml\|application/font-woff\|application/xhtml+xml\|application/xml\|application/xml-dtd\|application/xop+xml\|application/zip\|application/gzip\|audio/basic\|audio/L24\|audio/mp4\|audio/mpeg\|audio/ogg\|audio/vorbis\|audio/vnd.rn-realaudio\|audio/vnd.wave\|audio/webm\|image/gif\|image/jpeg\|image/pjpeg\|image/png\|image/svg+xml\|image/tiff\|image/vnd.microsoft.icon\|message/http\|message/imdn+xml\|message/partial\|message/rfc822\|model/example\|model/iges\|model/mesh\|model/vrml\|model/x3d+binary\|model/x3d+vrml\|model/x3d+xml\|multipart/mixed\|multipart/alternative\|multipart/related\|multipart/form-data\|multipart/signed\|multipart/encrypted\|text/cmd\|text/css\|text/csv\|text/html\|text/javascript\|text/plain\|text/vcard\|text/xml\|video/mpeg\|video/mp4\|video/ogg\|video/quicktime\|video/webm\|video/x-matroska\|video/x-ms-wmv\|video/x-flv" contained display

highlight def link redifSpecialFormat redifSpecial
highlight def link redifArgumentFileFormat redifError

" Keywords
"     Spell checked
syntax match redifArgumentKeywords /\%(^\S\{-}:\)\@!\S.*/ contains=@Spell,redifKeywordsSemicolon contained
syntax match redifKeywordsSemicolon /;/ contained

highlight def link redifKeywordsSemicolon redifSpecial

" Other spell-checked arguments
"    Very useful when copy-pasting abstracts that may contain hyphens or
"    ligatures.
syntax region redifArgumentAbstract start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=@Spell contained
syntax region redifArgumentAvailability start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=@Spell contained
syntax region redifArgumentBookTitle start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=@Spell contained
syntax region redifArgumentDescription start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=@Spell contained
syntax region redifArgumentFileRestriction start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=@Spell contained
syntax region redifArgumentNote start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=@Spell contained
syntax region redifArgumentNotification start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=@Spell contained
syntax region redifArgumentRestriction start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=@Spell contained
syntax region redifArgumentTitle start=/\%(^\S\{-}:\)\@!\S/ end=/^\S\{-}:/me=s-1 contains=@Spell contained

" Wrong line ending
syntax match redifWrongLineEnding /.\+/ contained display

highlight def link redifWrongLineEnding redifError

" Final highlight
highlight def link redifComment Comment
highlight def link redifError Error
highlight def link redifField Identifier
highlight def link redifFieldDeprecated Identifier
highlight def link redifSpecial Special
" For deprecated fields:
highlight redifFieldDeprecated term=undercurl cterm=undercurl gui=undercurl guisp=DarkGrey

" Sync: The template-type (ReDIF-Paper, ReDIF-Archive, etc.) influences which
" fields can follow. Thus sync must search backwards for it.
"
" I would like to simply ask VIM to search backward for the first occurrence of
" /^Template-Type:/, but it does not seem to be possible, so I have to start
" from the beginning of the file... This might slow down a lot for files that
" contain a lot of Template-Type statements.
syntax sync fromstart

" The problem with syntax sync match (tried below), it is that, for example,
" it cannot realize when it is inside a Author-Name cluster, which is inside a
" Template-Type template...
"
" TODO Is this linecont pattern really useful? It seems to work anyway...
"syntax sync linecont /^\(Template-Type:\)\=\s*$/
" TODO This sync is surprising... It seems to work on several lines even
" though I replaced \_s* by \s*, even without the linecont pattern...
"syntax sync match redifSyncForTemplatePaper groupthere redifRegionTemplatePaper /^Template-Type:\s*ReDIF-Paper \d\+\.\d\+/
"syntax sync match redifSyncForTemplateArticle groupthere redifRegionTemplateArticle /^Template-Type:\s*ReDIF-Article \d\+\.\d\+/
"syntax sync match redifSyncForTemplateChapter groupthere redifRegionTemplateChapter /^Template-Type:\s*ReDIF-Chapter \d\+\.\d\+/
"syntax sync match redifSyncForTemplateBook groupthere redifRegionTemplateBook /^Template-Type:\s*ReDIF-Book \d\+\.\d\+/
"syntax sync match redifSyncForTemplateSoftware groupthere redifRegionTemplateSoftware /^Template-Type:\s*ReDIF-Software \d\+\.\d\+/
"syntax sync match redifSyncForTemplateArchive groupthere redifRegionTemplateArchive /^Template-Type:\s*ReDIF-Archive \d\+\.\d\+/
"syntax sync match redifSyncForTemplateSeries groupthere redifRegionTemplateSeries /^Template-Type:\s*ReDIF-Series \d\+\.\d\+/
"syntax sync match redifSyncForTemplateInstitution groupthere redifRegionTemplateInstitution /^Template-Type:\s*ReDIF-Institution \d\+\.\d\+/
"syntax sync match redifSyncForTemplatePerson groupthere redifRegionTemplatePerson /^Template-Type:\s*ReDIF-Person \d\+\.\d\+/

" I do not really know how sync linebreaks works, but it helps when making
" changes on the argument when this argument is not on the same line than its
" field. I just assume that people won't leave more than one line of
" whitespace between fields and arguments (which is already very unlikely)
" hence the value of 2.
syntax sync linebreaks=2

" Since folding is defined by the syntax, set foldmethod to syntax.
set foldmethod=syntax

" Set "b:current_syntax" to the name of the syntax at the end:
let b:current_syntax="redif"
