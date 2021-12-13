from NonameOrm.Model.ModelExcutor cimport AsyncModelExecutor,BaseModelExecutor
from NonameOrm.Model.ModelProperty cimport FilterListCell

from NonameOrm.Ext.Dict cimport DictPlus

cdef class Page(DictPlus):
    pass

cdef class PageAble:
    cdef:
        object target
        BaseModelExecutor executor
        FilterListCell filter
        int page, pageSize
        bint deep

    cpdef Page _execute(self)