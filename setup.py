# cython_ext: language_level=3

from setuptools import setup, Extension
from Cython.Build import cythonize

import os

ex = []

for i, j, k in os.walk('./'):
    for file in k:
        if file.endswith('.pyx'):
            ex.append(Extension('*', [(i if i.endswith('/') else i+'/') + file]))

setup(
    ext_modules=cythonize(ex),
    language_level=3,
    zip_safe=False,
)
