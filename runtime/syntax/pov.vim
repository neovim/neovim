" Vim syntax file
" Language: PoV-Ray(tm) 3.7 Scene Description Language
" Maintainer: David Necas (Yeti) <yeti@physics.muni.cz>
" Last Change: 2011-04-23
" 2025 Apr 21 by Vim Project (deprecate render and statistics #17177)

" Setup
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case match

" Top level stuff
syn keyword povCommands global_settings
syn keyword povObjects array atmosphere background bicubic_patch blob box camera component cone cubic cylinder disc fog height_field isosurface julia_fractal lathe light_group light_source mesh mesh2 object ovus parametric pattern photons plane poly polygon polynomial prism quadric quartic rainbow sky_sphere smooth_triangle sor sphere sphere_sweep spline superellipsoid text torus triangle
syn keyword povCSG clipped_by composite contained_by difference intersection merge union
syn keyword povAppearance interior material media texture interior_texture texture_list
syn keyword povGlobalSettings ambient_light assumed_gamma charset hf_gray_16 irid_wavelength max_intersections max_trace_level number_of_waves radiosity noise_generator
syn keyword povTransform inverse matrix rotate scale translate transform

" Descriptors
syn keyword povDescriptors finish inside_vector normal pigment uv_mapping uv_vectors vertex_vectors
syn keyword povDescriptors adc_bailout always_sample brightness count error_bound distance_maximum gray_threshold load_file low_error_factor maximum_reuse max_sample media minimum_reuse mm_per_unit nearest_count normal pretrace_end pretrace_start recursion_limit save_file
syn keyword povDescriptors color colour rgb rgbt rgbf rgbft srgb srgbf srgbt srgbft
syn match povDescriptors "\<\(red\|green\|blue\|gray\)\>"
syn keyword povDescriptors bump_map color_map colour_map image_map material_map pigment_map quick_color quick_colour normal_map texture_map image_pattern pigment_pattern
syn keyword povDescriptors ambient brilliance conserve_energy crand diffuse fresnel irid metallic phong phong_size refraction reflection reflection_exponent roughness specular subsurface
syn keyword povDescriptors cylinder fisheye mesh_camera omnimax orthographic panoramic perspective spherical ultra_wide_angle
syn keyword povDescriptors agate aoi average brick boxed bozo bumps cells checker crackle cylindrical dents facets function gradient granite hexagon julia leopard magnet mandel marble onion pavement planar quilted radial ripples slope spherical spiral1 spiral2 spotted square tiles tile2 tiling toroidal triangular waves wood wrinkles
syn keyword povDescriptors density_file
syn keyword povDescriptors area_light shadowless spotlight parallel
syn keyword povDescriptors absorption confidence density emission intervals ratio samples scattering variance
syn keyword povDescriptors distance fog_alt fog_offset fog_type turb_depth
syn keyword povDescriptors b_spline bezier_spline cubic_spline evaluate face_indices form linear_spline max_gradient natural_spline normal_indices normal_vectors quadratic_spline uv_indices
syn keyword povDescriptors target

" Modifiers
syn keyword povModifiers caustics dispersion dispersion_samples fade_color fade_colour fade_distance fade_power ior
syn keyword povModifiers bounded_by double_illuminate hierarchy hollow no_shadow open smooth sturm threshold water_level
syn keyword povModifiers importance no_radiosity
syn keyword povModifiers hypercomplex max_iteration precision quaternion slice
syn keyword povModifiers conic_sweep linear_sweep
syn keyword povModifiers flatness type u_steps v_steps
syn keyword povModifiers aa_level aa_threshold adaptive area_illumination falloff jitter looks_like media_attenuation media_interaction method point_at radius tightness
syn keyword povModifiers angle aperture bokeh blur_samples confidence direction focal_point h_angle location look_at right sky up v_angle variance
syn keyword povModifiers all bump_size gamma interpolate map_type once premultiplied slope_map use_alpha use_color use_colour use_index
syn match povModifiers "\<\(filter\|transmit\)\>"
syn keyword povModifiers black_hole agate_turb brick_size control0 control1 cubic_wave density_map flip frequency interpolate inverse lambda metric mortar octaves offset omega phase poly_wave ramp_wave repeat scallop_wave sine_wave size strength triangle_wave thickness turbulence turb_depth type warp
syn keyword povModifiers eccentricity extinction
syn keyword povModifiers arc_angle falloff_angle width
syn keyword povModifiers accuracy all_intersections altitude autostop circular collect coords cutaway_textures dist_exp expand_thresholds exponent exterior gather global_lights major_radius max_trace no_bump_scale no_image no_reflection orient orientation pass_through precompute projected_through range_divider solid spacing split_union tolerance

