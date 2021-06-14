import json
import logging
import time
from typing import TypedDict

from typed_ast import ast3
import ast
import astor
from NonameOrm.DB.Generator import SqlGenerator
from NonameOrm.Ext.Decorators import use_database
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelProperty import *
from NonameOrm.DB.DB import DB
from NonameOrm.DB.Connector import AioMysqlConnector
import asyncio
from test.Test import *
from NonameOrm.Ext import generate_model, generate_table

DATEFORMAT = '%d-%m-%Y %H:%M:%S'
LOGFORMAT = '[ %(levelname)s - %(pathname)s - %(funcName)s] %(message)s]'

logging.basicConfig(level=logging.INFO, format='[ %(levelname)s - %(pathname)s - %(funcName)s] %(message)s')
logger = logging.getLogger(__name__)

# class Person(DataModel):
#     id = IntProperty(pk=True, default=auto_increment)
#     city = StrProperty()
#     id_card_no = StrProperty()
#     name = StrProperty()
#
#
# class User(DataModel):
#     id = IntProperty(pk=True, default=auto_increment)
#     avatar = StrProperty()
#     enable = BoolProperty(default=True)
#     locked = BoolProperty(default=False)
#     person = ForeignKey(Person, Type=ForeignType.MANY_TO_MANY)


code = """
from NonameOrm.Model.ModelProperty import *
from NonameOrm.Model.DataModel import DataModel

class abc(DataModel):
    id = IntProperty(pk=True, default=auto_increment)
    pass
"""


class abc:

    @use_database
    async def test(self):
        db = DB.getInstance()
        dbName = DB.getInstance().connector.config.get('db')
        res = await DB.getInstance().executeSql(
            f"SELECT TABLE_NAME FROM information_schema.`TABLES` WHERE TABLE_SCHEMA = '{dbName}';")
        for (tableName,) in res:
            desc = await db.executeSql(f'desc {tableName}', dictCur=True)
            for i in desc:
                print(i)
        print(astor.to_source(generatorModel()))


class ColAnnounce(TypedDict):
    Field: str
    Type: str
    Null: str
    Key: str
    Default: str


def generatorModel() -> ast3.Module:
    module: ast3.Module = ast.Module(body=[])
    module.body.append(ast.ImportFrom(module='NonameOrm.Model.ModelProperty', names=[ast.alias('*', None)], level=0))
    module.body.append(ast.ImportFrom(module='NonameOrm.Model.DataModel', names=[ast.alias('DataModel', None)], level=0))
    return module


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

    loop.run_until_complete(generate_table())
    # print(Person.user)
