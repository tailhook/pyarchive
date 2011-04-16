import warnings

from cpython.bytes cimport *
from cpython.unicode cimport *

cdef extern from "archive.h":
    cdef struct archive
    cdef struct archive_entry
    archive *archive_read_new()
    int archive_read_support_compression_all(archive *)
    int archive_read_support_format_all(archive *)
    int archive_read_close(archive *)
    int archive_read_finish(archive *)
    int archive_errno(archive *)
    int archive_read_open_filename(archive *, char *, int)
    int archive_read_next_header(archive *, archive_entry **)
    int archive_read_data(archive *, void *buf, int size)
    int archive_read_data_skip(archive *)
    char *archive_error_string(archive *)

    char * archive_entry_pathname(archive_entry *)

    cdef enum:
        ARCHIVE_EOF
        ARCHIVE_OK
        ARCHIVE_RETRY
        ARCHIVE_WARN
        ARCHIVE_FAILED
        ARCHIVE_FATAL

cdef extern from "Python.h":
    object PyUnicode_EncodeFSDefault(object)
    object PyUnicode_DecodeFSDefaultAndSize(char *, Py_ssize_t)
    object PyUnicode_FromString(char *str)

cdef extern from "string.h":
    int strlen(char *)

class ArchiveWarning(Warning):
    pass

class Error(Exception):

    def __init__(self, int errno, char *errstr):
        self.errno = errno
        self.errstr = PyUnicode_FromString(errstr)

    def __str__(self):
        return "[%d] %s" % (self.errno, self.errstr)

class TemporaryError(Error):
    pass

cdef class Archive

cdef class Entry:
    cdef Archive archive
    cdef archive_entry *_entry

    def __init__(self, archive):
        self.archive = archive

    property filename:
        def __get__(self):
            cdef char *pathname = archive_entry_pathname(self._entry)
            cdef Py_ssize_t len = strlen(pathname)
            return PyUnicode_DecodeFSDefaultAndSize(pathname, len)

    def skip(self):
        if self.archive._cur is self:
            self.archive._cur = None
            self.archive._check(archive_read_data_skip(self.archive._arch))

    def close(self):
        self.skip()

    def read(self, size):
        cdef object res = PyBytes_FromStringAndSize(NULL, size)
        cdef int bread
        cdef void *buf = PyBytes_AsString(res)
        cdef PyObject *pres = <PyObject *>res
        bread = self.archive._checkl(archive_read_data(self.archive._arch,
            buf, size))
        _PyBytes_Resize(&pres, bread)
        return <object>(res)

cdef class Archive:
    cdef archive *_arch
    cdef Entry _cur
    cdef int bufsize
    cdef object fn

    def __cinit__(self):
        self._arch = archive_read_new()
        if not self._arch:
            raise RuntimeError("Can't create archive instance")
        self._cur = None
        self._check(archive_read_support_compression_all(self._arch))
        self._check(archive_read_support_format_all(self._arch))

    def __init__(self, file, bufsize=16384):
        if hasattr(file, 'read'):
            raise RuntimeError("File-like objects"
                " are not supported at the momment")
        self.bufsize = bufsize
        self.fn = fn = PyUnicode_EncodeFSDefault(file)
        self._check(archive_read_open_filename(self._arch, fn, bufsize))

    cdef close(self):
        if self._arch:
            archive_read_close(self._arch)
            archive_read_finish(self._arch)

    def __del__(self):
        self.close()

    cdef int _checkl(Archive self, int result) except -1:
        if result > 0:
            return result
        return self._check(result)

    cdef int _check(Archive self, int result) except -1:
        if result == 0:
            return result
        elif result == ARCHIVE_FATAL:
            self.close()
            raise Error(
                archive_errno(self._arch),
                archive_error_string(self._arch))
        elif result == ARCHIVE_RETRY:
            raise TemporaryError(
                archive_errno(self._arch),
                archive_error_string(self._arch))
        elif result == ARCHIVE_EOF:
            raise EOFError()
        elif result == ARCHIVE_WARN:
            warnings.warn(archive_error_string(self._arch))
            return 0
        else:
            raise RuntimeError("Unknown return code")
        return 0

    def __iter__(self):
        return self

    def __next__(self):
        if self._cur:
            self._cur.close()
        entry = Entry(self)
        cdef int r = archive_read_next_header(self._arch, &entry._entry)
        if r == ARCHIVE_EOF:
            raise StopIteration()
        self._check(r)
        self._cur = entry
        return entry

