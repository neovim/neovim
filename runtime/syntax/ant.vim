" Vim syntax file
" Language:	ANT build file (xml)
" Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Tue Apr 27 13:05:59 CEST 2004
" Filenames:	build.xml
" $Id: ant.vim,v 1.1 2004/06/13 18:13:18 vimboss Exp $

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

let s:ant_cpo_save = &cpo
set cpo&vim

runtime! syntax/xml.vim

syn case ignore

if !exists('*AntSyntaxScript')
    fun AntSyntaxScript(tagname, synfilename)
	unlet b:current_syntax
	let s:include = expand("<sfile>:p:h").'/'.a:synfilename
	if filereadable(s:include)
	    exe 'syn include @ant'.a:tagname.' '.s:include
	else
	    exe 'syn include @ant'.a:tagname." $VIMRUNTIME/syntax/".a:synfilename
	endif

	exe 'syn region ant'.a:tagname
		    \." start=#<script[^>]\\{-}language\\s*=\\s*['\"]".a:tagname."['\"]\\(>\\|[^>]*[^/>]>\\)#"
		    \.' end=#</script>#'
		    \.' fold'
		    \.' contains=@ant'.a:tagname.',xmlCdataStart,xmlCdataEnd,xmlTag,xmlEndTag'
		    \.' keepend'
	exe 'syn cluster xmlRegionHook add=ant'.a:tagname
    endfun
endif

" TODO: add more script languages here ?
call AntSyntaxScript('javascript', 'javascript.vim')
call AntSyntaxScript('jpython', 'python.vim')


syn cluster xmlTagHook add=antElement

syn keyword antElement display WsdlToDotnet addfiles and ant antcall antstructure apply archives arg argument
syn keyword antElement display assertions attrib attribute available basename bcc blgenclient bootclasspath
syn keyword antElement display borland bottom buildnumber buildpath buildpathelement bunzip2 bzip2 cab
syn keyword antElement display catalogpath cc cccheckin cccheckout cclock ccmcheckin ccmcheckintask ccmcheckout
syn keyword antElement display ccmcreatetask ccmkattr ccmkbl ccmkdir ccmkelem ccmklabel ccmklbtype
syn keyword antElement display ccmreconfigure ccrmtype ccuncheckout ccunlock ccupdate checksum chgrp chmod
syn keyword antElement display chown classconstants classes classfileset classpath commandline comment
syn keyword antElement display compilerarg compilerclasspath concat concatfilter condition copy copydir
syn keyword antElement display copyfile coveragepath csc custom cvs cvschangelog cvspass cvstagdiff cvsversion
syn keyword antElement display daemons date defaultexcludes define delete deletecharacters deltree depend
syn keyword antElement display depends dependset depth description different dirname dirset disable dname
syn keyword antElement display doclet doctitle dtd ear echo echoproperties ejbjar element enable entity entry
syn keyword antElement display env equals escapeunicode exclude excludepackage excludesfile exec execon
syn keyword antElement display existing expandproperties extdirs extension extensionSet extensionset factory
syn keyword antElement display fail filelist filename filepath fileset filesmatch filetokenizer filter
syn keyword antElement display filterchain filterreader filters filterset filtersfile fixcrlf footer format
syn keyword antElement display from ftp generic genkey get gjdoc grant group gunzip gzip header headfilter http
syn keyword antElement display ignoreblank ilasm ildasm import importtypelib include includesfile input iplanet
syn keyword antElement display iplanet-ejbc isfalse isreference isset istrue jar jarlib-available
syn keyword antElement display jarlib-manifest jarlib-resolve java javac javacc javadoc javadoc2 jboss jdepend
syn keyword antElement display jjdoc jjtree jlink jonas jpcoverage jpcovmerge jpcovreport jsharpc jspc
syn keyword antElement display junitreport jvmarg lib libfileset linetokenizer link loadfile loadproperties
syn keyword antElement display location macrodef mail majority manifest map mapper marker mergefiles message
syn keyword antElement display metainf method mimemail mkdir mmetrics modified move mparse none not options or
syn keyword antElement display os outputproperty package packageset parallel param patch path pathconvert
syn keyword antElement display pathelement patternset permissions prefixlines present presetdef project
syn keyword antElement display property propertyfile propertyref propertyset pvcs pvcsproject record reference
syn keyword antElement display regexp rename renameext replace replacefilter replaceregex replaceregexp
syn keyword antElement display replacestring replacetoken replacetokens replacevalue replyto report resource
syn keyword antElement display revoke rmic root rootfileset rpm scp section selector sequential serverdeploy
syn keyword antElement display setproxy signjar size sleep socket soscheckin soscheckout sosget soslabel source
syn keyword antElement display sourcepath sql src srcfile srcfilelist srcfiles srcfileset sshexec stcheckin
syn keyword antElement display stcheckout stlabel stlist stringtokenizer stripjavacomments striplinebreaks
syn keyword antElement display striplinecomments style subant substitution support symlink sync sysproperty
syn keyword antElement display syspropertyset tabstospaces tag taglet tailfilter tar tarfileset target
syn keyword antElement display targetfile targetfilelist targetfileset taskdef tempfile test testlet text title
syn keyword antElement display to token tokenfilter touch transaction translate triggers trim tstamp type
syn keyword antElement display typedef unjar untar unwar unzip uptodate url user vbc vssadd vsscheckin
syn keyword antElement display vsscheckout vsscp vsscreate vssget vsshistory vsslabel waitfor war wasclasspath
syn keyword antElement display webapp webinf weblogic weblogictoplink websphere whichresource wlclasspath
syn keyword antElement display wljspc wsdltodotnet xmlcatalog xmlproperty xmlvalidate xslt zip zipfileset
syn keyword antElement display zipgroupfileset

hi def link antElement Statement

let b:current_syntax = "ant"

let &cpo = s:ant_cpo_save
unlet s:ant_cpo_save

" vim: ts=8
