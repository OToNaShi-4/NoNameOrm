import json
import logging

from NonameOrm.Ext.Decorators import use_database
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelProperty import *
from NonameOrm.DB.DB import DB
from NonameOrm.DB.Connector import AioMysqlConnector
import asyncio
from faker import Faker

from NonameOrm.Ext.PageAble import PageAble

fake = Faker(loacale='zh_CN')

logging.basicConfig(level=logging.DEBUG, format='[ %(levelname)s - %(pathname)s - %(funcName)s] %(message)s')
logger = logging.getLogger(__name__)


class User(DataModel):
    id = IntProperty(pk=True, default=auto_increment, Null=False)
    username = StrProperty(typeArgs=(35,), Null=False)
    nickname = StrProperty(typeArgs=(35,), Null=False)
    password = StrProperty(typeArgs=(33,), Null=False)
    avatar = StrProperty(targetType=strSupportType.tinyText)
    email = StrProperty(typeArgs=(100,))
    create_time = StrProperty(typeArgs=(255,))
    update_time = StrProperty(typeArgs=(255,))
    is_delete = BoolProperty(default=False)


class abc:

    @use_database
    async def test(self):
        return await PageAble(User).filter(User.is_delete == False).execute()


loop = asyncio.get_event_loop()


async def main():
    res = await abc().test()
    print(res)

if __name__ == '__main__':
    DB.create(connector=AioMysqlConnector(**{
            'host'    : '127.0.0.1',
            'port'    : 3306,
            'db'      : 'test',
            'user'    : 'root',
            'password': '888888'
    })).GenerateTable()

    loop.run_until_complete(main())
