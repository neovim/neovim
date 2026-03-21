" Vim syntax file
" Language:     Power Query M
" Maintainer:   Anarion Dunedain <anarion80@gmail.com>
" Last Change:
"   2025 Apr 03  First version

" quit when a syntax file was already loaded
if exists("b:current_syntax")
        finish
endif

let s:keepcpo = &cpo
set cpo&vim

" There are Power Query functions with dot or hash in the name
setlocal iskeyword+=.
setlocal iskeyword+=#

setlocal foldmethod=syntax
setlocal foldtext=getline(v:foldstart)

" DAX is case sensitive
syn case match

" Any Power Query identifier
syn match pqIdentifier "\<[a-zA-Z0-9$_#]*\>"

" Fold on parenthesis
syn region pqParenthesisFold start="(" end=")" transparent fold

" Power Query keywords
syn keyword pqKeyword section sections shared
syn region pqKeyword start="\<let\>\c" end="\<in\>\c\%(\_s*$\)"me=s-2 transparent fold keepend containedin=ALLBUT,pqString,pqComment

" Power Query types
syn keyword pqType null logical number time date datetime datetimezone duration text binary type list record table function anynonnull none

" Power Query conditionals
syn keyword pqConditional if then else each

" Power Query constants
syn keyword pqConstant
  \ Number.E Number.Epsilon Number.NaN
  \ Number.NegativeInfinity Number.PI Number.PositiveInfinity

" TODO
syn keyword pqTodo FIXME NOTE TODO OPTIMIZE XXX HACK contained

" Numbers
" integer number, or floating point number without a dot.
syn match pqNumber "\<\d\+\>"
" floating point number, with dot
syn match pqNumber "\<\d\+\.\d*\>"

syn match pqFloat "[-+]\=\<\d\+[eE][\-+]\=\d\+"
syn match pqFloat "[-+]\=\<\d\+\.\d*\([eE][\-+]\=\d\+\)\="
syn match pqFloat "[-+]\=\<\.\d\+\([eE][\-+]\=\d\+\)\="

" String and Character constants
syn region pqString start=+"+  end=+"+

" Power Query Record
syn region pqRecord matchgroup=pqParen start=/\[/ end=/\]/ contains=ALLBUT,pqIdentifier

" Power Query List
syn region pqList matchgroup=pqParen start=/{/ end=/}/ contains=ALLBUT,pqIdentifier

" Operators
syn match pqOperator "+"
syn match pqOperator "-"
syn match pqOperator "*"
syn match pqOperator "/"
syn match pqOperator "\<\(NOT\|AND\|OR\|AS\|IS\|META\)\>\c"
syn match pqOperator "??"
syn match pqOperator "&&"
syn match pqOperator "&"
syn match pqOperator "[<>]=\="
syn match pqOperator "<>"
syn match pqOperator "="
syn match pqOperator ">"
syn match pqOperator "<"

" Comments
syn region pqComment start="\(^\|\s\)\//"   end="$" contains=pqTodo
syn region pqComment start="/\*"  end="\*/" contains=pqTodo

