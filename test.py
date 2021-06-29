import json
import logging

from NonameOrm.Ext.Decorators import use_database
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelProperty import *
from NonameOrm.DB.DB import DB
from NonameOrm.DB.Connector import AioMysqlConnector
import asyncio

logging.basicConfig(level=logging.DEBUG, format='[ %(levelname)s - %(pathname)s - %(funcName)s] %(message)s')
logger = logging.getLogger(__name__)


class Role(DataModel):
    id = IntProperty(pk=True)
    name = StrProperty(typeArgs=(10,))


class Person(DataModel):
    id = IntProperty(pk=True)
    city = StrProperty(typeArgs=(10,))
    id_card_no = StrProperty(typeArgs=(10,))
    name = StrProperty(typeArgs=(10,))
    roles = ForeignKey(Role, ForeignType.MANY_TO_MANY)


class User(DataModel):
    id = IntProperty(pk=True, default=auto_increment)
    avatar = StrProperty(typeArgs=(10,))
    enable = BoolProperty(default=True, targetType=boolSupportType.tinyInt)
    locked = BoolProperty(default=False, targetType=boolSupportType.tinyInt)
    person = ForeignKey(Person)


class abc:

    @use_database
    async def test(self):
        instance = await User.getAsyncExecutor(self).findAllBy(User.id == 1)
        await User.getAsyncExecutor().findForeignKey(instance[0],deep=True)
        return instance


loop = asyncio.get_event_loop()


async def main():
    res = await abc().test()
    print(res)


if __name__ == '__main__':
    DB.create(connector=AioMysqlConnector(**{
        'host': '127.0.0.1',
        'port': 3306,
        'db': 'test_db',
        'user': 'root',
        # 'password': '123456'
        'password': '888888'
    })).GenerateTable()

    loop.run_until_complete(main())
