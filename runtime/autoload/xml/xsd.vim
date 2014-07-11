" Author: Thomas Barthel
" Last change: 2007 May 8
let g:xmldata_xsd = {
	\ 'schema': [
		\ [ 'include', 'import', 'redefine', 'annotation', 'simpleType', 'complexType', 'element', 'attribute', 'attributeGroup', 'group', 'notation', 'annotation'],
		\ { 'targetNamespace' : [], 'version' : [], 'xmlns' : [], 'finalDefault' : [], 'blockDefault' : [], 'id' : [], 'elementFormDefault' : [], 'attributeFormDefault' : [], 'xml:lang' : [] }],
	\ 'redefine' : [
		\ ['annotation', 'simpleType', 'complexType', 'attributeGroup', 'group'],
		\ {'schemaLocation' : [], 'id' : []} ],
	\ 'include' : [
		\ ['annotation'],
		\ {'namespace' : [], 'id' : []} ],
	\ 'import' : [
		\ ['annotation'],
		\ {'namespace' : [], 'schemaLocation' : [], 'id' : []} ],
	\ 'complexType' : [
		\ ['annotation', 'simpleContent', 'complexContent', 'all', 'choice', 'sequence', 'group', 'attribute', 'attributeGroup', 'anyAttribute'],
		\ {'name' : [], 'id' : [], 'abstract' : [], 'final' : [], 'block' : [], 'mixed' : []} ],
	\ 'complexContent' : [
		\ ['annotation', 'restriction', 'extension'],
		\ {'mixed' : [], 'id' : [] } ],
	\ 'simpleType' : [
		\ ['annotation', 'restriction', 'list', 'union'],
		\ {'name' : [], 'final' : [], 'id' : []} ],
	\ 'simpleContent' : [
		\ ['annotation', 'restriction', 'extension'],
		\ {'id' : []} ],
	\ 'element' : [
		\ ['annotation', 'complexType', 'simpleType', 'unique', 'key', 'keyref'],
		\ {'name' : [], 'id' : [], 'ref' : [], 'type' : [], 'minOccurs' : [], 'maxOccurs' : [], 'nillable' : [], 'substitutionGroup' : [], 'abstract' : [], 'final' : [], 'block' : [], 'default' : [], 'fixed' : [], 'form' : []} ],
	\ 'attribute' : [
		\ ['annotation', 'simpleType'],
		\ {'name' : [], 'id' : [], 'ref' : [], 'type' : [], 'use' : [], 'default' : [], 'fixed' : [], 'form' : []} ],
	\ 'group' : [
		\ ['annotation', 'all', 'choice', 'sequence'],
		\ {'name' : [], 'ref' : [], 'minOccurs' : [], 'maxOccurs' : [], 'id' : []} ],
	\ 'choice' : [
		\ ['annotation', 'element', 'group', 'choice', 'sequence', 'any'],
		\ {'minOccurs' : [], 'maxOccurs' : [], 'id' : []} ],
	\ 'sequence' : [
		\ ['annotation', 'element', 'group', 'choice', 'sequence', 'any'],
		\ {'minOccurs' : [], 'maxOccurs' : [], 'id' : []} ],
	\ 'all' : [
		\ ['annotation', 'element'],
		\ {'minOccurs' : [], 'maxOccurs' : [], 'id' : []} ],
	\ 'any' : [
		\ ['annotation'],
		\ {'namespace' : [], 'processContents' : [], 'minOccurs' : [], 'maxOccurs' : [], 'id' : []} ],
	\ 'unique' : [
		\ ['annotation', 'selector', 'field'],
		\ {'name' : [],  'id' : []} ],
	\ 'key' : [
		\ ['annotation', 'selector', 'field'],
		\ {'name' : [],  'id' : []} ],
	\ 'keyref' : [
		\ ['annotation', 'selector', 'field'],
		\ {'name' : [], 'refer' : [], 'id' : []} ],
	\ 'selector' : [
		\ ['annotation'],
		\ {'xpath' : [],  'id' : []} ],
	\ 'field' : [
		\ ['annotation'],
		\ {'xpath' : [],  'id' : []} ],
	\ 'restriction' : [
		\ ['annotation', 'simpleType', 'minExclusive', 'maxExclusive', 'minInclusive', 'maxInclusive', 'totalDigits', 'fractionDigits', 'length', 'minLength', 'maxLength', 'enumeration', 'whiteSpace', 'pattern'],
		\ {'base' : [], 'id' : []} ],
	\ 'minExclusive' : [
		\ ['annotation'],
		\ {'value' : [], 'id' : [], 'fixed' : []}],
	\ 'maxExclusive' : [
		\ ['annotation'],
		\ {'value' : [], 'id' : [], 'fixed' : []}],
	\ 'minInclusive' : [
		\ ['annotation'],
		\ {'value' : [], 'id' : [], 'fixed' : []}],
	\ 'maxInclusive' : [
		\ ['annotation'],
		\ {'value' : [], 'id' : [], 'fixed' : []}],
	\ 'totalDigits' : [		
	    \ ['annotation'],
		\ {'value' : [], 'id' : [], 'fixed' : []}],
	\ 'fractionDigits' : [
		\ ['annotation'],
		\ {'value' : [], 'id' : [], 'fixed' : []}],
     \ 'length' : [
     	\ ['annotation'],
     	\ {'value' : [], 'id' : [], 'fixed' : []}],
     \ 'minLength' : [
     	\ ['annotation'],
     	\ {'value' : [], 'id' : [], 'fixed' : []}],
     \ 'maxLength' : [
     	\ ['annotation'],
     	\ {'value' : [], 'id' : [], 'fixed' : []}],
     \ 'enumeration' : [
     	\ ['annotation'],
     	\ {'value' : [], 'id' : []}],
     \ 'whiteSpace' : [
     	\ ['annotation'],
     	\ {'value' : [], 'id' : [], 'fixed' : []}],
     \ 'pattern' : [
     	\ ['annotation'],
     	\ {'value' : [], 'id' : []}],
     \ 'extension' : [
     	\ ['annotation', 'all', 'choice', 'sequence', 'group', 'attribute', 'attributeGroup', 'anyAttribute'],
		\ {'base' : [], 'id' : []} ],
	 \ 'attributeGroup' : [
	 	\ ['annotation', 'attribute', 'attributeGroup', 'anyAttribute'],
	 	\ {'name' : [], 'id' : [], 'ref' : []} ],
	 \ 'anyAttribute' : [
	 	\ ['annotation'],
	 	\ {'namespace' : [], 'processContents' : [], 'id' : []} ],
	 \ 'list' : [
		\ ['annotation', 'simpleType'],
		\ {'itemType' : [], 'id' : []} ],
	 \ 'union' : [
	 	\ ['annotation', 'simpleType'],
	 	\ {'id' : [], 'memberTypes' : []} ],
	 \ 'notation' : [
	 	\ ['annotation'],
	 	\ {'name' : [], 'id' : [], 'public' : [], 'system' : []} ],
	 \ 'annotation' : [
	 	\ ['appinfo', 'documentation'],
	 	\ {} ],
	 \ 'appinfo' : [
	 	\ [],
	 	\ {'source' : [], 'id' : []} ],
	 \ 'documentation' : [
		\ [],
		\ {'source' : [], 'id' : [], 'xml' : []} ]
	\ }
