# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8
from typing import List

from NonameOrm.DB.Generator cimport SqlGenerator, sqlType
from NonameOrm.Error.DBError import DeleteWithOutPrimaryKeyError, UpdateWithOutPrimaryKeyError

from NonameOrm.Model.DataModel cimport ModelInstance, InstanceList
from NonameOrm.Model.ModelProperty import ForeignType

from .ModelProperty cimport *
from NonameOrm.DB.DB cimport DB

cdef class BaseModelExecutor:
    def __init__(self, model, work=None):
        self.db = DB.getInstance()
        self.model = model
        if work and hasattr(work, 'con'):
            self.work = work.con
        else:
            self.work = work
        self.sql = SqlGenerator().From(model)
        self.__dict__ = {}

    def reset(self):
        self.sql = SqlGenerator().From(self.model)
        return self

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

    def findAnyMatch(self, instance: ModelInstance, int limit = 0, int offset = 0):
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
            for i in range(len(res)):
                instances.append(self.model(zip(select, res[0])))
            return instances

    cdef processInsert(self, int res):
        from NonameOrm.Model.DataModel import MiddleDataModel
        if issubclass(self.model, MiddleDataModel):
            return
        if 'instance' in self.__dict__:
            if not self.__dict__['instance'][self.model.pkName] and res:
                self.__dict__['instance'][self.model.pkName] = res
            return self.__dict__['instance']
        return self.model({self.model.pkName: res})

    cdef process(self, object res):
        if self.sql.currentType == sqlType.INSERT:
            return self.processInsert(<int> res)
        elif self.sql.currentType == sqlType.SELECT:
            return self.processSelect(<tuple> res)
        elif self.sql.currentType == sqlType.UPDATE:
            return self.__dict__['instance']
        else:
            return None

cdef class AsyncModelExecutor(BaseModelExecutor):
    async def findAnyMatch(self, instance: ModelInstance, int limit = 0, int offset = 0) -> List:
        self.sql.select(*self.model.col)
        self.sql.where(self.instanceToFilter(instance))
        if limit > 0:
            self.sql.limit(limit, offset)
        return await self.execute()

    async def findAllBy(self, FilterListCell Filter = None):
        self.sql.select(*self.model.col) \
            .where(Filter)
        return await self.execute()

    def find(self, *cols: List[BaseProperty]):
        self.sql.select(*cols)
        return self

    async def findForeignKey(self, instance, deep=False):
        for fk in self.model.fk:
            if fk.Type == ForeignType.MANY_TO_MANY:
                exc: AsyncModelExecutor = fk.directTarget.getAsyncExecutor()
                exc.sql.join(getattr(fk.directTarget, fk.owner.tableName))
                instance[fk.directTarget.tableName] = await exc.findAllBy(
                    getattr(fk.middleModel, fk.owner.tableName + '_id') == instance[fk.bindCol.name])
            else:
                instance[fk.name] = await fk.target.getAsyncExecutor().findAllBy(
                    fk.targetBindCol == instance[fk.bindCol.name])
        return instance

    async def By(self, FilterListCell Filter = None):
        self.sql.where(Filter)
        return self.execute()

    async def save(self, instance):
        self.__dict__['instance'] = instance

        if instance.get(self.model.pkName):
            return await self.update(instance)
        cdef:
            BaseProperty cur  # 数据列指针
            list insertData = []

        for cur in self.model.col:
            # 判断此列是否在实例内
            if cur.name not in instance or not instance[cur.name]:
                continue
            # 插入数据列表
            insertData.append(cur.insertCell(instance[cur.name]))

        if not insertData:
            return instance

        self.sql.insert(self.model).values(*insertData)
        res = await self.execute()
        # 外键插入
        from NonameOrm.Model.ModelProperty import ForeignType
        for fk in self.model.fk:
            if fk['name'] not in instance or not instance[fk['name']]:
                continue
            elif fk['Type'] == ForeignType.ONE_TO_ONE:
                await self._saveOTO(res, fk, instance)
                continue
            elif fk.Type == ForeignType.ONE_TO_MANY:
                await self._saveOTM(fk, instance)
                continue
            elif fk.Type == ForeignType.MANY_TO_MANY:
                await self._saveMTM(fk, instance)
                continue
            res[fk['name']] = None if fk.Type == ForeignType else []
            for i in instance[fk['name']]:
                res[fk['name']].append(await fk['target'].getAsyncExecutor(self.work).save(instance[fk['name']]))
        return res

    async def _saveOTO(self, res, fk, instance):
        instance[fk['name']][fk['targetBindCol'].name] = res[fk['bindCol'].name]
        res[fk['name']] = await fk.target.getAsyncExecutor(self.work).save(instance[fk['name']])

    async def _saveOTM(self, fk, instance):
        exc = fk.target.getAsyncExecutor(self.work)
        for model in instance[fk.bindCol.name]:
            exc.reset()
            await exc.save(model)

    async def _saveMTM(self, fk, instance):
        targetExc = fk.directTarget.getAsyncExecutor(self.work)
        middleExc = fk.middleModel.getAsyncExecutor(self.work)
        targetFk = fk.middleModel.getOtherFkBy(fk.owner)
        await middleExc.delete({fk.targetBindCol.name: instance[fk.bindCol.name]},
                                       fk.targetBindCol == instance[fk.bindCol.name])
        for model in instance[fk.name]:
            await targetExc.reset().save(model)
            await middleExc.reset().save({
                fk.targetBindCol.name: instance[fk.bindCol.name],
                targetFk.bindCol.name: model[targetFk.targetBindCol.name]
            })

    async def delete(self, instance, filter=None):
        print(instance)
        if not filter and not instance[self.model.pkName]:
            raise DeleteWithOutPrimaryKeyError()
        self.sql.delete(self.model)
        if filter:
            self.sql.where(filter)
        else:
            self.sql.where(self.model.pkCol == instance[self.model.pkName])
        await self.execute()

    async def update(self, instance: ModelInstance):
        if not instance[self.model.pkName]:
            raise UpdateWithOutPrimaryKeyError()

        self.__dict__['instance'] = instance

        cdef:
            BaseProperty cur
            list params = [cur.updateCell(instance[cur.name]) for cur in self.model.col]

        self.sql.update(self.model).set(*params).where(self.model.pkCol == instance[self.model.pkName])
        from NonameOrm.Model.ModelProperty import ForeignType
        for fk in self.model.fk:
            if fk.name in instance:
                if fk.Type == ForeignType.ONE_TO_ONE:
                    await fk.owner.getAsyncExecutor(self.work).update(instance[fk.name])
                    continue
                for i in instance[fk.name]:
                    await fk.owner.getAsyncExecutor(self.work).update(i)

        return await self.execute()

    async def execute(self):
        if self.work:
            return await self.db.execute(executor=self, con=self.work)
        else:
            return await self.db.execute(executor=self)
