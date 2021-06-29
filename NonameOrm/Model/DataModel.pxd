


cdef class _DataModel:
    cdef tuple col
    cdef dict mapping
    cdef modelInstance
    cdef public str tableName

cdef class InstanceList(list):
    cdef int len(self)
    pass

cdef class ModelInstance(dict):
    cdef dict _temp
    pass