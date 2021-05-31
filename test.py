import json
import logging

from NonameOrm.DB.Generator import SqlGenerator
from NonameOrm.Ext.Decorators import use_database
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelProperty import *
from NonameOrm.DB.DB import DB
from NonameOrm.DB.Connector import AioMysqlConnector
import asyncio

logging.basicConfig(level=logging.DEBUG, format='[ %(levelname)s - %(pathname)s - %(funcName)s] %(message)s')
logger = logging.getLogger(__name__)


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
    person = ForeignKey(Person, Type=ForeignType.MANY_TO_MANY)


class abc:

    @use_database
    async def test(self):
        user = User({
            "avatar": "https://thirdwx.qlogo.cn/mmopen/vi_32/DYAIOgq83ep0Cb1HGLBTDxicbia9s5Pc7l94uHD7BfcQIhibVXVAlYK9Y5ayibCEcqlOAYSaNneQ6YeUiaiaTwDibM7bA/132",
            "enable": True,
            "locked": True,
            "person": {
                "city": None,
                "id_card_no": "Vvv",
                "name": "Vvvv"
            }
        })
        await User.getAsyncExecutor().find(User.id, User.locked).By((User.id == 3) & (User.locked == False))


loop = asyncio.get_event_loop()


async def main():
    res = await abc().test()
    print(res)


if __name__ == '__main__':
    # DB.create(connector=AioMysqlConnector(**{
    #     'host': '127.0.0.1',
    #     'port': 3306,
    #     'db': 'test_db',
    #     'user': 'root',
    #     # 'password': '123456'
    #     'password': '88888888'
    # })).GenerateTable()
    # print(User.person.target.getOtherFkBy(User))
    sql = SqlGenerator()
    res = sql.select(*Person.col).From(Person).join(Person.user).where(User.person.middleModel.user_id == 1).Build()
    print(res)
    # loop.run_until_complete(main())
    # print(Person.user)

