from DB.Generator cimport SqlGenerator
from Model.ModelProperty cimport BaseProperty

cdef class _DataModel:
    cdef tuple col
    cdef dict mapping
    cdef modelInstance
    cdef public str tableName


cdef class ModelExecutor:

    cdef:
        object model
        SqlGenerator sql
