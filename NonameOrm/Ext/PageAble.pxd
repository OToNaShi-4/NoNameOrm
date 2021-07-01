from NonameOrm.Model.ModelExcutor cimport AsyncModelExecutor
from NonameOrm.Model.ModelProperty cimport FilterListCell

from NonameOrm.Ext.Dict cimport DictPlus

cdef class Page(DictPlus):
    pass

cdef class PageAble:
    cdef:
        object target
        AsyncModelExecutor executor
        FilterListCell filter
        int page, pageSize
        bint deep

