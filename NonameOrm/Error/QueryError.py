from NonameOrm.Error.BaseOrmError import BaseOrmError


class QueryResoutIsNotOne(BaseOrmError):
    msg = '查询结果不唯一，请检查'