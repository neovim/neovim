# .ycm_extra_conf.py for nvim source code.
import os, ycm_core


def DirectoryOfThisScript():
    return os.path.dirname(os.path.abspath(__file__))


def GetDatabase():
    compilation_database_folder = DirectoryOfThisScript() + '/../build'
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
        replacement_file = basename + '.c'
        if os.path.exists(replacement_file):
            compilation_info = database.GetCompilationInfoForFile(replacement_file)
            if compilation_info.compiler_flags_:
                return compilation_info
        return None
    return database.GetCompilationInfoForFile(filename)


def FlagsForFile(filename):
    compilation_info = GetCompilationInfoForFile(filename)
    if not compilation_info:
        return None
    return {
        'flags': compilation_info.compiler_flags_,
        'do_cache': True
    }
