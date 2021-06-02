import json
import logging

from NonameOrm.DB.Generator import SqlGenerator
from NonameOrm.Ext.Decorators import use_database
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelProperty import *
from NonameOrm.DB.DB import DB
from NonameOrm.DB.Connector import AioMysqlConnector
import asyncio

DATEFORMAT = '%d-%m-%Y %H:%M:%S'
LOGFORMAT = '[ %(levelname)s - %(pathname)s - %(funcName)s] %(message)s]'


class NewLineFormatter(logging.Formatter):

    def __init__(self, fmt, datefmt=None):
        """
        Init given the log line format and date format
        """
        logging.Formatter.__init__(self, fmt, datefmt)


    def format(self, record):
        """
        Override format function
        """
        msg = logging.Formatter.format(self, record)

        if record.message != "":
            parts = msg.split(record.message)
            msg = msg.replace('\n', '\n' + parts[0])

        return msg

logging.basicConfig(level=logging.DEBUG,handlers=[NewLineFormatter(LOGFORMAT, datefmt=DATEFORMAT)])
logger = logging.getLogger(__name__)
logger.addHandler()


class Person(DataModel):
    id = IntProperty(pk=True, default=auto_increment)
    city = StrProperty()
    id_card_no = StrProperty()
    name = StrProperty()


class User(DataModel):
    id = IntProperty(pk=True, default=auto_increment)
    avatar = StrProperty()
    enable = BoolProperty(default=True)
    locked = BoolProperty(default=False)
    person = ForeignKey(Person, Type=ForeignType.MANY_TO_MANY)


class abc:

    @use_database
    async def test(self):
        user = User({
            'avatar': '123123124',
            'person': [
                {
                    'id': 1,
                    'id_card_no': 'sdhu',
                },
                {
                    'name': '123'
                }
            ]
        })
        res = await User.getAsyncExecutor(self).findAnyMatch(User(id=1))

        await User.getAsyncExecutor(self).findForeignKey(res)
        # res = await User.getAsyncExecutor(self).findAllBy(User.enable == True)
        # res = await User.getAsyncExecutor(self).save(user)
        print(res)



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
        'password': '88888888'
    })).GenerateTable()

    loop.run_until_complete(main())
    # print(Person.user)
