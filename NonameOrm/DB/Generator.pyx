# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8
from typing import List

from NonameOrm.Error.SqlError import *
from NonameOrm.Model.ModelProperty import BaseProperty, FilterListCell
from NonameOrm.Model.ModelProperty cimport Relationship
from NonameOrm.Model.ModelProperty cimport AutoIncrement

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
    def __init__(self, fk, JoinType joinType = JoinType.JOIN):
        self.Type = joinType
        self.key = fk

cdef class BaseSqlGenerator:
    cdef public tuple Build(self):
        return ()

cdef class SqlGenerator(BaseSqlGenerator):
    def __init__(self):
        self.currentType = NONE
        self.limit = ''
        self.target = None

    def insert(self, model):
        if not self.currentType == NONE:
            raise SqlInStanceError(self.currentType, sqlType.INSERT)
        self.currentType = sqlType.INSERT
        self.From(model)
        return self

    def values(self, *args):
        self.selectCol = list(args)
        return self

    def select(self, *args: List[BaseProperty]) -> SqlGenerator:
        if not self.currentType == NONE:
            raise SqlInStanceError(self.currentType, sqlType.SELECT)
        self.currentType = sqlType.SELECT
        self.selectCol = list(args)
        return self

    def delete(self, target):
        if not self.currentType == NONE:
            raise SqlInStanceError(self.currentType, sqlType.DELETE)
        self.From(target)
        self.currentType = sqlType.DELETE
        return self

    cdef public SqlGenerator update(self, object target):
        self.currentType = sqlType.UPDATE
        self.From(target)
        return self

    def set(self, *args)-> SqlGenerator:
        if self.currentType == sqlType.NONE:
            raise SetSQLError()
        self.updateCol = list(args)
        return self

    cpdef public SqlGenerator From(self, object target):
        if isinstance(target, str):
            self.target = target
        else:
            from NonameOrm.Model.DataModel import DataModel
            assert isinstance(target, type) and issubclass(target, DataModel), 'Form仅支持字符串或者DataModel子类'
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
        elif self.currentType == sqlType.INSERT:
            return self.build_insert()
        elif self.currentType == sqlType.DELETE:
            return self.build_delete()

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

    cdef tuple build_delete(self):
        cdef:
            str whereTemp
            list params

        whereTemp, params = self.build_where()

        return "DELETE FROM " + self.target + " " + whereTemp, params

    cdef tuple build_insert(self):
        cdef:
            str insertTemp = "INSERT INTO " + self.target + " "  # INSERT 语句
            dict cur  # 数据指针
            list params = []  # sql参数
            list cols = []
            int i

        # 将插入数据压入列表
        for cur in self.selectCol:
            cols.append((<BaseProperty> cur.get('col')).name)
            params.append(str(cur.get('value')))

        # 拼接完整sql语句
        insertTemp += "(" + ",".join(cols) + ") values (" + ",".join(['%s' for i in range(len(params))]) + ');'

        return insertTemp, params

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
        return updateTemp[:-1] + whereTemp + ";", params + whereParams

    cdef tuple build_select(self):
        cdef:
            BaseProperty Property
            str whereTemp
            str selectTemp = "SELECT "
            list params

        selectTemp += ",".join([f"{Property.model.tableName}.{Property.name}" for Property in self.selectCol if Property])
        whereTemp, params = self.build_where()

        if self.joinList and len(self.joinList):
            return selectTemp + ' FROM ' + self.target + self.build_join() + whereTemp + self.limit + ";", params
        else:
            return selectTemp + ' FROM ' + self.target + whereTemp + self.limit + ";", params

    cdef str build_join(self):
        cdef:
            str joinTemp = "\n"
            JoinCell cell
        for cell in self.joinList:
            foreignKey = cell.key
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

cdef class TableGenerator(BaseSqlGenerator):
    def __init__(self, model):
        self.model = model

    cpdef public tuple Build(self):
        cdef:
            str sqlTemp = "CREATE TABLE " + self.model.tableName + "( \n"
            BaseProperty col

        # 生成列定义语句
        for col in self.model.col:
            sqlTemp += TableGenerator.build_col(col)

        # 添加主键定义
        if self.model.pkCol:
            sqlTemp += "   constraint " + self.model.tableName + "_pk PRIMARY KEY (" + self.model.pkCol.name + ")\n"

        # 收尾
        sqlTemp += ") ENGINE=InnoDB DEFAULT CHARSET=UTF8MB4;"
        print(sqlTemp)
        return sqlTemp,

    @staticmethod
    cdef str build_col(BaseProperty col):
        cdef str temp = "   " + col.name + " "

        # 数据类型
        temp += (col.targetType.value + " ")

        # 是否非空
        temp += "NULL " if col.Null and not col.isPk else "NOT NULL "

        # 是否主键
        if col.isPk:

            temp += "AUTO_INCREMENT " if col._default==AutoIncrement else ""
        else:
            temp += ("DEFAULT " + col.toDBValue(col.Default)) if col.hasDefault else ""

        # 额外定义
        temp += col.define + ",\n"

        return temp
