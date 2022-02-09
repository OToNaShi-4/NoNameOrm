import logging

import faker

from NonameOrm.DB.Connector import AioMysqlConnector, AioSqliteConnector, Sqlite3Connector
from NonameOrm.DB.DB import DB
from NonameOrm.Ext.DataGenerator import data_task, GeneratorRunner
from NonameOrm.Ext.Decorators import use_database
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelProperty import *
import asyncio
from faker import Faker

from NonameOrm.DB.Generator import SqlGenerator

loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)

from NonameOrm.Ext.PageAble import PageAble

fake = Faker(loacale='zh_CN')

logging.basicConfig(level=logging.DEBUG, format='[ %(levelname)s - %(pathname)s - %(funcName)s] %(message)s')
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
        res = await User.getAsyncExecutor().findAllBy()
        print(res)


async def main():
    res = await abc().test()
    print(res)


@data_task(count=10)
def user_generator(time=1):
    name = fake.name()

    return User(
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
    )


if __name__ == '__main__':
    DB.create(connector=Sqlite3Connector(path=':memory:', showLog=False)).GenerateTable()

    GeneratorRunner().run()

    sql = SqlGenerator().From(User)

    print(User.getExecutor().findAllBy(User.nickname.has('a')))

    # loop.run_until_complete(main())
    pass
