Pyarchive
=========

Pyarchive is a python bindings for libarchive.


Usage
-----

::

    >>> import archive
    >>> a = archive.Archive('test.tgz')
    >>> for i in a:
    ...   print(a.filename)
    >>> print(a.read())  # last file read

Dependencies
------------

* python 3.2 (sorry, need FS encoding conversion functions)
* libarchive

