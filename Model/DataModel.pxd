from Model.ModelProperty cimport BaseProperty

cdef class _DataModel:
    cdef tuple col
    cdef dict mapping
    cdef modelInstance
    cdef public str tableName
