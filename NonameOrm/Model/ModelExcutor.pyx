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

    cdef InstanceList processSelect(self, list res):
        cdef:
            BaseProperty col
            InstanceList instances = InstanceList()
            int i
        for i in range(len(res)):
            instances.append(self.model(res[i],check=False))
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


    async def findListForeignKey(self, InstanceList instances, bint deep=False, dict path = {}, int clevel=1, int level=3,str before=None):
        cdef int i
        for i in range(len(instances)):
            await self.findForeignKey(instances[i], deep=True, path=path, clevel=clevel, level=level)

    async def findForeignKey(self, ModelInstance instance, bint deep=False, dict path = {}, int clevel=1, int level=3,str before=None):

        cdef:
            InstanceList res
            ModelInstance ins
            int i

        if deep and clevel == 1:
            # 若当前为深查找入口时将当前实例放入路径内
            path[self.model.tableName] = {instance[self.model.pkName]: instance}
        elif deep and not clevel == 1:
            # 若当前非深查找入口，则增加深度
            clevel += 1
            if clevel > level:
                # 检查当前深度
                return

        for fk in self.model.fk:
            # 循环查找
            if fk.Type == ForeignType.MANY_TO_MANY:
                if before == fk.directTarget.tableName:
                    continue
                # 若外键类型为多对多
                if fk.directTarget.tableName in path and instance[fk.bindCol.name] in path[fk.directTarget.tableName]:
                    # 查看当前外键关联下是否有已查询过的内容，有则直接返回
                    instance[fk.name] = path[fk.directTarget.tableName][instance[fk.bindCol.name]]
                else:
                    # 通过join中间表查询目标外键表
                    exc: AsyncModelExecutor = fk.directTarget.getAsyncExecutor()
                    exc.sql.join(getattr(fk.directTarget, fk.owner.tableName))
                    instance[fk.name] = await exc.findAllBy(
                        getattr(fk.middleModel, fk.owner.tableName + '_id') == instance[fk.bindCol.name])

                    # 将当前结果添加进路径
                    if fk.directTarget.tableName in path:
                        path[fk.directTarget.tableName][instance[fk.bindCol.name]] = instance[fk.name]
                    else:
                        path[fk.directTarget.tableName] = {instance[fk.bindCol.name]: instance}

                if deep and len(instance[fk.name]):
                    # 深查找
                    exc: AsyncModelExecutor = instance[fk.name][0].object.getAsyncExecutor()
                    for i in range(len(instance[fk.name])):
                        ins = instance[fk.name][i]
                        await exc.findForeignKey(ins, deep=True, path=path, clevel=clevel, level=level,before=self.model.tableName)
            else:
                if before == fk.target.tableName:
                    continue
                if fk.target.tableName in path and instance[fk.bindCol.name] in path[fk.target.tableName]:
                    res = path[fk.target.tableName][instance[fk.bindCol.name]]
                else:
                    res = await fk.target.getAsyncExecutor().findAllBy(
                        fk.targetBindCol == instance[fk.bindCol.name])
                if res and fk.Type == ForeignType.ONE_TO_ONE and res.len():
                    # 若为一对一关系则直接取结果集中的第一项作为数据放入实例
                    instance[fk.name] = res[0]
                    if deep:
                        await instance[fk.name].object.getAsyncExecutor().findForeignKey(instance[fk.name], deep=True, path=path, clevel=clevel, level=level,before=self.model.tableName)

                elif res and fk.Type == ForeignType.ONE_TO_MANY:
                    # 若为一对多关系，则直将结果集作为数据放入实例
                    exc: AsyncModelExecutor = res[0].object.getAsyncExecutor()
                    instance[fk.name] = res
                    if deep:
                        for i in range(len(res)):
                            await exc.findForeignKey(res[i], deep=True, path=path, clevel=clevel, level=level)


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
