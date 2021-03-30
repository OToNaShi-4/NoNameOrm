from .BaseOrmError import *
class DBInstanceError(BaseOrmError):
    msg:str = "DB链接对象实例已存在，不可重新创建"

class DBInstanceCreateError(BaseOrmError):
    msh:str = "请使用DB.create()创建数据库实例"

class WriteOperateNotInAffairs(BaseOrmError):
    msg:str = "写操作需要在事务中执行"