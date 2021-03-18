import json

from Model.DataModel import DataModel, AsyncModelExecutor
from Model.ModelProperty import *
from DB.Generator import SqlGenerator


class ForeignModel(DataModel):
    id = IntProperty(pk=True)
    fname = StrProperty()


class TestModel(DataModel):
    id = IntProperty(pk=True)
    name = StrProperty(default='这是名字')
    phone = StrProperty()
    foreign = ForeignKey(ForeignModel)


if __name__ == '__main__':
    # g: SqlGenerator = SqlGenerator()
    # sql, params = g.select(TestModel.name).From(TestModel) \
    #     .join(TestModel.foreign) \
    #     .where((TestModel.name != '3') & "3" & (TestModel.phone == "123")).Build()
    # print(sql)
    # print(json.dumps(TestModel()))
    # print(TestModel.__dict__)
    a = TestModel(id=1)
    exc: AsyncModelExecutor = TestModel.getAsyncExecutor()
    exc.getAnyMatch(a)
