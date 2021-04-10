# cython_ext: language_level=3
from Model.ModelProperty cimport BaseProperty
from Model.ModelProperty cimport FilterListCell

cdef enum sqlType:
    SELECT, INSERT, DELETE, UPDATE, NONE

cdef enum JoinType:
    JOIN, LEFT_JOIN, RIGHT_JOIN, INNER_JOIN

cdef class JoinCell:
    cdef:
        JoinType Type
        object key

cdef class BaseSqlGenerator:
    cdef  sqlType currentType
    cdef public tuple Build(self)

cdef class SqlGenerator(BaseSqlGenerator):
    cdef  list selectCol
    cdef  FilterListCell whereCol
    cdef  object target
    cdef  str limit
    cdef:
        list updateCol
        list joinList

    cdef public SqlGenerator update(self, object target)
    cpdef public SqlGenerator From(self, object target)
    cpdef public tuple Build(self)
    cdef tuple build_update(self)
    cdef tuple build_select(self)
    cdef tuple build_where(self)
    cdef tuple build_insert(self)
    cdef tuple build_delete(self)
    @staticmethod
    cdef str _getWhereCellStr(FilterListCell cur, list params)
    cdef str build_join(self)

cdef class TableGenerator(BaseSqlGenerator):
    cdef object model
    cpdef public tuple Build(self)
    @staticmethod
    cdef str build_col(BaseProperty col)