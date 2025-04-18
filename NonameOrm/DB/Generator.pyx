# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8
import ast
from typing import List, Iterable, Union
from NonameOrm.Error.SqlError import *
from NonameOrm.Model.ModelProperty import BaseProperty, FilterListCell, NullDefault
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
    Relationship.LIKE         : " LIKE "
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

cdef class CustomColAnnounce(BaseSqlGenerator):
    def __init__(self, str announce):
        self.announce = announce

    cdef public tuple Build(self):
        return self.announce, None

cdef class SqlGenerator(BaseSqlGenerator):
    def __init__(self):
        self.currentType = NONE
        self.limit = ' '
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

    cpdef public SqlGenerator update(self, object target):
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
        self.limit = " limit %i, %i" % (offset, count)
        return self

    def orderBy(self, *args):
        self.orderList = args
        pass

    def join(self, object foreignKey, joinType: JoinType = JoinType.JOIN) -> SqlGenerator:
        self.joinList.append(JoinCell(foreignKey, joinType))
        if foreignKey.target is not foreignKey.directTarget:
            self.joinList.append(JoinCell(foreignKey.target.getOtherFkBy(foreignKey.owner), joinType))
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

        whereTemp, params = SqlGenerator.build_where(self.whereCol)

        return "DELETE FROM " + self.target + " " + whereTemp, tuple(params)

    cdef tuple build_insert(self):
        from NonameOrm.DB.DB import DB
        cdef:
            str insertTemp = "INSERT INTO " + self.target + " "  # INSERT 语句
            dict cur  # 数据指针
            list params = []  # sql参数
            list cols = []
            int i
            int ct = DB.getInstance()._connector.con_type

        # 将插入数据压入列表
        for cur in self.selectCol:
            if ct == 1:
                cols.append(f"""'{(<BaseProperty> cur.get('col')).name}'""")
            elif ct == 0:
                cols.append(f"""{self.target}.{(<BaseProperty> cur.get('col')).name}""")
            params.append(cur.get('value'))

        # 拼接完整sql语句
        insertTemp += "(" + ",".join(cols) + ") values (" + ",".join(['%s' for i in range(len(params))]) + ');'

        return insertTemp, tuple(params)

    cdef tuple build_update(self):
        cdef:
            str updateTemp = "UPDATE " + self.target + " SET "
            dict cur
            list params = []
            str whereTemp
            list whereParams

        for cur in self.updateCol:
            updateTemp += '`' + cur['name'] + "` = %s,"
            params.append(cur['value'])
        whereTemp, whereParams = SqlGenerator.build_where(self.whereCol)
        return updateTemp[:-1] + whereTemp + ";", tuple(params + whereParams)

    @staticmethod
    cdef str build_order(tuple orderList):
        """
        生成 orderBy 子句
        
        :return: orderBy 子句内容 
        """
        if not orderList or len(orderList) == 0:
            return ""

        cdef:
            int i
            int length = len(orderList)
            str orderTemp = " order by "


        for i in range(length):
            orderTemp += orderList[i]
            if not i == length - 1:
                orderTemp += ", "
        return orderTemp

    cdef tuple build_select(self):
        """
        生成select子句
        
        :return: select 子句 
        """
        cdef:
            BaseProperty Property
            str whereTemp
            str selectTemp = "SELECT "
            list params

        selectTemp += ",".join(
            [f"{Property.model.tableName}.{Property.name}" for Property in self.selectCol if Property])
        whereTemp, params = SqlGenerator.build_where(self.whereCol)

        if self.joinList and len(self.joinList):
            return selectTemp + ' FROM ' + self.target + self.build_join() + whereTemp + SqlGenerator.build_order(self.orderList) + self.limit + ";", tuple(params)
        else:
            return selectTemp + ' FROM ' + self.target + whereTemp + SqlGenerator.build_order(self.orderList) + self.limit + ";", tuple(params)

    cdef str build_join(self):
        cdef:
            str joinTemp = "\n"
            JoinCell cell
        for cell in self.joinList:
            foreignKey = cell.key
            joinTemp += "       " + joinTypeMap.get(cell.Type) + \
                        foreignKey.target.tableName + \
                        " on " + foreignKey.owner.tableName + "." + foreignKey.bindCol.name + " = " + \
                        foreignKey.target.tableName + "." + foreignKey.targetBindCol.name + "\n"
        return joinTemp

    @staticmethod
    cdef tuple build_where(FilterListCell whereCol):
        cdef str whereTemp = " WHERE "
        cdef list params = []
        cdef:
            tuple args


        if not whereCol:
            return '', params
        cdef FilterListCell cur = whereCol

        if not cur.next and not isinstance(cur.value, BaseSqlGenerator):
            raise SqlInStanceError()
        while True:
            # 若过滤节点的内容为 sql 生成器， 则执行其build方法
            if isinstance(cur.value, BaseSqlGenerator):
                sql, args = cur.value.Build()
                params.extend(args)
                whereTemp += sql + relationshipMap.get(cur.relationship, '')
            elif cur.next and cur.relationship == Relationship.NONE:
                raise SqlMissingRelationshipError(cur.value, str(cur.next))
            else:
                whereTemp += SqlGenerator._getWhereCellStr(cur, params)
            if not cur.next:
                break
            cur = cur.next
        return whereTemp, params

    @property
    def joinList(self):
        if not self._joinList:
            self._joinList = []
        return self._joinList

    @staticmethod
    cdef str _getWhereCellStr(FilterListCell cur, list params):
        if cur.col:
            return cur.col.model.tableName + "." + cur.value + " " + relationshipMap.get(cur.relationship, '')
        else:
            params.append(cur.value)
            return " %s " + relationshipMap.get(cur.relationship, '')

