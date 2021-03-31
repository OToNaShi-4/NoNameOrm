import json

from Model.DataModel import DataModel, AsyncModelExecutor
from Model.ModelProperty import *
from DB.Generator import SqlGenerator
from DB.DB import DB
from DB.Connector import AioMysqlConnector
import asyncio


class Gift(DataModel):
    id = IntProperty(pk=True)
    name = StrProperty()
    icon = StrProperty()
    price = FloatProperty()


loop = asyncio.get_event_loop()

if __name__ == '__main__':
    # g: SqlGenerator = SqlGenerator()
    # sql, params = g.select(TestModel.name).From(TestModel) \
    #     .join(TestModel.foreign) \
    #     .where((TestModel.name != '3') & "3" & (TestModel.phone == "123")).Build()
    # print(sql)
    # print(json.dumps(TestModel()))
    # print(TestModel.__dict__)
    DB.create(connector=AioMysqlConnector(**{
        'host'    : '127.0.0.1',
        'port'    : 3306,
        'db'      : 'cy_live_dev',
        'user'    : 'root',
        # 'password': '12345678'
        'password': '88888888'
    }))
    mapper = Gift(id=14, name='123123', price=2.23)

    res = loop.run_until_complete(Gift.getAsyncExecutor().delete(mapper))
    print(res)
