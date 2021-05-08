import json

from NonameOrm.Ext.Decorators import use_database
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelProperty import *
from NonameOrm.DB.DB import DB
from NonameOrm.DB.Connector import AioMysqlConnector
import asyncio


class Person(DataModel):
    id = IntProperty(pk=True)
    city = StrProperty()
    id_card_no = StrProperty()
    name = StrProperty()


class User(DataModel):
    id = IntProperty(pk=True, default=auto_increment)
    avatar = StrProperty()
    enable = BoolProperty(default=True, targetType=boolSupportType.bit)
    locked = BoolProperty(default=False, targetType=boolSupportType.bit)
    person_id = IntProperty()
    # person = ForeignKey(Person, bindCol=person_id)


class abc:

    @use_database
    async def test(self):
        mapper = User(id=32)
        instance = await User.getAsyncExecutor(self).getAnyMatch(mapper)
        return instance
        # return await User.getAsyncExecutor(self).findForeignKey(instance)


loop = asyncio.get_event_loop()


async def main():
    res = await abc().test()
    print(res)


if __name__ == '__main__':
    DB.create(connector=AioMysqlConnector(**{
        'host': '127.0.0.1',
        'port': 3306,
        'db': 'cy_live_dev',
        'user': 'root',
        # 'password': '123456'
        'password': '888888'
    }))

    loop.run_until_complete(main())
