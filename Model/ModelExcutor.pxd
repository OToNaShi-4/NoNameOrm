# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8
from DB.DB cimport DB
from DB.Generator cimport SqlGenerator
from Model.DataModel cimport ModelInstance
from .ModelProperty cimport *

cdef class BaseModelExecutor:

    cdef:
        object model
        SqlGenerator sql
        object work
        DB db
        dict __dict__

    cdef FilterListCell instanceToFilter(self, ModelInstance instance)
    cdef process(self, object res)
    cdef object processSelect(self, tuple res)
    cdef processInsert(self, int res)


cdef class AsyncModelExecutor(BaseModelExecutor):
    pass