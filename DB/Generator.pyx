from Model.DataModel cimport _DataModel
# # from Model.ModelProperty import *
from Error.SqlError import *
#
#
from Model.ModelProperty cimport BaseProperty, FilterCell
#
cdef enum sqlType:
    SELECT, INSERT, DELETE, UPDATE, NONE

cdef class SqlGenerator:
    cdef sqlType currentType
    cdef list selectCol
    cdef list where
    cdef _DataModel target
    cdef char *limit

    def __init__(self):
        self._init()

    cdef void _init(self):
        self.selectCol = []
        self.where = []
        self.currentType = NONE
        self.limit = ''

    def select(self, *args) -> SqlGenerator:
        if self.currentType == sqlType.NONE:
            raise SqlInStanceError(self.currentType, sqlType.SELECT)
        self.currentType = sqlType.SELECT
        self.selectCol = args
        return self

    cdef public SqlGenerator From(self, _DataModel target):
        self.target = target
        return self

    def where(self, *args) -> SqlGenerator:
        self.where = args
        return self

    cdef public tuple Build(self):
        if self.currentType == sqlType.SELECT:
            return self.build_select()

    def limit(self, int count, int offset) -> SqlGenerator:
        self.limit = "limit %i %i" % (count, offset)
        return self

    cdef tuple build_select(self):
        cdef BaseProperty Property
        cdef char * selectTemp = 'select '
        for Property in self.selectCol:
            selectTemp += Property.name

        cdef char * whereTemp = ' where '
        cdef FilterCell d
        for d in self.where:

            pass
        return ()