" Words not marked `reserved' in documentation, but...
syn keyword povBMPType alpha exr gif hdr iff jpeg pgm png pot ppm sys tga tiff
syn keyword povFontType ttf contained
syn keyword povDensityType df3 contained
syn keyword povCharset ascii utf8 contained

" Math functions on floats, vectors and strings
syn keyword povFunctions abs acos acosh asc asin asinh atan atan2 atanh bitwise_and bitwise_or bitwise_xor ceil cos cosh defined degrees dimensions dimension_size div exp file_exists floor inside int internal ln log max min mod pow prod radians rand seed select sin sinh sqrt strcmp strlen sum tan tanh val vdot vlength vstr vturbulence
syn keyword povFunctions min_extent max_extent trace vcross vrotate vaxis_rotate vnormalize vturbulence
syn keyword povFunctions chr concat datetime now substr str strupr strlwr
syn keyword povJuliaFunctions acosh asinh atan cosh cube pwr reciprocal sinh sqr tanh

" Specialities
syn keyword povConsts clock clock_delta clock_on final_clock final_frame frame_number initial_clock initial_frame input_file_name image_width image_height false no off on pi true version yes
syn match povConsts "\<[tuvxyz]\>"
syn match povDotItem "\.\@<=\(blue\|green\|gray\|filter\|red\|transmit\|hf\|t\|u\|v\|x\|y\|z\)\>" display

" Comments
syn region povComment start="/\*" end="\*/" contains=povTodo,povComment
syn match povComment "//.*" contains=povTodo
syn match povCommentError "\*/"
syn sync ccomment povComment
syn sync minlines=50
syn keyword povTodo TODO FIXME XXX NOT contained
syn cluster povPRIVATE add=povTodo

" Language directives
syn match povConditionalDir "#\s*\(else\|end\|for\|if\|ifdef\|ifndef\|switch\|while\)\>"
syn match povLabelDir "#\s*\(break\|case\|default\|range\)\>"
syn match povDeclareDir "#\s*\(declare\|default\|local\|macro\|undef\|version\)\>" nextgroup=povDeclareOption skipwhite
syn keyword povDeclareOption deprecated once contained nextgroup=povDeclareOption skipwhite
syn match povIncludeDir "#\s*include\>"
syn match povFileDir "#\s*\(fclose\|fopen\|read\|write\)\>"
syn keyword povFileDataType uint8 sint8 unit16be uint16le sint16be sint16le sint32le sint32be
syn match povMessageDir "#\s*\(debug\|error\|warning\)\>"
syn match povMessageDirDeprecated "#\s*\%(render\|statistics\)\>"
syn region povFileOpen start="#\s*fopen\>" skip=+"[^"]*"+ matchgroup=povOpenType end="\<\(read\|write\|append\)\>" contains=ALLBUT,PovParenError,PovBraceError,@PovPRIVATE transparent keepend

" Literal strings
syn match povSpecialChar "\\u\x\{4}\|\\\d\d\d\|\\." contained
syn region povString start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=povSpecialChar oneline
syn cluster povPRIVATE add=povSpecialChar

" Catch errors caused by wrong parenthesization
syn region povParen start='(' end=')' contains=ALLBUT,povParenError,@povPRIVATE transparent
syn match povParenError ")"
syn region povBrace start='{' end='}' contains=ALLBUT,povBraceError,@povPRIVATE transparent
syn match povBraceError "}"

" Numbers
syn match povNumber "\(^\|\W\)\@<=[+-]\=\(\d\+\)\=\.\=\d\+\([eE][+-]\=\d\+\)\="

" Define the default highlighting
hi def link povComment Comment
hi def link povTodo Todo
hi def link povNumber Number
hi def link povString String
hi def link povFileOpen Constant
hi def link povConsts Constant
hi def link povDotItem povSpecial
hi def link povBMPType povSpecial
hi def link povCharset povSpecial
hi def link povDensityType povSpecial
hi def link povFontType povSpecial
hi def link povOpenType povSpecial
hi def link povSpecialChar povSpecial
hi def link povSpecial Special
hi def link povConditionalDir PreProc
hi def link povLabelDir PreProc
hi def link povDeclareDir Define
hi def link povDeclareOption Define
hi def link povIncludeDir Include
hi def link povFileDir PreProc
hi def link povFileDataType Special
hi def link povMessageDir Debug
hi def link povMessageDirDeprecated povError
hi def link povAppearance povDescriptors
hi def link povObjects povDescriptors
hi def link povGlobalSettings povDescriptors
hi def link povDescriptors Type
hi def link povJuliaFunctions PovFunctions
hi def link povModifiers povFunctions
hi def link povFunctions Function
hi def link povCommands Operator
hi def link povTransform Operator
hi def link povCSG Operator
hi def link povParenError povError
hi def link povBraceError povError
hi def link povCommentError povError
hi def link povError Error

let b:current_syntax = "pov"
