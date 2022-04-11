import logging
import time
from time import sleep

import aiosqlite
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
from test.Models import *

loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)

from NonameOrm.Ext.PageAble import PageAble

fake = Faker(loacale='zh_CN')

logging.basicConfig(level=logging.DEBUG, format='[ %(levelname)s - %(pathname)s - %(funcName)s] %(message)s')
logger = logging.getLogger(__name__)

if __name__ == '__main__':
    print(SqlGenerator().select(*Task.col).From(Task).where(Task.id.within((1,2,3,4))).Build())
