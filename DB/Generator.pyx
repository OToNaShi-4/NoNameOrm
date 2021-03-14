# cython_ext: language_level=3
from Model.DataModel cimport _DataModel
from Error.SqlError import *

from Model.ModelProperty cimport BaseProperty, FilterListCell, Relationship

cdef dict relationshipMap = {
    Relationship.AND     : " AND ",
    Relationship.OR      : " OR ",
    Relationship.EQUAL   : " = ",
    Relationship.BIGGER  : " > ",
    Relationship.SMALLER : " < ",
    Relationship.NOTEQUAL: " != ",
    Relationship.BIGGER_EQUAL: " >= ",
    Relationship.SMALLER_EQUAL: " <= ",
}

cdef class SqlGenerator:
    def __init__(self):
        self.selectCol = []
        self.currentType = sqlType.NONE
        self.limit =''

    def select(self, *args) -> SqlGenerator:
        if not self.currentType == sqlType.NONE:
            raise SqlInStanceError(self.currentType, sqlType.SELECT)
        self.currentType = sqlType.SELECT
        self.selectCol = list(args)
        return self

    cdef public SqlGenerator update(self, _DataModel target):
        self.currentType = sqlType.UPDATE
        self.target = target
        return self

    def set(self, *args)-> SqlGenerator:
        if self.currentType == sqlType.NONE:
            raise SetSQLError()
        self.updateCol = args
        pass

    cpdef public SqlGenerator From(self, object target):
        self.target = target.tableName
        return self

    def where(self, FilterListCell args=None) -> SqlGenerator:
        if self.currentType == sqlType.NONE:
            raise WhereSQLError()
        self.whereCol = args
        return self

    cpdef public tuple Build(self):
        if self.currentType == sqlType.SELECT:
            return self.build_select()
        elif self.currentType == sqlType.UPDATE:
            return self.build_update()

    def Limit(self, int count, int offset) -> SqlGenerator:
        self.limit = "limit %i %i" % (count, offset)
        return self

    cdef tuple build_update(self):
        cdef:
            str updateTemp = "UPDATE " + self.target + " SET "
            dict cur
            list params = []
            str whereTemp
            list whereParams
        for cur in self.updateCol:
            updateTemp += cur['name'] + " = ?,"
            params.append(cur['value'])

        whereTemp, whereParams = self.build_where()
        return updateTemp[:-1] + whereTemp, params + (<list> whereParams)

    cdef tuple build_select(self):
        cdef:
            BaseProperty Property
            str whereTemp
            str selectTemp = "SELECT "
            list params


        selectTemp += ",".join([Property.name for Property in self.selectCol if Property])

        whereTemp, params = self.build_where()

        return selectTemp + ' FROM ' + self.target + whereTemp + self.limit, params

    cdef tuple build_where(self):
        cdef str whereTemp = " WHERE "
        cdef list params = []

        if not self.whereCol:
            return '', []
        cdef FilterListCell cur = self.whereCol
        if not cur.next:
            raise SqlInStanceError()
        while True:
            if cur.next and cur.relationship == Relationship.NONE:
                raise SqlMissingRelationshipError(cur.value, str(cur.next))
            whereTemp += ("?" + relationshipMap.get(cur.relationship, ''))
            params.append(cur.value)
            if not cur.next:
                break
            cur = cur.next
        return whereTemp, params