cdef class CustomSqlGenerator(BaseSqlGenerator):
    """
    自定义sql生成器
    """
    def __init__(self, str sql, tuple args):
        self.sql = sql
        self.args = args

    cpdef public tuple Build(self):
        return self.sql, self.args

cdef class InOperatorGenerator(BaseSqlGenerator):
    """
        用于生成in操作符 对应的sql语句
        可传入 模型实例， 非字典等其他出去
    """

    def __init__(self, others: Union[list, tuple], BaseProperty pro):
        from NonameOrm.Model.DataModel import ModelInstance
        # from NonameOrm.Error.DBError import InOperatorError

        cdef:
            int index
            list temp = []
        for index in range(len(others)):
            item = others[index]
            if isinstance(item, ModelInstance):
                temp.append(item[item.object.pkName])
            elif isinstance(item, (dict, list, tuple)):
                raise
            else:
                temp.append(item)
        self.temp = temp
        self.property = pro

    cpdef public tuple Build(self):
        cdef:
            str temp = ' ' + self.property.model.tableName + '.' + self.property.dbName + ' in ('
            int index
            list args = []

        for index in range(len(self.temp)):
            temp += '%s, '  # 使用%s占位符
            args.append(self.temp[index])

        temp = temp[0:-2] + ') '

        return temp, tuple(args)

cdef class QueryGroup(BaseSqlGenerator):
    def __init__(self, FilterListCell query):
        self.query = query
        pass

    cpdef public tuple Build(self):
        cdef:
            list args
            str sql
        sql, args = SqlGenerator.build_where(self.query)
        return " (" + sql.replace('WHERE ', '') + ") ", tuple(args)

cdef class FunctionCall(BaseSqlGenerator):
    def __init__(self, str func_name, *args):
        self.func_name = func_name
        self.args = args

    cpdef public tuple Build(self):
        cdef:
            str sql = self.func_name + '('
            int index
            tuple temp
            BaseProperty pro
            list params = []


        for index in range(len(self.args)):
            if isinstance(self.args[index], BaseSqlGenerator):
                temp = self.args[index].Build()
                sql += temp[0] + ", "
                params += temp[1]
            elif isinstance(self.args[index], BaseProperty):
                pro = self.args[index]
                sql += pro.model.tableName + '.' + pro.dbName + ", "
            else:
                sql += '%s, '
                params.append(self.args[index])

        sql = sql[0:-2] + ') '


        return sql, tuple(params)


def Q(FilterListCell query) -> FilterListCell:
    return FilterListCell(QueryGroup(query))

cdef class TableGenerator(BaseSqlGenerator):
    def __init__(self, model):
        self.model = model

    cpdef public tuple Build(self):
        cdef:
            str sqlTemp = "CREATE TABLE " + self.model.tableName + "( \n"
            BaseProperty col
            int index

            # 生成列定义语句
        for index in range(len(self.model.col)):
            col = self.model.col[index]
            sqlTemp += TableGenerator.build_col(col)

        # 添加主键定义
        if self.model.pkCol:
            sqlTemp += "   constraint " + self.model.tableName + "_pk PRIMARY KEY (" + self.model.pkCol.name + ")\n"

        # 收尾
        if sqlTemp.endswith(',\n'):
            sqlTemp = sqlTemp[:-2] + '\n'
        sqlTemp += ") ;"
        return sqlTemp,

    @staticmethod
    cdef str build_col(BaseProperty col):
        cdef:
            str temp = "   `" + col.name + "` "
            str typeArgs = str(col.typeArgs).replace(",", "") if str(col.typeArgs).endswith(",)") else str(col.typeArgs) if len(col.typeArgs) else ''


        # 是否主键
        if col.isPk:
            temp += buildDefault(col)
        else:
            # 数据类型
            temp += (col.targetType + typeArgs + " ")
            # 是否非空
            temp += "NULL " if col.Null else "NOT NULL "
            temp += ("DEFAULT " + buildDefault(col)) if col.hasDefault else ""

        # 额外定义
        temp += col.define + ",\n"

        return temp

cdef str buildDefault(BaseProperty col):
    if isinstance(col._default, BaseSqlGenerator):
        return (<BaseSqlGenerator> col._default).Build()[0]
    elif col.isPk:
        if col._default == AutoIncrement:
            from NonameOrm.DB.DB import DB
            return DB.getInstance().connector.autoFiledAnnounce(col)
        else:
            # 数据类型
            temp = ''
            typeArgs = str(col.typeArgs).replace(",", "") if str(col.typeArgs).endswith(",)") else str(col.typeArgs) if len(col.typeArgs) else ''
            temp += (col.targetType + typeArgs + " ")
            # 是否非空
            temp += "NULL " if col.Null else "NOT NULL "
            return temp

    elif isinstance(col._default, NullDefault) or col._default is NullDefault:
        return ''
    else:
        return _processValue(col.toDBValue(col._default))

cdef _processValue(object data):
    if isinstance(data, bytes):
        return '1' if data == b'\x01' else '0'
    if isinstance(data, str):
        return "'" + data + "'"
    return str(data)

cdef str BuildAlterColSql(str tableName, assignNode: ast.Assign):
    cdef:
        str colName = assignNode.targets[0].id
        str
    return "ALTER TABLE " + tableName + "\n    add " + colName
