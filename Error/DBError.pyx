from .BaseOrmError import *
class DBInstanceError(BaseOrmError):
    msg:str = "DB链接对象实例已存在，不可重新创建"

class DBInstanceCreateError(BaseOrmError):
    msh:str = "请使用DB.create()创建数据库实例"