" Power Query functions
syn keyword pqFunction
  \ #binary #date #datetime #datetimezone #duration #table #time
  \ Access.Database AccessControlEntry.ConditionToIdentities Action.WithErrorContext
  \ ActiveDirectory.Domains AdoDotNet.DataSource AdoDotNet.Query AdobeAnalytics.Cubes
  \ AnalysisServices.Database AnalysisServices.Databases AzureStorage.BlobContents
  \ AzureStorage.Blobs AzureStorage.DataLake AzureStorage.DataLakeContents
  \ AzureStorage.Tables Binary.ApproximateLength Binary.Buffer
  \ Binary.Combine Binary.Compress Binary.Decompress
  \ Binary.From Binary.FromList Binary.FromText
  \ Binary.InferContentType Binary.Length Binary.Range
  \ Binary.Split Binary.ToList Binary.ToText
  \ Binary.View Binary.ViewError Binary.ViewFunction
  \ BinaryFormat.7BitEncodedSignedInteger BinaryFormat.7BitEncodedUnsignedInteger BinaryFormat.Binary
  \ BinaryFormat.Byte BinaryFormat.ByteOrder BinaryFormat.Choice
  \ BinaryFormat.Decimal BinaryFormat.Double BinaryFormat.Group
  \ BinaryFormat.Length BinaryFormat.List BinaryFormat.Null
  \ BinaryFormat.Record BinaryFormat.SignedInteger16 BinaryFormat.SignedInteger32
  \ BinaryFormat.SignedInteger64 BinaryFormat.Single BinaryFormat.Text
  \ BinaryFormat.Transform BinaryFormat.UnsignedInteger16 BinaryFormat.UnsignedInteger32
  \ BinaryFormat.UnsignedInteger64 Byte.From Byte.Type Cdm.Contents
  \ Character.FromNumber Character.ToNumber Combiner.CombineTextByDelimiter
  \ Combiner.CombineTextByEachDelimiter Combiner.CombineTextByLengths Combiner.CombineTextByPositions
  \ Combiner.CombineTextByRanges Comparer.Equals Comparer.FromCulture
  \ Comparer.Ordinal Comparer.OrdinalIgnoreCase Csv.Document
  \ Cube.AddAndExpandDimensionColumn Cube.AddMeasureColumn Cube.ApplyParameter
  \ Cube.AttributeMemberId Cube.AttributeMemberProperty Cube.CollapseAndRemoveColumns
  \ Cube.Dimensions Cube.DisplayFolders Cube.MeasureProperties
  \ Cube.MeasureProperty Cube.Measures Cube.Parameters
  \ Cube.Properties Cube.PropertyKey Cube.ReplaceDimensions
  \ Cube.Transform Currency.From Currency.Type DB2.Database
  \ Date.AddDays Date.AddMonths Date.AddQuarters
  \ Date.AddWeeks Date.AddYears Date.Day
  \ Date.DayOfWeek Date.DayOfWeekName Date.DayOfYear
  \ Date.DaysInMonth Date.EndOfDay Date.EndOfMonth
  \ Date.EndOfQuarter Date.EndOfWeek Date.EndOfYear
  \ Date.From Date.FromText Date.IsInCurrentDay
  \ Date.IsInCurrentMonth Date.IsInCurrentQuarter Date.IsInCurrentWeek
  \ Date.IsInCurrentYear Date.IsInNextDay Date.IsInNextMonth
  \ Date.IsInNextNDays Date.IsInNextNMonths Date.IsInNextNQuarters
  \ Date.IsInNextNWeeks Date.IsInNextNYears Date.IsInNextQuarter
  \ Date.IsInNextWeek Date.IsInNextYear Date.IsInPreviousDay
  \ Date.IsInPreviousMonth Date.IsInPreviousNDays Date.IsInPreviousNMonths
  \ Date.IsInPreviousNQuarters Date.IsInPreviousNWeeks Date.IsInPreviousNYears
  \ Date.IsInPreviousQuarter Date.IsInPreviousWeek Date.IsInPreviousYear
  \ Date.IsInYearToDate Date.IsLeapYear Date.Month
  \ Date.MonthName Date.QuarterOfYear Date.StartOfDay
  \ Date.StartOfMonth Date.StartOfQuarter Date.StartOfWeek
  \ Date.StartOfYear Date.ToRecord Date.ToText
  \ Date.WeekOfMonth Date.WeekOfYear Date.Year
  \ DateTime.AddZone DateTime.Date DateTime.FixedLocalNow
  \ DateTime.From DateTime.FromFileTime DateTime.FromText
  \ DateTime.IsInCurrentHour DateTime.IsInCurrentMinute DateTime.IsInCurrentSecond
  \ DateTime.IsInNextHour DateTime.IsInNextMinute DateTime.IsInNextNHours
  \ DateTime.IsInNextNMinutes DateTime.IsInNextNSeconds DateTime.IsInNextSecond
  \ DateTime.IsInPreviousHour DateTime.IsInPreviousMinute DateTime.IsInPreviousNHours
  \ DateTime.IsInPreviousNMinutes DateTime.IsInPreviousNSeconds DateTime.IsInPreviousSecond
  \ DateTime.LocalNow DateTime.Time DateTime.ToRecord
  \ DateTime.ToText DateTimeZone.FixedLocalNow DateTimeZone.FixedUtcNow
  \ DateTimeZone.From DateTimeZone.FromFileTime DateTimeZone.FromText
  \ DateTimeZone.LocalNow DateTimeZone.RemoveZone DateTimeZone.SwitchZone
  \ DateTimeZone.ToLocal DateTimeZone.ToRecord DateTimeZone.ToText
  \ DateTimeZone.ToUtc DateTimeZone.UtcNow DateTimeZone.ZoneHours
  \ DateTimeZone.ZoneMinutes Decimal.From Decimal.Type DeltaLake.Metadata
  \ DeltaLake.Table Diagnostics.ActivityId Diagnostics.CorrelationId
  \ Diagnostics.Trace DirectQueryCapabilities.From Double.From Double.Type
  \ Duration.Days Duration.From Duration.FromText
  \ Duration.Hours Duration.Minutes Duration.Seconds
  \ Duration.ToRecord Duration.ToText Duration.TotalDays
  \ Duration.TotalHours Duration.TotalMinutes Duration.TotalSeconds
  \ Embedded.Value Error.Record Essbase.Cubes
  \ Excel.CurrentWorkbook Excel.ShapeTable Excel.Workbook
  \ Exchange.Contents Expression.Constant Expression.Evaluate
  \ Expression.Identifier File.Contents Folder.Contents
  \ Folder.Files Function.From Function.Invoke
  \ Function.InvokeAfter Function.InvokeWithErrorContext Function.IsDataSource
  \ Function.ScalarVector Geography.FromWellKnownText Geography.ToWellKnownText
  \ GeographyPoint.From Geometry.FromWellKnownText Geometry.ToWellKnownText
  \ GeometryPoint.From GoogleAnalytics.Accounts Graph.Nodes
  \ Guid.From Guid.Type HdInsight.Containers HdInsight.Contents
  \ HdInsight.Files Hdfs.Contents Hdfs.Files
  \ Html.Table Identity.From Identity.IsMemberOf
  \ IdentityProvider.Default Informix.Database Int16.From Int16.Type
  \ Int32.From Int32.Type Int64.From Int64.Type Int8.From Int8.Type
  \ ItemExpression.From ItemExpression.Item Json.Document
  \ Json.FromValue Json.FromValue Lines.FromBinary
  \ Lines.FromText Lines.ToBinary Lines.ToText
  \ List.Accumulate List.AllTrue List.Alternate
  \ List.AnyTrue List.Average List.Buffer
  \ List.Combine List.ConformToPageReader List.Contains
  \ List.ContainsAll List.ContainsAny List.Count
  \ List.Covariance List.DateTimeZones List.DateTimes
  \ List.Dates List.Difference List.Distinct
  \ List.Durations List.FindText List.First
  \ List.FirstN List.Generate List.InsertRange
  \ List.Intersect List.IsDistinct List.IsEmpty
  \ List.Last List.LastN List.MatchesAll
  \ List.MatchesAny List.Max List.MaxN
  \ List.Median List.Min List.MinN
  \ List.Mode List.Modes List.NonNullCount
  \ List.Numbers List.Percentile List.PositionOf
  \ List.PositionOfAny List.Positions List.Product
  \ List.Random List.Range List.RemoveFirstN
  \ List.RemoveItems List.RemoveLastN List.RemoveMatchingItems
  \ List.RemoveNulls List.RemoveRange List.Repeat
  \ List.ReplaceMatchingItems List.ReplaceRange List.ReplaceValue
  \ List.Reverse List.Select List.Single
  \ List.SingleOrDefault List.Skip List.Sort
  \ List.Split List.StandardDeviation List.Sum
  \ List.Times List.Transform List.TransformMany
  \ List.Union List.Zip Logical.From
  \ Logical.FromText Logical.ToText Module.Versions
  \ MySQL.Database Number.Abs Number.Acos
  \ Number.Asin Number.Atan Number.Atan2
  \ Number.BitwiseAnd Number.BitwiseNot Number.BitwiseOr
  \ Number.BitwiseShiftLeft Number.BitwiseShiftRight Number.BitwiseXor
  \ Number.Combinations Number.Cos Number.Cosh
  \ Number.Exp Number.Factorial Number.From
  \ Number.FromText Number.IntegerDivide Number.IsEven
  \ Number.IsNaN Number.IsOdd Number.Ln
  \ Number.Log Number.Log10 Number.Mod
  \ Number.Permutations Number.Power Number.Random
  \ Number.RandomBetween Number.Round Number.RoundAwayFromZero
  \ Number.RoundDown Number.RoundTowardZero Number.RoundUp
  \ Number.Sign Number.Sin Number.Sinh
  \ Number.Sqrt Number.Tan Number.Tanh
  \ Number.ToText Number.Type OData.Feed Odbc.DataSource
  \ Odbc.InferOptions Odbc.Query OleDb.DataSource
  \ OleDb.Query Oracle.Database Pdf.Tables
  \ Percentage.From Percentage.Type PostgreSQL.Database Progress.DataSourceProgress
  \ RData.FromBinary Record.AddField Record.Combine
  \ Record.Field Record.FieldCount Record.FieldNames
  \ Record.FieldOrDefault Record.FieldValues Record.FromList
  \ Record.FromTable Record.HasFields Record.RemoveFields
  \ Record.RenameFields Record.ReorderFields Record.SelectFields
  \ Record.ToList Record.ToTable Record.TransformFields Record.Type
  \ Replacer.ReplaceText Replacer.ReplaceValue RowExpression.Column
  \ RowExpression.From RowExpression.Row Salesforce.Data
  \ Salesforce.Reports SapBusinessWarehouse.Cubes SapHana.Database
  \ SharePoint.Contents SharePoint.Files SharePoint.Tables
  \ Single.From Single.Type Soda.Feed Splitter.SplitByNothing
  \ Splitter.SplitTextByAnyDelimiter Splitter.SplitTextByCharacterTransition Splitter.SplitTextByDelimiter
  \ Splitter.SplitTextByEachDelimiter Splitter.SplitTextByLengths Splitter.SplitTextByPositions
  \ Splitter.SplitTextByRanges Splitter.SplitTextByRepeatedLengths Splitter.SplitTextByWhitespace
  \ Sql.Database Sql.Databases SqlExpression.SchemaFrom
  \ SqlExpression.ToExpression Sybase.Database Table.AddColumn
  \ Table.AddFuzzyClusterColumn Table.AddIndexColumn Table.AddJoinColumn
  \ Table.AddKey Table.AddRankColumn Table.AggregateTableColumn
  \ Table.AlternateRows Table.ApproximateRowCount Table.Buffer
  \ Table.Column Table.ColumnCount Table.ColumnNames
  \ Table.ColumnsOfType Table.Combine Table.CombineColumns
  \ Table.CombineColumnsToRecord Table.ConformToPageReader Table.Contains
  \ Table.ContainsAll Table.ContainsAny Table.DemoteHeaders
  \ Table.Distinct Table.DuplicateColumn Table.ExpandListColumn
  \ Table.ExpandRecordColumn Table.ExpandTableColumn Table.FillDown
  \ Table.FillUp Table.FilterWithDataTable Table.FindText
  \ Table.First Table.FirstN Table.FirstValue
  \ Table.FromColumns Table.FromList Table.FromPartitions
  \ Table.FromRecords Table.FromRows Table.FromValue
  \ Table.FuzzyGroup Table.FuzzyJoin Table.FuzzyNestedJoin
  \ Table.Group Table.HasColumns Table.InsertRows
  \ Table.IsDistinct Table.IsEmpty Table.Join
  \ Table.Keys Table.Last Table.LastN
  \ Table.MatchesAllRows Table.MatchesAnyRows Table.Max
  \ Table.MaxN Table.Min Table.MinN
  \ Table.NestedJoin Table.Partition Table.PartitionValues
  \ Table.PartitionValues Table.Pivot Table.PositionOf
  \ Table.PositionOfAny Table.PrefixColumns Table.Profile
  \ Table.PromoteHeaders Table.Range Table.RemoveColumns
  \ Table.RemoveFirstN Table.RemoveLastN Table.RemoveMatchingRows
  \ Table.RemoveRows Table.RemoveRowsWithErrors Table.RenameColumns
  \ Table.ReorderColumns Table.Repeat Table.ReplaceErrorValues
  \ Table.ReplaceKeys Table.ReplaceMatchingRows Table.ReplaceRelationshipIdentity
  \ Table.ReplaceRows Table.ReplaceValue Table.ReverseRows
  \ Table.RowCount Table.Schema Table.SelectColumns
  \ Table.SelectRows Table.SelectRowsWithErrors Table.SingleRow
  \ Table.Skip Table.Sort Table.Split
  \ Table.SplitAt Table.SplitColumn Table.StopFolding
  \ Table.ToColumns Table.ToList Table.ToRecords
  \ Table.ToRows Table.TransformColumnNames Table.TransformColumnTypes
  \ Table.TransformColumns Table.TransformRows Table.Transpose
  \ Table.Unpivot Table.UnpivotOtherColumns Table.View
  \ Table.ViewError Table.ViewFunction Table.WithErrorContext
  \ Tables.GetRelationships Teradata.Database Text.AfterDelimiter
  \ Text.At Text.BeforeDelimiter Text.BetweenDelimiters
  \ Text.Clean Text.Combine Text.Contains
  \ Text.End Text.EndsWith Text.From
  \ Text.FromBinary Text.InferNumberType Text.Insert
  \ Text.Length Text.Lower Text.Middle
  \ Text.NewGuid Text.PadEnd Text.PadStart
  \ Text.PositionOf Text.PositionOfAny Text.Proper
  \ Text.Range Text.Remove Text.RemoveRange
  \ Text.Repeat Text.Replace Text.ReplaceRange
  \ Text.Reverse Text.Select Text.Split
  \ Text.SplitAny Text.Start Text.StartsWith
  \ Text.ToBinary Text.ToList Text.Trim
  \ Text.TrimEnd Text.TrimStart Text.Upper
  \ Time.EndOfHour Time.From Time.FromText
  \ Time.Hour Time.Minute Time.Second
  \ Time.StartOfHour Time.ToRecord Time.ToText
  \ Type.AddTableKey Type.ClosedRecord Type.Facets
  \ Type.ForFunction Type.ForRecord Type.FunctionParameters
  \ Type.FunctionRequiredParameters Type.FunctionReturn Type.Is
  \ Type.IsNullable Type.IsOpenRecord Type.ListItem
  \ Type.NonNullable Type.OpenRecord Type.RecordFields
  \ Type.ReplaceFacets Type.ReplaceTableKeys Type.TableColumn
  \ Type.TableKeys Type.TableRow Type.TableSchema
  \ Type.Union Uri.BuildQueryString Uri.Combine
  \ Uri.EscapeDataString Uri.Parts Value.Add
  \ Value.Alternates Value.As Value.Compare
  \ Value.Divide Value.Equals Value.Expression
  \ Value.Firewall Value.FromText Value.Is
  \ Value.Lineage Value.Metadata Value.Multiply
  \ Value.NativeQuery Value.NullableEquals Value.Optimize
  \ Value.RemoveMetadata Value.ReplaceMetadata Value.ReplaceType
  \ Value.Subtract Value.Traits Value.Type
  \ Value.VersionIdentity Value.Versions Value.ViewError
  \ Value.ViewFunction Variable.Value Web.BrowserContents
  \ Web.Contents Web.Headers Web.Page
  \ WebAction.Request Xml.Document Xml.Tables


" Fold on let/in
" syn region pqLetFold start="\<let\>\c" end="\<in\>\c" transparent fold

" Define highlighting
hi def link pqComment          Comment
hi def link pqNumber           Number
hi def link pqFloat            Float
hi def link pqString           String
hi def link pqKeyword          Keyword
hi def link pqOperator         Operator
hi def link pqFunction         Delimiter
hi def link pqTable            Number
hi def link pqRecord           Statement
hi def link pqList             Delimiter
hi def link pqParen            Delimiter
hi def link pqTodo             Todo
hi def link pqConditional      Conditional
hi def link pqNull             Const
hi def link pqType             Type
hi def link pqIdentifier       Number
hi def link pqConstant         Constant
hi def link pqLetFold          Constant

let b:current_syntax = "pq"

let &cpo = s:keepcpo
unlet! s:keepcpo

" vim: ts=8
