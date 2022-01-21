from NonameOrm.Error.BaseOrmError import BaseOrmError


class SqlInStanceError(BaseOrmError):

    def _process(self, c, t):
        self.msg = f'无法在{c}语句中添加{t}语句块'


class SqlMissingRelationshipError(BaseOrmError):

    def _process(self,  a,  b):
        self.msg = f'在{a}与{b}之间缺少了关系运算符'


class WhereSQLError(BaseOrmError):
    msg = "无法在未指定操作类型的sql上添加where子句"

class SetSQLError(BaseOrmError):
    msg = "无法在非UPDATE语句中添加SET语句"