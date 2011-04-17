import warnings

from cpython.bytes cimport *
from cpython.unicode cimport *

cdef extern from "sys/types.h":
    struct stat:
        int st_size
cdef extern from "sys/stat.h": pass
cdef extern from "fcntl.h": pass

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
    int archive_read_data_block(archive *, void **, size_t *, int *)
    int archive_read_data_skip(archive *)
    char *archive_error_string(archive *)

    cdef enum:
        ARCHIVE_EOF
        ARCHIVE_OK
        ARCHIVE_RETRY
        ARCHIVE_WARN
        ARCHIVE_FAILED
        ARCHIVE_FATAL

cdef extern from "archive_entry.h":
    char * archive_entry_pathname(archive_entry *)
    stat *archive_entry_stat(archive_entry *)
    void archive_entry_free(archive_entry *)


cdef extern from "Python.h":
    object PyUnicode_EncodeFSDefault(object)
    object PyUnicode_DecodeFSDefaultAndSize(char *, Py_ssize_t)
    object PyUnicode_FromString(char *str)

cdef extern from "string.h":
    int strlen(char *)

cdef extern from "malloc.h":
    void *alloca(size_t sz)


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
    cdef Py_ssize_t position

    def __init__(self, archive):
        self.archive = archive
        self.position = 0

    property filename:
        def __get__(self):
            cdef char *pathname = archive_entry_pathname(self._entry)
            cdef Py_ssize_t len = strlen(pathname)
            return PyUnicode_DecodeFSDefaultAndSize(pathname, len)

    def __del__(self):
        archive_entry_free(self._entry)

    def skip(self):
        if self.archive._cur is self:
            self.archive._cur = None
            self.archive._check(archive_read_data_skip(self.archive._arch))

    def close(self):
        self.skip()

    def read(self, size=-1):
        cdef size_t sz
        cdef size_t ln
        cdef void *buf
        cdef size_t len
        cdef int offset
        if size == -1:
            sz = archive_entry_stat(self._entry).st_size
            if sz > self.position:
                ln = sz - self.position
                buf = <char*>alloca(ln)
                bread = self.archive._checkl(archive_read_data(self.archive._arch,
                    buf, sz - self.position))
                assert bread == ln
                res = PyBytes_FromStringAndSize(<char*>buf + self.position, ln)
                self.position = sz
                return res
            return b""
        r = archive_read_data_block(self.archive._arch, &buf, &len, &offset)
        if r == ARCHIVE_EOF:
            return b""
        self.archive._check(r)
        if offset > self.position:
            zlen = offset - self.position
            self.position = offset + len
            return b'\x00'*zlen + PyBytes_FromStringAndSize(<char *>buf, len)
        self.position = offset + len
        return PyBytes_FromStringAndSize(<char *>buf, len)

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

