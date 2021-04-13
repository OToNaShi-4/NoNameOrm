import json

from NonameOrm.Ext.Decorators import use_database
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelProperty import *
from NonameOrm.DB.DB import DB
from NonameOrm.DB.Connector import AioMysqlConnector
import asyncio


class Gift(DataModel):
    id = IntProperty(pk=True, default=auto_increment)
    name = StrProperty()
    icon = StrProperty()
    price = FloatProperty()


class abc:

    @use_database
    async def test(self):
        mapper = Gift(name='123123', price=3.23)
        return await Gift.getAsyncExecutor(self).save(mapper)


loop = asyncio.get_event_loop()


async def main():
    res = await abc().test()
    print(res)


if __name__ == '__main__':
    DB.create(connector=AioMysqlConnector(**{
        'host'    : '127.0.0.1',
        'port'    : 3306,
        'db'      : 'test_db',
        'user'    : 'root',
        # 'password': '123456'
        'password': '88888888'
    })).GenerateTable()

    loop.run_until_complete(main())
