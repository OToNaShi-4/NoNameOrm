# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8
from typing import List

from DB.Generator cimport SqlGenerator, sqlType

from Model.DataModel cimport ModelInstance, InstanceList
from .ModelProperty cimport *
from DB.DB cimport DB

cdef class BaseModelExecutor:
    def __init__(self, model, work=None):
        self.db = DB.getInstance()
        self.model = model
        self.work = work
        self.sql = SqlGenerator().From(model)


    cdef FilterListCell instanceToFilter(self, ModelInstance instance):
        cdef:
            int i
            BaseProperty cur
            FilterListCell f_list = FilterListCell('1')
        for i in range(len(self.model.col) - 1):
            cur = (<list> self.model.col)[i]
            if not instance.get(cur.name):
                continue
            f_list.append(FilterListCell(cur.name, col=cur), Relationship.AND) \
                .append(FilterListCell(instance.get(cur.name)), Relationship.EQUAL)
        return f_list

    @property
    def generator(self) -> SqlGenerator:
        return self.sql

    def getAnyMatch(self, instance: ModelInstance):
        pass

    def find(self, *cols: List[BaseProperty]):
        pass

    def save(self, instance: ModelInstance):
        pass

    def update(self, instance: ModelInstance):
        pass

    def execute(self):
        pass

    cdef object processSelect(self, tuple res):
        cdef:
            BaseProperty col
            list select = [col.name for col in self.sql.selectCol]
            InstanceList instances
            int i
        if len(res) == 1:
            return self.model(zip(select, res[0]))
        else:
            instances = InstanceList()
            for i in range(len(res) - 1):
                instances.append(self.model(zip(select, res[0])))
            return instances

    cdef process(self, object res):
        if self.sql.currentType == sqlType.INSERT:
            return self.model({self.model.pkName: res})
        elif self.sql.currentType == sqlType.SELECT:
            return self.processSelect(<tuple> res)
        else:
            return None

cdef class AsyncModelExecutor(BaseModelExecutor):
    async def getAnyMatch(self, instance: ModelInstance) -> List:
        self.sql.select(*self.model.col)
        self.sql.where(self.instanceToFilter(instance))
        return await self.execute()

    async def findAllBy(self, FilterListCell Filter = None):
        self.sql.select(*self.model.col) \
            .where(Filter)
        return await self.execute()

    async def find(self, *cols: List[BaseProperty]):
        pass

    async def save(self, instance: ModelInstance):

        pass

    async def update(self, instance: ModelInstance):
        pass

    async def execute(self):
        if self.work:
            return await self.db.execute(executor=self, con=self.work.con)
        else:
            return await self.db.execute(executor=self)
