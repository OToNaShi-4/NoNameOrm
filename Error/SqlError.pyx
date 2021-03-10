from Error.BaseOrmError import BaseOrmError

class SqlInStanceError(BaseOrmError):

    def _process(self, c, t):
        self.msg = f'无法在{c}语句中添加{t}语句块'