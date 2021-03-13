# cython_ext: language_level=3
from Model.DataModel cimport _DataModel
from Error.SqlError import *

from Model.ModelProperty cimport BaseProperty, FilterListCell, Relationship

cdef enum sqlType:
    SELECT, INSERT, DELETE, UPDATE, NONE

cdef dict relationshipMap = {
    Relationship.AND     : " AND ",
    Relationship.OR      : " OR ",
    Relationship.EQUAL   : " = ",
    Relationship.BIGGER  : " > ",
    Relationship.SMALLER : " < ",
    Relationship.NOTEQUAL: " != ",
}

cdef class SqlGenerator:
    cdef sqlType currentType
    cdef list selectCol
    cdef FilterListCell where
    cdef _DataModel target
    cdef char *limit

    def __init__(self):
        self.selectCol = []
        self.where = None
        self.currentType = NONE
        self.limit = ""

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
        cdef:
            BaseProperty Property
            char *whereTemp
            char *selectTemp = "select "
            list params

        selectTemp += ",".join([Property.name for Property in self.selectCol if Property])
        whereTemp, params = self.build_where()

        return selectTemp + str(self.target.tableName) + whereTemp + self.limit, params

    cdef tuple build_where(self):
        cdef char *whereTemp = " where "
        cdef list params = []
        cdef FilterListCell cur = self.where
        if not cur.next:
            raise SqlInStanceError()
        while True:
            if not cur.next and cur.relationship == Relationship.NONE:
                raise SqlMissingRelationshipError(cur.value, str(cur.next))
            whereTemp += ("?" + relationshipMap.get(cur.relationship, ''))
            params.append(cur.value)
            if not cur.next:
                break
            cur = cur.next
        return whereTemp, params
