# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8
from typing import List

from Model.DataModel import DataModel
from Model.DataModel cimport _DataModel
from Error.SqlError import *
from Model.ModelProperty cimport BaseProperty, FilterListCell, Relationship
from Model.ModelProperty import ForeignKey

cdef dict relationshipMap = {
    Relationship.AND          : " AND ",
    Relationship.OR           : " OR ",
    Relationship.EQUAL        : " = ",
    Relationship.BIGGER       : " > ",
    Relationship.SMALLER      : " < ",
    Relationship.NOTEQUAL     : " != ",
    Relationship.BIGGER_EQUAL : " >= ",
    Relationship.SMALLER_EQUAL: " <= ",
}

cdef dict joinTypeMap = {
    JOIN      : "JOIN ",
    LEFT_JOIN : "LEFT JOIN ",
    RIGHT_JOIN: "RIGHT JOIN ",
    INNER_JOIN: "INNER JOIN ",
}

cdef class JoinCell:
    def __init__(self, fk: ForeignKey, JoinType joinType = JoinType.JOIN):
        self.Type = joinType
        self.key = fk

cdef class SqlGenerator:
    def __init__(self):
        self.selectCol = []
        self.currentType = NONE
        self.limit = ''
        self.joinList = []

    def insert(self, model: DataModel):
        if not self.currentType == NONE:
            raise SqlInStanceError(self.currentType, sqlType.INSERT)
        self.target = model
        return self

    def select(self, *args: List[BaseProperty]) -> SqlGenerator:
        if not self.currentType == NONE:
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

    def join(self, object foreignKey, joinType: JoinType = JoinType.JOIN) -> SqlGenerator:
        self.joinList.append(JoinCell(foreignKey, joinType))
        return self

    def leftJoin(self, object foreignKey) -> SqlGenerator:
        return self.join(foreignKey, JoinType.LEFT_JOIN)

    def rightJoin(self, object foreignKey) -> SqlGenerator:
        return self.join(foreignKey, JoinType.RIGHT_JOIN)

    def innerJoin(self, object foreignKey) -> SqlGenerator:
        return self.join(foreignKey, JoinType.INNER_JOIN)

    cdef tuple build_update(self):
        cdef:
            str updateTemp = "UPDATE " + self.target + " SET "
            dict cur
            list params = []
            str whereTemp
            list whereParams
        for cur in self.updateCol:
            updateTemp += cur['name'] + " = %s,"
            params.append(str(cur['value']))

        whereTemp, whereParams = self.build_where()
        return updateTemp[:-1] + whereTemp, params + (<list> whereParams) + ";"

    cdef tuple build_select(self):
        cdef:
            BaseProperty Property
            str whereTemp
            str selectTemp = "SELECT "
            list params

        selectTemp += ",".join([f"{Property.model.tableName}.{Property.name}" for Property in self.selectCol if Property])
        whereTemp, params = self.build_where()

        if len(self.joinList):
            return selectTemp + ' FROM ' + self.target + self.build_join() + whereTemp + self.limit + ";", params
        else:
            return selectTemp + ' FROM ' + self.target + whereTemp + self.limit + ";", params

    cdef str build_join(self):
        cdef:
            str joinTemp = "\n"
            JoinCell cell
        for cell in self.joinList:
            foreignKey: ForeignKey = cell.key
            joinTemp += "       " + joinTypeMap.get(cell.Type) + \
                        foreignKey.target.tableName + \
                        " on " + foreignKey.owner.tableName + "." + foreignKey.owner.pkName + " = " + \
                        foreignKey.target.tableName + "." + foreignKey.target.pkName + "\n"
        return joinTemp

    cdef tuple build_where(self):
        cdef str whereTemp = " WHERE "
        cdef list params = []

        if not self.whereCol:
            return '', params
        cdef FilterListCell cur = self.whereCol
        if not cur.next:
            raise SqlInStanceError()
        while True:
            if cur.next and cur.relationship == Relationship.NONE:
                raise SqlMissingRelationshipError(cur.value, str(cur.next))
            whereTemp += SqlGenerator._getWhereCellStr(cur, params)
            if not cur.next:
                break
            cur = cur.next
        return whereTemp, params

    @staticmethod
    cdef str _getWhereCellStr(FilterListCell cur, list params):
        if cur.col:
            return cur.col.model.tableName + "." + cur.value + " " + relationshipMap.get(cur.relationship, '')
        else:
            params.append(str(cur.value))
            return " %s " + relationshipMap.get(cur.relationship, '')
