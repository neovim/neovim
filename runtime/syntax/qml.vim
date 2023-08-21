" Vim syntax file
" Language:     QML
" Previous Maintainer: Peter Hoeg <peter@hoeg.com>
" Maintainer:   Chase Knowlden <haroldknowlden@gmail.com>
" Changes:      `git log` is your friend
" Last Change:  2023 Aug 16
"
" This file is bassed on the original work done by Warwick Allison
" <warwick.allison@nokia.com> whose did about 99% of the work here.

" Based on javascript syntax (as is QML)

if exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'qml'
endif

" Drop fold if it set but vim doesn't support it.
if !has("folding")
  unlet! qml_fold
endif

syn case ignore

syn cluster qmlExpr              contains=qmlStringD,qmlStringS,qmlStringT,SqmlCharacter,qmlNumber,qmlObjectLiteralType,qmlBoolean,qmlType,qmlJsType,qmlNull,qmlGlobal,qmlFunction,qmlArrowFunction,qmlNullishCoalescing
syn keyword qmlCommentTodo       TODO FIXME XXX TBD contained
syn match   qmlLineComment       "\/\/.*" contains=@Spell,qmlCommentTodo
syn match   qmlCommentSkip       "^[ \t]*\*\($\|[ \t]\+\)"
syn region  qmlComment           start="/\*"  end="\*/" contains=@Spell,qmlCommentTodo fold
syn match   qmlSpecial           "\\\d\d\d\|\\."
syn region  qmlStringD           start=+"+  skip=+\\\\\|\\"\|\\$+  end=+"+  keepend  contains=qmlSpecial,@htmlPreproc,@Spell
syn region  qmlStringS           start=+'+  skip=+\\\\\|\\'\|\\$+  end=+'+  keepend  contains=qmlSpecial,@htmlPreproc,@Spell
syn region  qmlStringT           start=+`+  skip=+\\\\\|\\`\|\\$+  end=+`+  keepend  contains=qmlTemplateExpr,qmlSpecial,@htmlPreproc,@Spell

syntax region  qmlTemplateExpr contained  matchgroup=qmlBraces start=+${+ end=+}+  keepend  contains=@qmlExpr

syn match   qmlCharacter         "'\\.'"
syn match   qmlNumber            "-\=\<\d\+L\=\>\|0[xX][0-9a-fA-F]\+\>"
syn region  qmlRegexpString      start=+/[^/*]+me=e-1 skip=+\\\\\|\\/+ end=+/[gi]\{0,2\}\s*$+ end=+/[gi]\{0,2\}\s*[;.,)\]}]+me=e-1 contains=@htmlPreproc oneline
syn match   qmlObjectLiteralType "[A-Za-z][_A-Za-z0-9]*\s*\({\)\@="
syn region  qmlTernaryColon   start="?" end=":" contains=@qmlExpr,qmlBraces,qmlParens,qmlLineComment
syn match   qmlBindingProperty   "\<[A-Za-z][_A-Za-z.0-9]*\s*:"
syn match  qmlNullishCoalescing    "??"

syn keyword qmlConditional       if else switch
syn keyword qmlRepeat            while for do in
syn keyword qmlBranch            break continue
syn keyword qmlOperator          new delete instanceof typeof
syn keyword qmlJsType            Array Boolean Date Function Number Object String RegExp
syn keyword qmlType              action alias bool color date double enumeration font int list point real rect size string time url variant vector2d vector3d vector4d coordinate geocircle geopath geopolygon georectangle geoshape matrix4x4 palette quaternion
syn keyword qmlStatement         return with
syn keyword qmlBoolean           true false
syn keyword qmlNull              null undefined
syn keyword qmlIdentifier        arguments this var let const
syn keyword qmlLabel             case default
syn keyword qmlException         try catch finally throw
syn keyword qmlMessage           alert confirm prompt status
syn keyword qmlGlobal            self
syn keyword qmlDeclaration       property signal component readonly required
syn keyword qmlReserved          abstract boolean byte char class debugger enum export extends final float goto implements import interface long native package pragma private protected public short static super synchronized throws transient volatile

syn case match

" List extracted in alphabatical order from: https://doc.qt.io/qt-5/qmltypes.html
" Qt v5.15.1

" Begin Literal Types {{{

syntax keyword qmlObjectLiteralType Abstract3DSeries
syntax keyword qmlObjectLiteralType AbstractActionInput
syntax keyword qmlObjectLiteralType AbstractAnimation
syntax keyword qmlObjectLiteralType AbstractAxis
syntax keyword qmlObjectLiteralType AbstractAxis3D
syntax keyword qmlObjectLiteralType AbstractAxisInput
syntax keyword qmlObjectLiteralType AbstractBarSeries
syntax keyword qmlObjectLiteralType AbstractButton
syntax keyword qmlObjectLiteralType AbstractClipAnimator
syntax keyword qmlObjectLiteralType AbstractClipBlendNode
syntax keyword qmlObjectLiteralType AbstractDataProxy
syntax keyword qmlObjectLiteralType AbstractGraph3D
syntax keyword qmlObjectLiteralType AbstractInputHandler3D
syntax keyword qmlObjectLiteralType AbstractPhysicalDevice
syntax keyword qmlObjectLiteralType AbstractRayCaster
syntax keyword qmlObjectLiteralType AbstractSeries
syntax keyword qmlObjectLiteralType AbstractSkeleton
syntax keyword qmlObjectLiteralType AbstractTexture
syntax keyword qmlObjectLiteralType AbstractTextureImage
syntax keyword qmlObjectLiteralType Accelerometer
syntax keyword qmlObjectLiteralType AccelerometerReading
syntax keyword qmlObjectLiteralType Accessible
syntax keyword qmlObjectLiteralType Action
syntax keyword qmlObjectLiteralType ActionGroup
syntax keyword qmlObjectLiteralType ActionInput
syntax keyword qmlObjectLiteralType AdditiveClipBlend
syntax keyword qmlObjectLiteralType AdditiveColorGradient
syntax keyword qmlObjectLiteralType Address
syntax keyword qmlObjectLiteralType Affector
syntax keyword qmlObjectLiteralType Age
syntax keyword qmlObjectLiteralType AlphaCoverage
syntax keyword qmlObjectLiteralType AlphaTest
syntax keyword qmlObjectLiteralType Altimeter
syntax keyword qmlObjectLiteralType AltimeterReading
syntax keyword qmlObjectLiteralType AluminumAnodizedEmissiveMaterial
syntax keyword qmlObjectLiteralType AluminumAnodizedMaterial
syntax keyword qmlObjectLiteralType AluminumBrushedMaterial
syntax keyword qmlObjectLiteralType AluminumEmissiveMaterial
syntax keyword qmlObjectLiteralType AluminumMaterial
syntax keyword qmlObjectLiteralType AmbientLightReading
syntax keyword qmlObjectLiteralType AmbientLightSensor
syntax keyword qmlObjectLiteralType AmbientTemperatureReading
syntax keyword qmlObjectLiteralType AmbientTemperatureSensor
syntax keyword qmlObjectLiteralType AnalogAxisInput
syntax keyword qmlObjectLiteralType AnchorAnimation
syntax keyword qmlObjectLiteralType AnchorChanges
syntax keyword qmlObjectLiteralType AngleDirection
syntax keyword qmlObjectLiteralType AnimatedImage
syntax keyword qmlObjectLiteralType AnimatedSprite
syntax keyword qmlObjectLiteralType Animation
syntax keyword qmlObjectLiteralType AnimationController
syntax keyword qmlObjectLiteralType AnimationGroup
syntax keyword qmlObjectLiteralType Animator
syntax keyword qmlObjectLiteralType ApplicationWindow
syntax keyword qmlObjectLiteralType ApplicationWindowStyle
syntax keyword qmlObjectLiteralType AreaLight
syntax keyword qmlObjectLiteralType AreaSeries
syntax keyword qmlObjectLiteralType Armature
syntax keyword qmlObjectLiteralType AttenuationModelInverse
syntax keyword qmlObjectLiteralType AttenuationModelLinear
syntax keyword qmlObjectLiteralType Attractor
syntax keyword qmlObjectLiteralType Attribute
syntax keyword qmlObjectLiteralType Audio
syntax keyword qmlObjectLiteralType AudioCategory
syntax keyword qmlObjectLiteralType AudioEngine
syntax keyword qmlObjectLiteralType AudioListener
syntax keyword qmlObjectLiteralType AudioSample
syntax keyword qmlObjectLiteralType AuthenticationDialogRequest
syntax keyword qmlObjectLiteralType Axis
syntax keyword qmlObjectLiteralType AxisAccumulator
syntax keyword qmlObjectLiteralType AxisHelper
syntax keyword qmlObjectLiteralType AxisSetting

syntax keyword qmlObjectLiteralType BackspaceKey
syntax keyword qmlObjectLiteralType Bar3DSeries
syntax keyword qmlObjectLiteralType BarCategoryAxis
syntax keyword qmlObjectLiteralType BarDataProxy
syntax keyword qmlObjectLiteralType Bars3D
syntax keyword qmlObjectLiteralType BarSeries
syntax keyword qmlObjectLiteralType BarSet
syntax keyword qmlObjectLiteralType BaseKey
syntax keyword qmlObjectLiteralType BasicTableView
syntax keyword qmlObjectLiteralType Behavior
syntax keyword qmlObjectLiteralType Binding
syntax keyword qmlObjectLiteralType Blend
syntax keyword qmlObjectLiteralType BlendedClipAnimator
syntax keyword qmlObjectLiteralType BlendEquation
syntax keyword qmlObjectLiteralType BlendEquationArguments
syntax keyword qmlObjectLiteralType Blending
syntax keyword qmlObjectLiteralType BlitFramebuffer
syntax keyword qmlObjectLiteralType BluetoothDiscoveryModel
syntax keyword qmlObjectLiteralType BluetoothService
syntax keyword qmlObjectLiteralType BluetoothSocket
syntax keyword qmlObjectLiteralType Blur
syntax keyword qmlObjectLiteralType bool
syntax keyword qmlObjectLiteralType BorderImage
syntax keyword qmlObjectLiteralType BorderImageMesh
syntax keyword qmlObjectLiteralType BoundaryRule
syntax keyword qmlObjectLiteralType Bounds
syntax keyword qmlObjectLiteralType BoxPlotSeries
syntax keyword qmlObjectLiteralType BoxSet
syntax keyword qmlObjectLiteralType BrightnessContrast
syntax keyword qmlObjectLiteralType BrushStrokes
syntax keyword qmlObjectLiteralType Buffer
syntax keyword qmlObjectLiteralType BufferBlit
syntax keyword qmlObjectLiteralType BufferCapture
syntax keyword qmlObjectLiteralType BufferInput
syntax keyword qmlObjectLiteralType BusyIndicator
syntax keyword qmlObjectLiteralType BusyIndicatorStyle
syntax keyword qmlObjectLiteralType Button
syntax keyword qmlObjectLiteralType ButtonAxisInput
syntax keyword qmlObjectLiteralType ButtonGroup
syntax keyword qmlObjectLiteralType ButtonStyle

syntax keyword qmlObjectLiteralType Calendar
syntax keyword qmlObjectLiteralType CalendarModel
syntax keyword qmlObjectLiteralType CalendarStyle
syntax keyword qmlObjectLiteralType Camera
syntax keyword qmlObjectLiteralType Camera3D
syntax keyword qmlObjectLiteralType CameraCapabilities
syntax keyword qmlObjectLiteralType CameraCapture
syntax keyword qmlObjectLiteralType CameraExposure
syntax keyword qmlObjectLiteralType CameraFlash
syntax keyword qmlObjectLiteralType CameraFocus
syntax keyword qmlObjectLiteralType CameraImageProcessing
syntax keyword qmlObjectLiteralType CameraLens
syntax keyword qmlObjectLiteralType CameraRecorder
syntax keyword qmlObjectLiteralType CameraSelector
syntax keyword qmlObjectLiteralType CandlestickSeries
syntax keyword qmlObjectLiteralType CandlestickSet
syntax keyword qmlObjectLiteralType Canvas
syntax keyword qmlObjectLiteralType CanvasGradient
syntax keyword qmlObjectLiteralType CanvasImageData
syntax keyword qmlObjectLiteralType CanvasPixelArray
syntax keyword qmlObjectLiteralType Category
syntax keyword qmlObjectLiteralType CategoryAxis
syntax keyword qmlObjectLiteralType CategoryAxis3D
syntax keyword qmlObjectLiteralType CategoryModel
syntax keyword qmlObjectLiteralType CategoryRange
syntax keyword qmlObjectLiteralType ChangeLanguageKey
syntax keyword qmlObjectLiteralType ChartView
syntax keyword qmlObjectLiteralType CheckBox
syntax keyword qmlObjectLiteralType CheckBoxStyle
syntax keyword qmlObjectLiteralType CheckDelegate
syntax keyword qmlObjectLiteralType ChromaticAberration
syntax keyword qmlObjectLiteralType CircularGauge
syntax keyword qmlObjectLiteralType CircularGaugeStyle
syntax keyword qmlObjectLiteralType ClearBuffers
syntax keyword qmlObjectLiteralType ClipAnimator
syntax keyword qmlObjectLiteralType ClipBlendValue
syntax keyword qmlObjectLiteralType ClipPlane
syntax keyword qmlObjectLiteralType CloseEvent
syntax keyword qmlObjectLiteralType color
syntax keyword qmlObjectLiteralType ColorAnimation
syntax keyword qmlObjectLiteralType ColorDialog
syntax keyword qmlObjectLiteralType ColorDialogRequest
syntax keyword qmlObjectLiteralType ColorGradient
syntax keyword qmlObjectLiteralType ColorGradientStop
syntax keyword qmlObjectLiteralType Colorize
syntax keyword qmlObjectLiteralType ColorMask
syntax keyword qmlObjectLiteralType ColorMaster
syntax keyword qmlObjectLiteralType ColorOverlay
syntax keyword qmlObjectLiteralType Column
syntax keyword qmlObjectLiteralType ColumnLayout
syntax keyword qmlObjectLiteralType ComboBox
syntax keyword qmlObjectLiteralType ComboBoxStyle
syntax keyword qmlObjectLiteralType Command
syntax keyword qmlObjectLiteralType Compass
syntax keyword qmlObjectLiteralType CompassReading
syntax keyword qmlObjectLiteralType Component
syntax keyword qmlObjectLiteralType Component3D
syntax keyword qmlObjectLiteralType ComputeCommand
syntax keyword qmlObjectLiteralType ConeGeometry
syntax keyword qmlObjectLiteralType ConeMesh
syntax keyword qmlObjectLiteralType ConicalGradient
syntax keyword qmlObjectLiteralType Connections
syntax keyword qmlObjectLiteralType ContactDetail
syntax keyword qmlObjectLiteralType ContactDetails
syntax keyword qmlObjectLiteralType Container
syntax keyword qmlObjectLiteralType Context2D
syntax keyword qmlObjectLiteralType ContextMenuRequest
syntax keyword qmlObjectLiteralType Control
syntax keyword qmlObjectLiteralType coordinate
syntax keyword qmlObjectLiteralType CoordinateAnimation
syntax keyword qmlObjectLiteralType CopperMaterial
syntax keyword qmlObjectLiteralType CuboidGeometry
syntax keyword qmlObjectLiteralType CuboidMesh
syntax keyword qmlObjectLiteralType CullFace
syntax keyword qmlObjectLiteralType CullMode
syntax keyword qmlObjectLiteralType CumulativeDirection
syntax keyword qmlObjectLiteralType Custom3DItem
syntax keyword qmlObjectLiteralType Custom3DLabel
syntax keyword qmlObjectLiteralType Custom3DVolume
syntax keyword qmlObjectLiteralType CustomCamera
syntax keyword qmlObjectLiteralType CustomMaterial
syntax keyword qmlObjectLiteralType CustomParticle
syntax keyword qmlObjectLiteralType CylinderGeometry
syntax keyword qmlObjectLiteralType CylinderMesh

syntax keyword qmlObjectLiteralType Date
syntax keyword qmlObjectLiteralType date
syntax keyword qmlObjectLiteralType DateTimeAxis
syntax keyword qmlObjectLiteralType DayOfWeekRow
syntax keyword qmlObjectLiteralType DebugView
syntax keyword qmlObjectLiteralType DefaultMaterial
syntax keyword qmlObjectLiteralType DelayButton
syntax keyword qmlObjectLiteralType DelayButtonStyle
syntax keyword qmlObjectLiteralType DelegateChoice
syntax keyword qmlObjectLiteralType DelegateChooser
syntax keyword qmlObjectLiteralType DelegateModel
syntax keyword qmlObjectLiteralType DelegateModelGroup
syntax keyword qmlObjectLiteralType DepthInput
syntax keyword qmlObjectLiteralType DepthOfFieldHQBlur
syntax keyword qmlObjectLiteralType DepthRange
syntax keyword qmlObjectLiteralType DepthTest
syntax keyword qmlObjectLiteralType Desaturate
syntax keyword qmlObjectLiteralType Dial
syntax keyword qmlObjectLiteralType Dialog
syntax keyword qmlObjectLiteralType DialogButtonBox
syntax keyword qmlObjectLiteralType DialStyle
syntax keyword qmlObjectLiteralType DiffuseMapMaterial
syntax keyword qmlObjectLiteralType DiffuseSpecularMapMaterial
syntax keyword qmlObjectLiteralType DiffuseSpecularMaterial
syntax keyword qmlObjectLiteralType Direction
syntax keyword qmlObjectLiteralType DirectionalBlur
syntax keyword qmlObjectLiteralType DirectionalLight
syntax keyword qmlObjectLiteralType DispatchCompute
syntax keyword qmlObjectLiteralType Displace
syntax keyword qmlObjectLiteralType DistanceReading
syntax keyword qmlObjectLiteralType DistanceSensor
syntax keyword qmlObjectLiteralType DistortionRipple
syntax keyword qmlObjectLiteralType DistortionSphere
syntax keyword qmlObjectLiteralType DistortionSpiral
syntax keyword qmlObjectLiteralType Dithering
syntax keyword qmlObjectLiteralType double
syntax keyword qmlObjectLiteralType DoubleValidator
syntax keyword qmlObjectLiteralType Drag
syntax keyword qmlObjectLiteralType DragEvent
syntax keyword qmlObjectLiteralType DragHandler
syntax keyword qmlObjectLiteralType Drawer
syntax keyword qmlObjectLiteralType DropArea
syntax keyword qmlObjectLiteralType DropShadow
syntax keyword qmlObjectLiteralType DwmFeatures
syntax keyword qmlObjectLiteralType DynamicParameter

syntax keyword qmlObjectLiteralType EdgeDetect
syntax keyword qmlObjectLiteralType EditorialModel
syntax keyword qmlObjectLiteralType Effect
syntax keyword qmlObjectLiteralType EllipseShape
syntax keyword qmlObjectLiteralType Emboss
syntax keyword qmlObjectLiteralType Emitter
syntax keyword qmlObjectLiteralType EnterKey
syntax keyword qmlObjectLiteralType EnterKeyAction
syntax keyword qmlObjectLiteralType Entity
syntax keyword qmlObjectLiteralType EntityLoader
syntax keyword qmlObjectLiteralType enumeration
syntax keyword qmlObjectLiteralType EnvironmentLight
syntax keyword qmlObjectLiteralType EventConnection
syntax keyword qmlObjectLiteralType EventPoint
syntax keyword qmlObjectLiteralType EventTouchPoint
syntax keyword qmlObjectLiteralType ExclusiveGroup
syntax keyword qmlObjectLiteralType ExtendedAttributes
syntax keyword qmlObjectLiteralType ExtrudedTextGeometry
syntax keyword qmlObjectLiteralType ExtrudedTextMesh

syntax keyword qmlObjectLiteralType FastBlur
syntax keyword qmlObjectLiteralType FileDialog
syntax keyword qmlObjectLiteralType FileDialogRequest
syntax keyword qmlObjectLiteralType FillerKey
syntax keyword qmlObjectLiteralType FilterKey
syntax keyword qmlObjectLiteralType FinalState
syntax keyword qmlObjectLiteralType FindTextResult
syntax keyword qmlObjectLiteralType FirstPersonCameraController
syntax keyword qmlObjectLiteralType Flickable
syntax keyword qmlObjectLiteralType Flip
syntax keyword qmlObjectLiteralType Flipable
syntax keyword qmlObjectLiteralType Flow
syntax keyword qmlObjectLiteralType FocusScope
syntax keyword qmlObjectLiteralType FolderDialog
syntax keyword qmlObjectLiteralType FolderListModel
syntax keyword qmlObjectLiteralType font
syntax keyword qmlObjectLiteralType FontDialog
syntax keyword qmlObjectLiteralType FontLoader
syntax keyword qmlObjectLiteralType FontMetrics
syntax keyword qmlObjectLiteralType FormValidationMessageRequest
syntax keyword qmlObjectLiteralType ForwardRenderer
syntax keyword qmlObjectLiteralType Frame
syntax keyword qmlObjectLiteralType FrameAction
syntax keyword qmlObjectLiteralType FrameGraphNode
syntax keyword qmlObjectLiteralType Friction
syntax keyword qmlObjectLiteralType FrontFace
syntax keyword qmlObjectLiteralType FrostedGlassMaterial
syntax keyword qmlObjectLiteralType FrostedGlassSinglePassMaterial
syntax keyword qmlObjectLiteralType FrustumCamera
syntax keyword qmlObjectLiteralType FrustumCulling
syntax keyword qmlObjectLiteralType FullScreenRequest
syntax keyword qmlObjectLiteralType Fxaa

syntax keyword qmlObjectLiteralType Gamepad
syntax keyword qmlObjectLiteralType GamepadManager
syntax keyword qmlObjectLiteralType GammaAdjust
syntax keyword qmlObjectLiteralType Gauge
syntax keyword qmlObjectLiteralType GaugeStyle
syntax keyword qmlObjectLiteralType GaussianBlur
syntax keyword qmlObjectLiteralType geocircle
syntax keyword qmlObjectLiteralType GeocodeModel
syntax keyword qmlObjectLiteralType Geometry
syntax keyword qmlObjectLiteralType GeometryRenderer
syntax keyword qmlObjectLiteralType geopath
syntax keyword qmlObjectLiteralType geopolygon
syntax keyword qmlObjectLiteralType georectangle
syntax keyword qmlObjectLiteralType geoshape
syntax keyword qmlObjectLiteralType GestureEvent
syntax keyword qmlObjectLiteralType GlassMaterial
syntax keyword qmlObjectLiteralType GlassRefractiveMaterial
syntax keyword qmlObjectLiteralType Glow
syntax keyword qmlObjectLiteralType GoochMaterial
syntax keyword qmlObjectLiteralType Gradient
syntax keyword qmlObjectLiteralType GradientStop
syntax keyword qmlObjectLiteralType GraphicsApiFilter
syntax keyword qmlObjectLiteralType GraphicsInfo
syntax keyword qmlObjectLiteralType Gravity
syntax keyword qmlObjectLiteralType Grid
syntax keyword qmlObjectLiteralType GridGeometry
syntax keyword qmlObjectLiteralType GridLayout
syntax keyword qmlObjectLiteralType GridMesh
syntax keyword qmlObjectLiteralType GridView
syntax keyword qmlObjectLiteralType GroupBox
syntax keyword qmlObjectLiteralType GroupGoal
syntax keyword qmlObjectLiteralType Gyroscope
syntax keyword qmlObjectLiteralType GyroscopeReading

syntax keyword qmlObjectLiteralType HandlerPoint
syntax keyword qmlObjectLiteralType HandwritingInputPanel
syntax keyword qmlObjectLiteralType HandwritingModeKey
syntax keyword qmlObjectLiteralType HBarModelMapper
syntax keyword qmlObjectLiteralType HBoxPlotModelMapper
syntax keyword qmlObjectLiteralType HCandlestickModelMapper
syntax keyword qmlObjectLiteralType HDRBloomTonemap
syntax keyword qmlObjectLiteralType HeightMapSurfaceDataProxy
syntax keyword qmlObjectLiteralType HideKeyboardKey
syntax keyword qmlObjectLiteralType HistoryState
syntax keyword qmlObjectLiteralType HolsterReading
syntax keyword qmlObjectLiteralType HolsterSensor
syntax keyword qmlObjectLiteralType HorizontalBarSeries
syntax keyword qmlObjectLiteralType HorizontalHeaderView
syntax keyword qmlObjectLiteralType HorizontalPercentBarSeries
syntax keyword qmlObjectLiteralType HorizontalStackedBarSeries
syntax keyword qmlObjectLiteralType Host
syntax keyword qmlObjectLiteralType HoverHandler
syntax keyword qmlObjectLiteralType HPieModelMapper
syntax keyword qmlObjectLiteralType HueSaturation
syntax keyword qmlObjectLiteralType HumidityReading
syntax keyword qmlObjectLiteralType HumiditySensor
syntax keyword qmlObjectLiteralType HXYModelMapper

syntax keyword qmlObjectLiteralType Icon
syntax keyword qmlObjectLiteralType IdleInhibitManagerV1
syntax keyword qmlObjectLiteralType Image
syntax keyword qmlObjectLiteralType ImageModel
syntax keyword qmlObjectLiteralType ImageParticle
syntax keyword qmlObjectLiteralType InnerShadow
syntax keyword qmlObjectLiteralType InputChord
syntax keyword qmlObjectLiteralType InputContext
syntax keyword qmlObjectLiteralType InputEngine
syntax keyword qmlObjectLiteralType InputHandler3D
syntax keyword qmlObjectLiteralType InputMethod
syntax keyword qmlObjectLiteralType InputModeKey
syntax keyword qmlObjectLiteralType InputPanel
syntax keyword qmlObjectLiteralType InputSequence
syntax keyword qmlObjectLiteralType InputSettings
syntax keyword qmlObjectLiteralType Instantiator
syntax keyword qmlObjectLiteralType int
syntax keyword qmlObjectLiteralType IntValidator
syntax keyword qmlObjectLiteralType InvokedServices
syntax keyword qmlObjectLiteralType IRProximityReading
syntax keyword qmlObjectLiteralType IRProximitySensor
syntax keyword qmlObjectLiteralType Item
syntax keyword qmlObjectLiteralType ItemDelegate
syntax keyword qmlObjectLiteralType ItemGrabResult
syntax keyword qmlObjectLiteralType ItemModelBarDataProxy
syntax keyword qmlObjectLiteralType ItemModelScatterDataProxy
syntax keyword qmlObjectLiteralType ItemModelSurfaceDataProxy
syntax keyword qmlObjectLiteralType ItemParticle
syntax keyword qmlObjectLiteralType ItemSelectionModel
syntax keyword qmlObjectLiteralType IviApplication
syntax keyword qmlObjectLiteralType IviSurface

syntax keyword qmlObjectLiteralType JavaScriptDialogRequest
syntax keyword qmlObjectLiteralType Joint
syntax keyword qmlObjectLiteralType JumpList
syntax keyword qmlObjectLiteralType JumpListCategory
syntax keyword qmlObjectLiteralType JumpListDestination
syntax keyword qmlObjectLiteralType JumpListLink
syntax keyword qmlObjectLiteralType JumpListSeparator

syntax keyword qmlObjectLiteralType Key
syntax keyword qmlObjectLiteralType KeyboardColumn
syntax keyword qmlObjectLiteralType KeyboardDevice
syntax keyword qmlObjectLiteralType KeyboardHandler
syntax keyword qmlObjectLiteralType KeyboardLayout
syntax keyword qmlObjectLiteralType KeyboardLayoutLoader
syntax keyword qmlObjectLiteralType KeyboardRow
syntax keyword qmlObjectLiteralType KeyboardStyle
syntax keyword qmlObjectLiteralType KeyEvent
syntax keyword qmlObjectLiteralType Keyframe
syntax keyword qmlObjectLiteralType KeyframeAnimation
syntax keyword qmlObjectLiteralType KeyframeGroup
syntax keyword qmlObjectLiteralType KeyIcon
syntax keyword qmlObjectLiteralType KeyNavigation
syntax keyword qmlObjectLiteralType KeyPanel
syntax keyword qmlObjectLiteralType Keys

syntax keyword qmlObjectLiteralType Label
syntax keyword qmlObjectLiteralType Layer
syntax keyword qmlObjectLiteralType LayerFilter
syntax keyword qmlObjectLiteralType Layout
syntax keyword qmlObjectLiteralType LayoutMirroring
syntax keyword qmlObjectLiteralType Legend
syntax keyword qmlObjectLiteralType LerpClipBlend
syntax keyword qmlObjectLiteralType LevelAdjust
syntax keyword qmlObjectLiteralType LevelOfDetail
syntax keyword qmlObjectLiteralType LevelOfDetailBoundingSphere
syntax keyword qmlObjectLiteralType LevelOfDetailLoader
syntax keyword qmlObjectLiteralType LevelOfDetailSwitch
syntax keyword qmlObjectLiteralType LidReading
syntax keyword qmlObjectLiteralType LidSensor
syntax keyword qmlObjectLiteralType Light
syntax keyword qmlObjectLiteralType Light3D
syntax keyword qmlObjectLiteralType LightReading
syntax keyword qmlObjectLiteralType LightSensor
syntax keyword qmlObjectLiteralType LinearGradient
syntax keyword qmlObjectLiteralType LineSeries
syntax keyword qmlObjectLiteralType LineShape
syntax keyword qmlObjectLiteralType LineWidth
syntax keyword qmlObjectLiteralType list
syntax keyword qmlObjectLiteralType ListElement
syntax keyword qmlObjectLiteralType ListModel
syntax keyword qmlObjectLiteralType ListView
syntax keyword qmlObjectLiteralType Loader
syntax keyword qmlObjectLiteralType Loader3D
syntax keyword qmlObjectLiteralType Locale
syntax keyword qmlObjectLiteralType Location
syntax keyword qmlObjectLiteralType LoggingCategory
syntax keyword qmlObjectLiteralType LogicalDevice
syntax keyword qmlObjectLiteralType LogValueAxis
syntax keyword qmlObjectLiteralType LogValueAxis3DFormatter
syntax keyword qmlObjectLiteralType LottieAnimation

syntax keyword qmlObjectLiteralType Magnetometer
syntax keyword qmlObjectLiteralType MagnetometerReading
syntax keyword qmlObjectLiteralType Map
syntax keyword qmlObjectLiteralType MapCircle
syntax keyword qmlObjectLiteralType MapCircleObject
syntax keyword qmlObjectLiteralType MapCopyrightNotice
syntax keyword qmlObjectLiteralType MapGestureArea
syntax keyword qmlObjectLiteralType MapIconObject
syntax keyword qmlObjectLiteralType MapItemGroup
syntax keyword qmlObjectLiteralType MapItemView
syntax keyword qmlObjectLiteralType MapObjectView
syntax keyword qmlObjectLiteralType MapParameter
syntax keyword qmlObjectLiteralType MapPinchEvent
syntax keyword qmlObjectLiteralType MapPolygon
syntax keyword qmlObjectLiteralType MapPolygonObject
syntax keyword qmlObjectLiteralType MapPolyline
syntax keyword qmlObjectLiteralType MapPolylineObject
syntax keyword qmlObjectLiteralType MapQuickItem
syntax keyword qmlObjectLiteralType MapRectangle
syntax keyword qmlObjectLiteralType MapRoute
syntax keyword qmlObjectLiteralType MapRouteObject
syntax keyword qmlObjectLiteralType MapType
syntax keyword qmlObjectLiteralType Margins
syntax keyword qmlObjectLiteralType MaskedBlur
syntax keyword qmlObjectLiteralType MaskShape
syntax keyword qmlObjectLiteralType Material
syntax keyword qmlObjectLiteralType Matrix4x4
syntax keyword qmlObjectLiteralType matrix4x4
syntax keyword qmlObjectLiteralType MediaPlayer
syntax keyword qmlObjectLiteralType mediaplayer-qml-dynamic
syntax keyword qmlObjectLiteralType MemoryBarrier
syntax keyword qmlObjectLiteralType Menu
syntax keyword qmlObjectLiteralType MenuBar
syntax keyword qmlObjectLiteralType MenuBarItem
syntax keyword qmlObjectLiteralType MenuBarStyle
syntax keyword qmlObjectLiteralType MenuItem
syntax keyword qmlObjectLiteralType MenuItemGroup
syntax keyword qmlObjectLiteralType MenuSeparator
syntax keyword qmlObjectLiteralType MenuStyle
syntax keyword qmlObjectLiteralType Mesh
syntax keyword qmlObjectLiteralType MessageDialog
syntax keyword qmlObjectLiteralType MetalRoughMaterial
syntax keyword qmlObjectLiteralType ModeKey
syntax keyword qmlObjectLiteralType Model
syntax keyword qmlObjectLiteralType MonthGrid
syntax keyword qmlObjectLiteralType MorphingAnimation
syntax keyword qmlObjectLiteralType MorphTarget
syntax keyword qmlObjectLiteralType MotionBlur
syntax keyword qmlObjectLiteralType MouseArea
syntax keyword qmlObjectLiteralType MouseDevice
syntax keyword qmlObjectLiteralType MouseEvent
syntax keyword qmlObjectLiteralType MouseHandler
syntax keyword qmlObjectLiteralType MultiPointHandler
syntax keyword qmlObjectLiteralType MultiPointTouchArea
syntax keyword qmlObjectLiteralType MultiSampleAntiAliasing

syntax keyword qmlObjectLiteralType Navigator
syntax keyword qmlObjectLiteralType NdefFilter
syntax keyword qmlObjectLiteralType NdefMimeRecord
syntax keyword qmlObjectLiteralType NdefRecord
syntax keyword qmlObjectLiteralType NdefTextRecord
syntax keyword qmlObjectLiteralType NdefUriRecord
syntax keyword qmlObjectLiteralType NearField
syntax keyword qmlObjectLiteralType Node
syntax keyword qmlObjectLiteralType NodeInstantiator
syntax keyword qmlObjectLiteralType NoDepthMask
syntax keyword qmlObjectLiteralType NoDraw
syntax keyword qmlObjectLiteralType NoPicking
syntax keyword qmlObjectLiteralType NormalDiffuseMapAlphaMaterial
syntax keyword qmlObjectLiteralType NormalDiffuseMapMaterial
syntax keyword qmlObjectLiteralType NormalDiffuseSpecularMapMaterial
syntax keyword qmlObjectLiteralType Number
syntax keyword qmlObjectLiteralType NumberAnimation
syntax keyword qmlObjectLiteralType NumberKey

syntax keyword qmlObjectLiteralType Object3D
syntax keyword qmlObjectLiteralType ObjectModel
syntax keyword qmlObjectLiteralType ObjectPicker
syntax keyword qmlObjectLiteralType OpacityAnimator
syntax keyword qmlObjectLiteralType OpacityMask
syntax keyword qmlObjectLiteralType OpenGLInfo
syntax keyword qmlObjectLiteralType OrbitCameraController
syntax keyword qmlObjectLiteralType OrientationReading
syntax keyword qmlObjectLiteralType OrientationSensor
syntax keyword qmlObjectLiteralType OrthographicCamera
syntax keyword qmlObjectLiteralType Overlay

syntax keyword qmlObjectLiteralType Package
syntax keyword qmlObjectLiteralType Page
syntax keyword qmlObjectLiteralType PageIndicator
syntax keyword qmlObjectLiteralType palette
syntax keyword qmlObjectLiteralType Pane
syntax keyword qmlObjectLiteralType PaperArtisticMaterial
syntax keyword qmlObjectLiteralType PaperOfficeMaterial
syntax keyword qmlObjectLiteralType ParallelAnimation
syntax keyword qmlObjectLiteralType Parameter
syntax keyword qmlObjectLiteralType ParentAnimation
syntax keyword qmlObjectLiteralType ParentChange
syntax keyword qmlObjectLiteralType Particle
syntax keyword qmlObjectLiteralType ParticleExtruder
syntax keyword qmlObjectLiteralType ParticleGroup
syntax keyword qmlObjectLiteralType ParticlePainter
syntax keyword qmlObjectLiteralType ParticleSystem
syntax keyword qmlObjectLiteralType Pass
syntax keyword qmlObjectLiteralType Path
syntax keyword qmlObjectLiteralType PathAngleArc
syntax keyword qmlObjectLiteralType PathAnimation
syntax keyword qmlObjectLiteralType PathArc
syntax keyword qmlObjectLiteralType PathAttribute
syntax keyword qmlObjectLiteralType PathCubic
syntax keyword qmlObjectLiteralType PathCurve
syntax keyword qmlObjectLiteralType PathElement
syntax keyword qmlObjectLiteralType PathInterpolator
syntax keyword qmlObjectLiteralType PathLine
syntax keyword qmlObjectLiteralType PathMove
syntax keyword qmlObjectLiteralType PathMultiline
syntax keyword qmlObjectLiteralType PathPercent
syntax keyword qmlObjectLiteralType PathPolyline
syntax keyword qmlObjectLiteralType PathQuad
syntax keyword qmlObjectLiteralType PathSvg
syntax keyword qmlObjectLiteralType PathText
syntax keyword qmlObjectLiteralType PathView
syntax keyword qmlObjectLiteralType PauseAnimation
syntax keyword qmlObjectLiteralType PdfDocument
syntax keyword qmlObjectLiteralType PdfLinkModel
syntax keyword qmlObjectLiteralType PdfNavigationStack
syntax keyword qmlObjectLiteralType PdfSearchModel
syntax keyword qmlObjectLiteralType PdfSelection
syntax keyword qmlObjectLiteralType PercentBarSeries
syntax keyword qmlObjectLiteralType PerspectiveCamera
syntax keyword qmlObjectLiteralType PerVertexColorMaterial
syntax keyword qmlObjectLiteralType PhongAlphaMaterial
syntax keyword qmlObjectLiteralType PhongMaterial
syntax keyword qmlObjectLiteralType PickEvent
syntax keyword qmlObjectLiteralType PickingSettings
syntax keyword qmlObjectLiteralType PickLineEvent
syntax keyword qmlObjectLiteralType PickPointEvent
syntax keyword qmlObjectLiteralType PickResult
syntax keyword qmlObjectLiteralType PickTriangleEvent
syntax keyword qmlObjectLiteralType Picture
syntax keyword qmlObjectLiteralType PieMenu
syntax keyword qmlObjectLiteralType PieMenuStyle
syntax keyword qmlObjectLiteralType PieSeries
syntax keyword qmlObjectLiteralType PieSlice
syntax keyword qmlObjectLiteralType PinchArea
syntax keyword qmlObjectLiteralType PinchEvent
syntax keyword qmlObjectLiteralType PinchHandler
syntax keyword qmlObjectLiteralType Place
syntax keyword qmlObjectLiteralType PlaceAttribute
syntax keyword qmlObjectLiteralType PlaceSearchModel
syntax keyword qmlObjectLiteralType PlaceSearchSuggestionModel
syntax keyword qmlObjectLiteralType PlaneGeometry
syntax keyword qmlObjectLiteralType PlaneMesh
syntax keyword qmlObjectLiteralType PlasticStructuredRedEmissiveMaterial
syntax keyword qmlObjectLiteralType PlasticStructuredRedMaterial
syntax keyword qmlObjectLiteralType Playlist
syntax keyword qmlObjectLiteralType PlaylistItem
syntax keyword qmlObjectLiteralType PlayVariation
syntax keyword qmlObjectLiteralType Plugin
syntax keyword qmlObjectLiteralType PluginParameter
syntax keyword qmlObjectLiteralType point
syntax keyword qmlObjectLiteralType PointDirection
syntax keyword qmlObjectLiteralType PointerDevice
syntax keyword qmlObjectLiteralType PointerDeviceHandler
syntax keyword qmlObjectLiteralType PointerEvent
syntax keyword qmlObjectLiteralType PointerHandler
syntax keyword qmlObjectLiteralType PointerScrollEvent
syntax keyword qmlObjectLiteralType PointHandler
syntax keyword qmlObjectLiteralType PointLight
syntax keyword qmlObjectLiteralType PointSize
syntax keyword qmlObjectLiteralType PolarChartView
syntax keyword qmlObjectLiteralType PolygonOffset
syntax keyword qmlObjectLiteralType Popup
syntax keyword qmlObjectLiteralType Position
syntax keyword qmlObjectLiteralType Positioner
syntax keyword qmlObjectLiteralType PositionSource
syntax keyword qmlObjectLiteralType PressureReading
syntax keyword qmlObjectLiteralType PressureSensor
syntax keyword qmlObjectLiteralType PrincipledMaterial
syntax keyword qmlObjectLiteralType Product
syntax keyword qmlObjectLiteralType ProgressBar
syntax keyword qmlObjectLiteralType ProgressBarStyle
syntax keyword qmlObjectLiteralType PropertyAction
syntax keyword qmlObjectLiteralType PropertyAnimation
syntax keyword qmlObjectLiteralType PropertyChanges
syntax keyword qmlObjectLiteralType ProximityFilter
syntax keyword qmlObjectLiteralType ProximityReading
syntax keyword qmlObjectLiteralType ProximitySensor

syntax keyword qmlObjectLiteralType QAbstractState
syntax keyword qmlObjectLiteralType QAbstractTransition
syntax keyword qmlObjectLiteralType QmlSensors
syntax keyword qmlObjectLiteralType QSignalTransition
syntax keyword qmlObjectLiteralType Qt
syntax keyword qmlObjectLiteralType QtMultimedia
syntax keyword qmlObjectLiteralType QtObject
syntax keyword qmlObjectLiteralType QtPositioning
syntax keyword qmlObjectLiteralType QtRemoteObjects
syntax keyword qmlObjectLiteralType quaternion
syntax keyword qmlObjectLiteralType QuaternionAnimation
syntax keyword qmlObjectLiteralType QuotaRequest

syntax keyword qmlObjectLiteralType RadialBlur
syntax keyword qmlObjectLiteralType RadialGradient
syntax keyword qmlObjectLiteralType Radio
syntax keyword qmlObjectLiteralType RadioButton
syntax keyword qmlObjectLiteralType RadioButtonStyle
syntax keyword qmlObjectLiteralType RadioData
syntax keyword qmlObjectLiteralType RadioDelegate
syntax keyword qmlObjectLiteralType RangeSlider
syntax keyword qmlObjectLiteralType RasterMode
syntax keyword qmlObjectLiteralType Ratings
syntax keyword qmlObjectLiteralType RayCaster
syntax keyword qmlObjectLiteralType real
syntax keyword qmlObjectLiteralType rect
syntax keyword qmlObjectLiteralType Rectangle
syntax keyword qmlObjectLiteralType RectangleShape
syntax keyword qmlObjectLiteralType RectangularGlow
syntax keyword qmlObjectLiteralType RecursiveBlur
syntax keyword qmlObjectLiteralType RegExpValidator
syntax keyword qmlObjectLiteralType RegisterProtocolHandlerRequest
syntax keyword qmlObjectLiteralType RegularExpressionValidator
syntax keyword qmlObjectLiteralType RenderCapabilities
syntax keyword qmlObjectLiteralType RenderCapture
syntax keyword qmlObjectLiteralType RenderCaptureReply
syntax keyword qmlObjectLiteralType RenderPass
syntax keyword qmlObjectLiteralType RenderPassFilter
syntax keyword qmlObjectLiteralType RenderSettings
syntax keyword qmlObjectLiteralType RenderState
syntax keyword qmlObjectLiteralType RenderStateSet
syntax keyword qmlObjectLiteralType RenderStats
syntax keyword qmlObjectLiteralType RenderSurfaceSelector
syntax keyword qmlObjectLiteralType RenderTarget
syntax keyword qmlObjectLiteralType RenderTargetOutput
syntax keyword qmlObjectLiteralType RenderTargetSelector
syntax keyword qmlObjectLiteralType Repeater
syntax keyword qmlObjectLiteralType Repeater3D
syntax keyword qmlObjectLiteralType ReviewModel
syntax keyword qmlObjectLiteralType Rotation
syntax keyword qmlObjectLiteralType RotationAnimation
syntax keyword qmlObjectLiteralType RotationAnimator
syntax keyword qmlObjectLiteralType RotationReading
syntax keyword qmlObjectLiteralType RotationSensor
syntax keyword qmlObjectLiteralType RoundButton
syntax keyword qmlObjectLiteralType Route
syntax keyword qmlObjectLiteralType RouteLeg
syntax keyword qmlObjectLiteralType RouteManeuver
syntax keyword qmlObjectLiteralType RouteModel
syntax keyword qmlObjectLiteralType RouteQuery
syntax keyword qmlObjectLiteralType RouteSegment
syntax keyword qmlObjectLiteralType Row
syntax keyword qmlObjectLiteralType RowLayout

syntax keyword qmlObjectLiteralType Scale
syntax keyword qmlObjectLiteralType ScaleAnimator
syntax keyword qmlObjectLiteralType Scatter
syntax keyword qmlObjectLiteralType Scatter3D
syntax keyword qmlObjectLiteralType Scatter3DSeries
syntax keyword qmlObjectLiteralType ScatterDataProxy
syntax keyword qmlObjectLiteralType ScatterSeries
syntax keyword qmlObjectLiteralType Scene2D
syntax keyword qmlObjectLiteralType Scene3D
syntax keyword qmlObjectLiteralType Scene3DView
syntax keyword qmlObjectLiteralType SceneEnvironment
syntax keyword qmlObjectLiteralType SceneLoader
syntax keyword qmlObjectLiteralType ScissorTest
syntax keyword qmlObjectLiteralType Screen
syntax keyword qmlObjectLiteralType ScreenRayCaster
syntax keyword qmlObjectLiteralType ScriptAction
syntax keyword qmlObjectLiteralType ScrollBar
syntax keyword qmlObjectLiteralType ScrollIndicator
syntax keyword qmlObjectLiteralType ScrollView
syntax keyword qmlObjectLiteralType ScrollViewStyle
syntax keyword qmlObjectLiteralType SCurveTonemap
syntax keyword qmlObjectLiteralType ScxmlStateMachine
syntax keyword qmlObjectLiteralType SeamlessCubemap
syntax keyword qmlObjectLiteralType SelectionListItem
syntax keyword qmlObjectLiteralType SelectionListModel
syntax keyword qmlObjectLiteralType Sensor
syntax keyword qmlObjectLiteralType SensorGesture
syntax keyword qmlObjectLiteralType SensorReading
syntax keyword qmlObjectLiteralType SequentialAnimation
syntax keyword qmlObjectLiteralType Settings
syntax keyword qmlObjectLiteralType SettingsStore
syntax keyword qmlObjectLiteralType SetUniformValue
syntax keyword qmlObjectLiteralType Shader
syntax keyword qmlObjectLiteralType ShaderEffect
syntax keyword qmlObjectLiteralType ShaderEffectSource
syntax keyword qmlObjectLiteralType ShaderImage
syntax keyword qmlObjectLiteralType ShaderInfo
syntax keyword qmlObjectLiteralType ShaderProgram
syntax keyword qmlObjectLiteralType ShaderProgramBuilder
syntax keyword qmlObjectLiteralType Shape
syntax keyword qmlObjectLiteralType ShapeGradient
syntax keyword qmlObjectLiteralType ShapePath
syntax keyword qmlObjectLiteralType SharedGLTexture
syntax keyword qmlObjectLiteralType ShellSurface
syntax keyword qmlObjectLiteralType ShellSurfaceItem
syntax keyword qmlObjectLiteralType ShiftHandler
syntax keyword qmlObjectLiteralType ShiftKey
syntax keyword qmlObjectLiteralType Shortcut
syntax keyword qmlObjectLiteralType SignalSpy
syntax keyword qmlObjectLiteralType SignalTransition
syntax keyword qmlObjectLiteralType SinglePointHandler
syntax keyword qmlObjectLiteralType size
syntax keyword qmlObjectLiteralType Skeleton
syntax keyword qmlObjectLiteralType SkeletonLoader
syntax keyword qmlObjectLiteralType SkyboxEntity
syntax keyword qmlObjectLiteralType Slider
syntax keyword qmlObjectLiteralType SliderStyle
syntax keyword qmlObjectLiteralType SmoothedAnimation
syntax keyword qmlObjectLiteralType SortPolicy
syntax keyword qmlObjectLiteralType Sound
syntax keyword qmlObjectLiteralType SoundEffect
syntax keyword qmlObjectLiteralType SoundInstance
syntax keyword qmlObjectLiteralType SpaceKey
syntax keyword qmlObjectLiteralType SphereGeometry
syntax keyword qmlObjectLiteralType SphereMesh
syntax keyword qmlObjectLiteralType SpinBox
syntax keyword qmlObjectLiteralType SpinBoxStyle
syntax keyword qmlObjectLiteralType SplineSeries
syntax keyword qmlObjectLiteralType SplitHandle
syntax keyword qmlObjectLiteralType SplitView
syntax keyword qmlObjectLiteralType SpotLight
syntax keyword qmlObjectLiteralType SpringAnimation
syntax keyword qmlObjectLiteralType Sprite
syntax keyword qmlObjectLiteralType SpriteGoal
syntax keyword qmlObjectLiteralType SpriteSequence
syntax keyword qmlObjectLiteralType Stack
syntax keyword qmlObjectLiteralType StackedBarSeries
syntax keyword qmlObjectLiteralType StackLayout
syntax keyword qmlObjectLiteralType StackView
syntax keyword qmlObjectLiteralType StackViewDelegate
syntax keyword qmlObjectLiteralType StandardPaths
syntax keyword qmlObjectLiteralType State
syntax keyword qmlObjectLiteralType StateChangeScript
syntax keyword qmlObjectLiteralType StateGroup
syntax keyword qmlObjectLiteralType StateMachine
syntax keyword qmlObjectLiteralType StateMachineLoader
syntax keyword qmlObjectLiteralType StatusBar
syntax keyword qmlObjectLiteralType StatusBarStyle
syntax keyword qmlObjectLiteralType StatusIndicator
syntax keyword qmlObjectLiteralType StatusIndicatorStyle
syntax keyword qmlObjectLiteralType SteelMilledConcentricMaterial
syntax keyword qmlObjectLiteralType StencilMask
syntax keyword qmlObjectLiteralType StencilOperation
syntax keyword qmlObjectLiteralType StencilOperationArguments
syntax keyword qmlObjectLiteralType StencilTest
syntax keyword qmlObjectLiteralType StencilTestArguments
syntax keyword qmlObjectLiteralType Store
syntax keyword qmlObjectLiteralType String
syntax keyword qmlObjectLiteralType string
syntax keyword qmlObjectLiteralType SubtreeEnabler
syntax keyword qmlObjectLiteralType Supplier
syntax keyword qmlObjectLiteralType Surface3D
syntax keyword qmlObjectLiteralType Surface3DSeries
syntax keyword qmlObjectLiteralType SurfaceDataProxy
syntax keyword qmlObjectLiteralType SwipeDelegate
syntax keyword qmlObjectLiteralType SwipeView
syntax keyword qmlObjectLiteralType Switch
syntax keyword qmlObjectLiteralType SwitchDelegate
syntax keyword qmlObjectLiteralType SwitchStyle
syntax keyword qmlObjectLiteralType SymbolModeKey
syntax keyword qmlObjectLiteralType SystemPalette
syntax keyword qmlObjectLiteralType SystemTrayIcon

syntax keyword qmlObjectLiteralType Tab
syntax keyword qmlObjectLiteralType TabBar
syntax keyword qmlObjectLiteralType TabButton
syntax keyword qmlObjectLiteralType TableModel
syntax keyword qmlObjectLiteralType TableModelColumn
syntax keyword qmlObjectLiteralType TableView
syntax keyword qmlObjectLiteralType TableViewColumn
syntax keyword qmlObjectLiteralType TableViewStyle
syntax keyword qmlObjectLiteralType TabView
syntax keyword qmlObjectLiteralType TabViewStyle
syntax keyword qmlObjectLiteralType TapHandler
syntax keyword qmlObjectLiteralType TapReading
syntax keyword qmlObjectLiteralType TapSensor
syntax keyword qmlObjectLiteralType TargetDirection
syntax keyword qmlObjectLiteralType TaskbarButton
syntax keyword qmlObjectLiteralType Technique
syntax keyword qmlObjectLiteralType TechniqueFilter
syntax keyword qmlObjectLiteralType TestCase
syntax keyword qmlObjectLiteralType Text
syntax keyword qmlObjectLiteralType Text2DEntity
syntax keyword qmlObjectLiteralType TextArea
syntax keyword qmlObjectLiteralType TextAreaStyle
syntax keyword qmlObjectLiteralType TextEdit
syntax keyword qmlObjectLiteralType TextField
syntax keyword qmlObjectLiteralType TextFieldStyle
syntax keyword qmlObjectLiteralType TextInput
syntax keyword qmlObjectLiteralType TextMetrics
syntax keyword qmlObjectLiteralType Texture
syntax keyword qmlObjectLiteralType Texture1D
syntax keyword qmlObjectLiteralType Texture1DArray
syntax keyword qmlObjectLiteralType Texture2D
syntax keyword qmlObjectLiteralType Texture2DArray
syntax keyword qmlObjectLiteralType Texture2DMultisample
syntax keyword qmlObjectLiteralType Texture2DMultisampleArray
syntax keyword qmlObjectLiteralType Texture3D
syntax keyword qmlObjectLiteralType TextureBuffer
syntax keyword qmlObjectLiteralType TextureCubeMap
syntax keyword qmlObjectLiteralType TextureCubeMapArray
syntax keyword qmlObjectLiteralType TextureImage
syntax keyword qmlObjectLiteralType TextureInput
syntax keyword qmlObjectLiteralType TextureLoader
syntax keyword qmlObjectLiteralType TextureRectangle
syntax keyword qmlObjectLiteralType Theme3D
syntax keyword qmlObjectLiteralType ThemeColor
syntax keyword qmlObjectLiteralType ThresholdMask
syntax keyword qmlObjectLiteralType ThumbnailToolBar
syntax keyword qmlObjectLiteralType ThumbnailToolButton
syntax keyword qmlObjectLiteralType TiltReading
syntax keyword qmlObjectLiteralType TiltSensor
syntax keyword qmlObjectLiteralType TiltShift
syntax keyword qmlObjectLiteralType Timeline
syntax keyword qmlObjectLiteralType TimelineAnimation
syntax keyword qmlObjectLiteralType TimeoutTransition
syntax keyword qmlObjectLiteralType Timer
syntax keyword qmlObjectLiteralType ToggleButton
syntax keyword qmlObjectLiteralType ToggleButtonStyle
syntax keyword qmlObjectLiteralType ToolBar
syntax keyword qmlObjectLiteralType ToolBarStyle
syntax keyword qmlObjectLiteralType ToolButton
syntax keyword qmlObjectLiteralType ToolSeparator
syntax keyword qmlObjectLiteralType ToolTip
syntax keyword qmlObjectLiteralType TooltipRequest
syntax keyword qmlObjectLiteralType Torch
syntax keyword qmlObjectLiteralType TorusGeometry
syntax keyword qmlObjectLiteralType TorusMesh
syntax keyword qmlObjectLiteralType TouchEventSequence
syntax keyword qmlObjectLiteralType TouchInputHandler3D
syntax keyword qmlObjectLiteralType TouchPoint
syntax keyword qmlObjectLiteralType Trace
syntax keyword qmlObjectLiteralType TraceCanvas
syntax keyword qmlObjectLiteralType TraceInputArea
syntax keyword qmlObjectLiteralType TraceInputKey
syntax keyword qmlObjectLiteralType TraceInputKeyPanel
syntax keyword qmlObjectLiteralType TrailEmitter
syntax keyword qmlObjectLiteralType Transaction
syntax keyword qmlObjectLiteralType Transform
syntax keyword qmlObjectLiteralType Transition
syntax keyword qmlObjectLiteralType Translate
syntax keyword qmlObjectLiteralType TreeView
syntax keyword qmlObjectLiteralType TreeViewStyle
syntax keyword qmlObjectLiteralType Tumbler
syntax keyword qmlObjectLiteralType TumblerColumn
syntax keyword qmlObjectLiteralType TumblerStyle
syntax keyword qmlObjectLiteralType Turbulence

syntax keyword qmlObjectLiteralType UniformAnimator
syntax keyword qmlObjectLiteralType url
syntax keyword qmlObjectLiteralType User

syntax keyword qmlObjectLiteralType ValueAxis
syntax keyword qmlObjectLiteralType ValueAxis3D
syntax keyword qmlObjectLiteralType ValueAxis3DFormatter
syntax keyword qmlObjectLiteralType var
syntax keyword qmlObjectLiteralType variant
syntax keyword qmlObjectLiteralType VBarModelMapper
syntax keyword qmlObjectLiteralType VBoxPlotModelMapper
syntax keyword qmlObjectLiteralType VCandlestickModelMapper
syntax keyword qmlObjectLiteralType vector2d
syntax keyword qmlObjectLiteralType vector3d
syntax keyword qmlObjectLiteralType Vector3dAnimation
syntax keyword qmlObjectLiteralType vector4d
syntax keyword qmlObjectLiteralType VertexBlendAnimation
syntax keyword qmlObjectLiteralType VerticalHeaderView
syntax keyword qmlObjectLiteralType Video
syntax keyword qmlObjectLiteralType VideoOutput
syntax keyword qmlObjectLiteralType View3D
syntax keyword qmlObjectLiteralType Viewport
syntax keyword qmlObjectLiteralType ViewTransition
syntax keyword qmlObjectLiteralType Vignette
syntax keyword qmlObjectLiteralType VirtualKeyboardSettings
syntax keyword qmlObjectLiteralType VPieModelMapper
syntax keyword qmlObjectLiteralType VXYModelMapper

syntax keyword qmlObjectLiteralType Wander
syntax keyword qmlObjectLiteralType WasdController
syntax keyword qmlObjectLiteralType WavefrontMesh
syntax keyword qmlObjectLiteralType WaylandClient
syntax keyword qmlObjectLiteralType WaylandCompositor
syntax keyword qmlObjectLiteralType WaylandHardwareLayer
syntax keyword qmlObjectLiteralType WaylandOutput
syntax keyword qmlObjectLiteralType WaylandQuickItem
syntax keyword qmlObjectLiteralType WaylandSeat
syntax keyword qmlObjectLiteralType WaylandSurface
syntax keyword qmlObjectLiteralType WaylandView
syntax keyword qmlObjectLiteralType Waypoint
syntax keyword qmlObjectLiteralType WebChannel
syntax keyword qmlObjectLiteralType WebEngine
syntax keyword qmlObjectLiteralType WebEngineAction
syntax keyword qmlObjectLiteralType WebEngineCertificateError
syntax keyword qmlObjectLiteralType WebEngineClientCertificateOption
syntax keyword qmlObjectLiteralType WebEngineClientCertificateSelection
syntax keyword qmlObjectLiteralType WebEngineDownloadItem
syntax keyword qmlObjectLiteralType WebEngineHistory
syntax keyword qmlObjectLiteralType WebEngineHistoryListModel
syntax keyword qmlObjectLiteralType WebEngineLoadRequest
syntax keyword qmlObjectLiteralType WebEngineNavigationRequest
syntax keyword qmlObjectLiteralType WebEngineNewViewRequest
syntax keyword qmlObjectLiteralType WebEngineNotification
syntax keyword qmlObjectLiteralType WebEngineProfile
syntax keyword qmlObjectLiteralType WebEngineScript
syntax keyword qmlObjectLiteralType WebEngineSettings
syntax keyword qmlObjectLiteralType WebEngineView
syntax keyword qmlObjectLiteralType WebSocket
syntax keyword qmlObjectLiteralType WebSocketServer
syntax keyword qmlObjectLiteralType WebView
syntax keyword qmlObjectLiteralType WebViewLoadRequest
syntax keyword qmlObjectLiteralType WeekNumberColumn
syntax keyword qmlObjectLiteralType WheelEvent
syntax keyword qmlObjectLiteralType WheelHandler
syntax keyword qmlObjectLiteralType Window
syntax keyword qmlObjectLiteralType WlScaler
syntax keyword qmlObjectLiteralType WlShell
syntax keyword qmlObjectLiteralType WlShellSurface
syntax keyword qmlObjectLiteralType WorkerScript

syntax keyword qmlObjectLiteralType XAnimator
syntax keyword qmlObjectLiteralType XdgDecorationManagerV1
syntax keyword qmlObjectLiteralType XdgOutputManagerV1
syntax keyword qmlObjectLiteralType XdgPopup
syntax keyword qmlObjectLiteralType XdgPopupV5
syntax keyword qmlObjectLiteralType XdgPopupV6
syntax keyword qmlObjectLiteralType XdgShell
syntax keyword qmlObjectLiteralType XdgShellV5
syntax keyword qmlObjectLiteralType XdgShellV6
syntax keyword qmlObjectLiteralType XdgSurface
syntax keyword qmlObjectLiteralType XdgSurfaceV5
syntax keyword qmlObjectLiteralType XdgSurfaceV6
syntax keyword qmlObjectLiteralType XdgToplevel
syntax keyword qmlObjectLiteralType XdgToplevelV6
syntax keyword qmlObjectLiteralType XmlListModel
syntax keyword qmlObjectLiteralType XmlRole
syntax keyword qmlObjectLiteralType XYPoint
syntax keyword qmlObjectLiteralType XYSeries

syntax keyword qmlObjectLiteralType YAnimator

syntax keyword qmlObjectLiteralType ZoomBlur

" }}}

if get(g:, 'qml_fold', 0)
  syn match   qmlFunction      "\<function\>"
  syn region  qmlFunctionFold  start="^\z(\s*\)\<function\>.*[^};]$" end="^\z1}.*$" transparent fold keepend

  syn sync match qmlSync  grouphere qmlFunctionFold "\<function\>"
  syn sync match qmlSync  grouphere NONE "^}"

  setlocal foldmethod=syntax
  setlocal foldtext=getline(v:foldstart)
else
  syn keyword qmlFunction         function
  syn match   qmlArrowFunction    "=>"
  syn match   qmlBraces           "[{}\[\]]"
  syn match   qmlParens           "[()]"
endif

syn sync fromstart
syn sync maxlines=100

if main_syntax == "qml"
  syn sync ccomment qmlComment
endif

hi def link qmlComment           Comment
hi def link qmlLineComment       Comment
hi def link qmlCommentTodo       Todo
hi def link qmlSpecial           Special
hi def link qmlStringS           String
hi def link qmlStringD           String
hi def link qmlStringT           String
hi def link qmlCharacter         Character
hi def link qmlNumber            Number
hi def link qmlConditional       Conditional
hi def link qmlRepeat            Repeat
hi def link qmlBranch            Conditional
hi def link qmlOperator          Operator
hi def link qmlJsType            Type
hi def link qmlType              Type
hi def link qmlObjectLiteralType Type
hi def link qmlStatement         Statement
hi def link qmlFunction          Function
hi def link qmlArrowFunction     Function
hi def link qmlBraces            Function
hi def link qmlError             Error
hi def link qmlNull              Keyword
hi def link qmlBoolean           Boolean
hi def link qmlRegexpString      String
hi def link qmlNullishCoalescing Operator

hi def link qmlIdentifier        Identifier
hi def link qmlLabel             Label
hi def link qmlException         Exception
hi def link qmlMessage           Keyword
hi def link qmlGlobal            Keyword
hi def link qmlReserved          Keyword
hi def link qmlDebug             Debug
hi def link qmlConstant          Label
hi def link qmlBindingProperty   Label
hi def link qmlDeclaration       Function

let b:current_syntax = "qml"
if main_syntax == 'qml'
  unlet main_syntax
endif
