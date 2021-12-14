# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8

from setuptools import setup, Extension
from Cython.Build import cythonize
import os
from os import path as os_path

ex = []

for i, j, k in os.walk('./'):
    for file in k:
        if file.endswith('.pyx'):
            ex.append(Extension('*', [(i if i.endswith('/') else i + '/') + file]))

this_directory = os_path.abspath(os_path.dirname(__file__))


def read_file(filename):
    with open(os_path.join(this_directory, filename), encoding='utf-8') as f:
        long_description = f.read()
    return long_description


def read_requirements(filename):
    return [line.strip() for line in read_file(filename).splitlines()
            if not line.startswith('#')]


setup(
    name='NonameOrm',
    python_requires='>=3.7.0',
    version='1.0.0',  # 包的版本
    author='OToNaShi-4',
    author_email='517431682@qq.com',
    url="https://gitee.com/otonashi-4/python_async_orm",
    description="A Orm support asyncio and sync",
    long_description=read_file('README.md'),  # 读取的Readme文档内容
    long_description_content_type="text/markdown",
    packages=["NonameOrm"],
    include_package_data=True,
    keywords=['asyncio', 'aiomysql', 'orm'],
    install_requires=read_requirements('requirements.txt'),
    package_data={"NonameOrm": ["*.pyi", "**/*.pyi", "*.py", "*/*.py", "*.pxd", "*/*.pxd", '*/*.pyd', '*.pyd']},
    ext_modules=cythonize(ex, compiler_directives={'language_level': "3"}, ),
    zip_safe=False,
    classifiers=[
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Natural Language :: English',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.10',
    ],
)
