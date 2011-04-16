from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext

setup(name='pyarchive',
    version='0.1',
    description='Python wrapper for libarchive',
    author='Paul Colomiets',
    author_email='pc@gafol.net',
    url='http://github.com/tailhook/pyarchive',
    classifiers=[
        'Programming Language :: Python :: 3',
        'License :: OSI Approved :: MIT License',
        ],
    packages=['archive'],
    cmdclass = {'build_ext': build_ext},
    ext_modules = [Extension("archive.core",
        ["archive/core.pyx"],
        libraries = ['archive'],
        )],
    )
