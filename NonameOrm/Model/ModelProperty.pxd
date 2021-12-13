# cython_ext: language_level=3
from NonameOrm.DB.Generator cimport CustomColAnnounce






cdef class NullDefault:
    pass

cdef class AutoIncrement:
    pass

cdef class BaseProperty:
    cdef public str name
    cdef type _Type
    cdef public bint isPk
    cdef public bint Null
    cdef public object _default
    cdef public object _targetType
    cdef object model
    cdef str define
    cdef public tuple typeArgs

    cpdef public bint sizeChecker(self, object value)
    cpdef public bint verifier(self, object value)
    cdef public str desc(self)
    cdef public str asc(self)

    cpdef FilterListCell setFilter(self, object other, Relationship relationship)

cdef enum Relationship:
    AND
    OR
    EQUAL
    BIGGER
    BIGGER_EQUAL
    SMALLER
    SMALLER_EQUAL
    NOTEQUAL
    NONE
    LIKE

cdef class FilterListCell:
    cdef public object value
    cdef public Relationship relationship
    cdef public FilterListCell next
    cdef public BaseProperty col

    cpdef FilterListCell append(self, FilterListCell cell, Relationship relationship)
    cpdef _add(self, object other, Relationship relationship)

