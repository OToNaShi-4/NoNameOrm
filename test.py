from Model.DataModel import DataModel
from Model.ModelProperty import *


class TestModel(DataModel):
    name = StrProperty(default='这是名字')


if __name__ == '__main__':
    a = TestModel(**{'name': '傻逼'})
    print(a.tableName)
