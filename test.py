import logging

import faker

from NonameOrm.DB.Connector import AioMysqlConnector, AioSqliteConnector
from NonameOrm.DB.DB import DB
from NonameOrm.Ext.Decorators import use_database
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelProperty import *
import asyncio
from faker import Faker

loop = asyncio.new_event_loop()

asyncio.set_event_loop(loop)

from NonameOrm.Ext.PageAble import PageAble

fake = Faker(loacale='zh_CN')

logging.basicConfig(level=logging.ERROR, format='[ %(levelname)s - %(pathname)s - %(funcName)s] %(message)s')
logger = logging.getLogger(__name__)


class Person(DataModel):
    id = IntProperty(pk=True, Null=False)
    real_name = StrProperty(typeArgs=(8,), Null=False)
    id_card = StrProperty(typeArgs=(24,), Null=False)
    phone = StrProperty(typeArgs=(16,))
    addr = StrProperty(typeArgs=(60,))
    gender = BoolProperty(default=False, Null=False)
    birth_day = TimestampProperty()
    nation = StrProperty(typeArgs=(10,))
    student_id = StrProperty(typeArgs=(18,))
    student_class = StrProperty(typeArgs=(18,))
    specialized_subject = StrProperty(typeArgs=(14,))
    academy = StrProperty(typeArgs=(10,))
    position = StrProperty(typeArgs=(10,))


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
    person = ForeignKey(Person)


class abc:

    async def test(self):
        name = fake.name()
        await User.getAsyncExecutor().save(User(
            username=name,
            nickname=fake.name(),
            password=fake.name(),
            email=fake.ascii_email(),
            person=Person(
                phone=fake.phone_number(),
                real_name=fake.name(),
                gender=True,
                id_card=fake.phone_number()
            )
        ))

        res = await PageAble(User).filter(User.username == name).findForeign().execute()

        # res = await User.getAsyncExecutor().findAllBy(User.username == name)
        print(res)


async def main():
    res = await abc().test()
    print(res)


if __name__ == '__main__':
    DB.create(connector=AioSqliteConnector(loop=loop, path=':memory:')).GenerateTable()

    loop.run_until_complete(main())
    pass
