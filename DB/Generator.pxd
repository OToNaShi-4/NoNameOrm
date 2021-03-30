# cython_ext: language_level=3
from Model.DataModel cimport _DataModel
from Model.ModelProperty cimport FilterListCell

cdef enum sqlType:
    SELECT, INSERT, DELETE, UPDATE, NONE

cdef enum JoinType:
    JOIN, LEFT_JOIN, RIGHT_JOIN, INNER_JOIN

cdef class JoinCell:
    cdef:
        JoinType Type
        object key

cdef class SqlGenerator:
    cdef  sqlType currentType
    cdef  list selectCol
    cdef  FilterListCell whereCol
    cdef  object target
    cdef  str limit
    cdef:
        list updateCol
        list joinList


    cdef public SqlGenerator update(self, _DataModel target)
    cpdef public SqlGenerator From(self, object target)
    cpdef public tuple Build(self)
    cdef tuple build_update(self)
    cdef tuple build_select(self)
    cdef tuple build_where(self)
    @staticmethod
    cdef str _getWhereCellStr(FilterListCell cur, list params)
    cdef str build_join(self)