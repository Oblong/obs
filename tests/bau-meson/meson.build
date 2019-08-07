project('hello', 'c',
  version : '1.0.0',
  license : 'proprietary',
  default_options : [
    'werror=true',
    'warning_level=2'
  ]
)

# Add compiler flags (if supported by current compiler).
maybe_c_flags = [
  '-fmax-errors=3',
]
c_compiler = meson.get_compiler('c')
c_flags = []
foreach flag : maybe_c_flags
  if c_compiler.has_argument(flag)
    c_flags += flag
  endif
endforeach

# Find system libraries this project depends on.
libs = [
   'libpcre',
]
project_deps = []
foreach lib : libs
   project_deps += dependency(lib, required : true)
endforeach

# Any rpath entries needed should come in via .pc files,
# but until https://github.com/mesonbuild/meson/issues/4027
# is fixed, jam in a guess at the appropriate rpath here.
rpaths = []
foreach dep : project_deps
     libdir = dep.get_pkgconfig_variable('libdir')
     if libdir != '' and libdir not in rpaths
         rpaths += libdir
     endif
endforeach
final_rpath = ':'.join(rpaths)
message('Using final rpath of ' + final_rpath)

# Build the project, and tell meson to install it if asked (via 'ninja install').
executable(
   'pcredemo',
   'pcredemo.c',
   c_args : c_flags,
   dependencies : project_deps,
   install_rpath : final_rpath,
   install : true)

# Build and run the project's unit test.
# (By convention, 'ninja test' should always work for our meson projects)
t = find_program('pcredemo_test.sh')
test('greppy', t)
