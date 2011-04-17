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
    >>> print(a.read())  # read last file

Dependencies
------------

* python 3.2 (sorry, need FS encoding conversion functions)
* libarchive

Performance
-----------

According to my tests libarchive 5-15 times faster that tarfile
