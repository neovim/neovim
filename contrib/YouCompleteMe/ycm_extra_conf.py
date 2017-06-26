# .ycm_extra_conf.py for nvim source code.
import os
import ycm_core


def DirectoryOfThisScript():
    return os.path.dirname(os.path.abspath(__file__))


def GetDatabase():
    compilation_database_folder = os.path.join(DirectoryOfThisScript(),
                                               'build')
    if os.path.exists(compilation_database_folder):
        return ycm_core.CompilationDatabase(compilation_database_folder)
    return None


def GetCompilationInfoForFile(filename):
    database = GetDatabase()
    if not database:
        return None
    return database.GetCompilationInfoForFile(filename)


# It seems YCM does not resolve directories correctly. This function will
# adjust paths in the compiler flags to be absolute
def FixDirectories(args, compiler_working_dir):
    def adjust_path(path):
        return os.path.abspath(os.path.join(compiler_working_dir, path))

    adjust_next_arg = False
    new_args = []
    for arg in args:
        if adjust_next_arg:
            arg = adjust_path(arg)
            adjust_next_arg = False
        else:
            for dir_flag in ['-I', '-isystem', '-o', '-c']:
                if arg.startswith(dir_flag):
                    if arg != dir_flag:
                        # flag and path are concatenated in same arg
                        path = arg[len(dir_flag):]
                        new_path = adjust_path(path)
                        arg = '{0}{1}'.format(dir_flag, new_path)
                    else:
                        # path is specified in next argument
                        adjust_next_arg = True
        new_args.append(arg)
    return new_args


def FlagsForFile(filename):
    compilation_info = GetCompilationInfoForFile(filename)
    if not compilation_info:
        return None
    # Add flags not needed for clang-the-binary,
    # but needed for libclang-the-library (YCM uses this last one).
    flags = FixDirectories((list(compilation_info.compiler_flags_)
                            if compilation_info.compiler_flags_
                            else []), compilation_info.compiler_working_dir_)
    extra_flags = ['-Wno-newline-eof']
    return {
        'flags': flags + extra_flags,
        'do_cache': True
    }
