# .ycm_extra_conf.py for nvim source code.
import os
import ycm_core


def DirectoryOfThisScript():
    return os.path.dirname(os.path.abspath(__file__))


def GetDatabase():
    compilation_database_folder = os.path.join(DirectoryOfThisScript(),
                                               '..', 'build')
    if os.path.exists(compilation_database_folder):
        return ycm_core.CompilationDatabase(compilation_database_folder)
    return None


def IsHeaderFile(filename):
    extension = os.path.splitext(filename)[1]
    return extension == '.h'


def GetCompilationInfoForFile(filename):
    database = GetDatabase()
    if not database:
        return None
    if IsHeaderFile(filename):
        basename = os.path.splitext(filename)[0]
        c_file = basename + '.c'
        # for pure headers (no c file), default to main.c
        if not os.path.exists(c_file):
            c_file = os.path.join(DirectoryOfThisScript(), 'nvim', 'main.c')
        if os.path.exists(c_file):
            compilation_info = database.GetCompilationInfoForFile(c_file)
            if compilation_info.compiler_flags_:
                return compilation_info
        return None
    return database.GetCompilationInfoForFile(filename)


def FlagsForFile(filename):
    compilation_info = GetCompilationInfoForFile(filename)
    if not compilation_info:
        return None
    # Add flags not needed for clang-the-binary,
    # but needed for libclang-the-library (YCM uses this last one).
    flags = (list(compilation_info.compiler_flags_)
             if compilation_info.compiler_flags_
             else [])
    extra_flags = ['-Wno-newline-eof']
    final_flags = flags + extra_flags
    return {
        'flags': final_flags,
        'do_cache': True
    }
