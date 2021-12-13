# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8

from setuptools import setup, Extension
from Cython.Build import cythonize
import os

ex = []

for i, j, k in os.walk('./'):
    for file in k:
        if file.endswith('.pyx'):
            ex.append(Extension('*', [(i if i.endswith('/') else i + '/') + file]))

setup(
        name='NonameOrm',
        python_requires='>=3.7.0',
        version='1.0.0',  # 包的版本
        author='OToNaShi-4',
        author_email='517431682@qq.com',
        url="https://gitee.com/otonashi-4/python_async_orm",
        description="A Orm support asyncio and sync",
        packages=["NonameOrm"],
        package_data={"NonameOrm": ["*.pyi", "**/*.pyi", "*.py", "*/*.py", "*.pxd", "*/*.pxd"]},
        ext_modules=cythonize(ex, compiler_directives={'language_level': "3"}, ),
        zip_safe=False,
)
