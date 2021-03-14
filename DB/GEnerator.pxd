from Model.DataModel cimport _DataModel
from Model.ModelProperty cimport FilterListCell

cdef enum sqlType:
    SELECT, INSERT, DELETE, UPDATE, NONE

cdef class SqlGenerator:
    cdef  sqlType currentType
    cdef  list selectCol
    cdef  FilterListCell whereCol
    cdef  target
    cdef  str limit
    cdef  list updateCol

    cdef public SqlGenerator update(self, _DataModel target)
    cpdef public SqlGenerator From(self, object target)
    cpdef public tuple Build(self)
    cdef tuple build_update(self)
    cdef tuple build_select(self)
    cdef tuple build_where(self)
