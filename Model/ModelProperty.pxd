from enum import Enum

cdef class BaseProperty:
    cdef public str name
    cdef type _Type
    cdef public bint isPk
    cdef public bint Null

    cdef public object _default
    cdef object targetType

    cpdef public bint sizeChecker(self, object value)
    cpdef public bint verifier(self, object value)
    cdef public toDBValue(self, value)
    cdef public toObjValue(self, value)

cdef enum Relationship:
    AND
    OR
    EQUAL
    BIGGER
    SMALLER
    NOTEQUAL
    NONE


cdef class FilterListCell:
    cdef char * value
    cdef Relationship relationship
    cdef FilterListCell next

    cdef FilterListCell append(self, FilterListCell cell)
