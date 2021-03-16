from Model.DataModel import DataModel
from Model.ModelProperty import *
from DB.Generator import SqlGenerator


class TestModel(DataModel):
    id = IntProperty(pk=True)
    name = StrProperty(default='这是名字')
    phone = StrProperty()


if __name__ == '__main__':
    g: SqlGenerator = SqlGenerator()
    print(g.select(TestModel.name).From(TestModel).where((TestModel.name < '3') & "3" & (TestModel.phone == "123")).Build())
    print(TestModel.pkCol)




