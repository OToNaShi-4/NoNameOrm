from typing import Optional, Type, List
from .ModelProperty cimport *
from DB.DB import *

cdef str get_lower_case_name(str text):
    text = text.replace('Model', '')
    cdef list lst = []
    cdef int index
    cdef str char
    for index, char in enumerate(text):
        if char.isupper() and index != 0:
            lst.append("_")
        lst.append(char)

    return "".join(lst).lower()

cdef class _DataModel:
    @classmethod
    def instanceBuilder(cls: DataModel, *args, **kwargs) -> ModelInstance:
        return cls.modelInstance(*args, **kwargs)


class _DataModelMeta(type):

    def __new__(cls, str name, bases: tuple, attrs: dict, **kwargs):
        attrs['col'], attrs['mapping'] = _DataModelMeta.getPropertyObj(cls, attrs)
        if not attrs.get('tableName'):
            attrs['tableName'] = get_lower_case_name(name)
        Class = type.__new__(cls, name, bases, attrs)
        setattr(Class, 'modelInstance', _DataModelMeta.buildModelInstance(Class, attrs['col'], name))
        return Class

    @staticmethod
    def buildModelInstance(cls, list cols: List[BaseProperty], str name) -> Type[ModelInstance]:
        cdef dict temp = dict()

        return type(name + 'Instance', (ModelInstance,), {'object': cls, '_temp': {}})

    @staticmethod
    def getPropertyObj(type cls, attrs: dict):
        cdef list temp = []
        cdef dict mapping = {}
        cdef str key
        for key, item in attrs.items():
            if isinstance(item, BaseProperty):
                temp.append(item)
                mapping[key] = item
        return temp, mapping


cdef class ModelInstance(dict):
    object: Optional[DataModel]
    cdef dict _temp

    def __init__(self, *args, **kwargs):
        super().__init__()

        cdef:
            str k
            BaseProperty v
            cdef dict data = args[0] if len(args) == 1 and isinstance(args[0], dict) else kwargs
        for k, v in object.__getattribute__(self, 'object').mapping.items():
            if k in data:
                self[v.name] = data[k]
            else:
                self[v.name] = v.Default if not isinstance(v.Default, NullDefault) else None

    def __getattribute__(self, str name):
        item = object.__getattribute__(self, 'get')(name)
        if item:
            return item
        else:
            return object.__getattribute__(self, name)

    def __setattr__(self, key, value):
        if key in object.__getattribute__(self, 'dataModel').mapping:
            self[key] = value
            return
        raise KeyError()

cdef class InstanceList(list):
    pass

cdef class ModelExecutor:
    pass

cdef class AsyncModelExecutor(ModelExecutor):
    def __init__(self, model: DataModel, work=None):
        self.model = model
        self.sql = SqlGenerator()

    def getAnyMatch(self, instance: ModelInstance):
        self.sql.select(*self.model.col) \
            .From(self.model)

        self.sql.where(self.instanceToFilter(instance))
        print(self.sql.Build())

    cdef FilterListCell instanceToFilter(self, ModelInstance instance):
        cdef:
            int i
            BaseProperty cur
            FilterListCell f_list = FilterListCell('true')
        for i in range(len(self.model.col) - 1):
            cur = (<list> self.model.col)[i]
            if not instance.get(cur.name):
                continue
            f_list.append(FilterListCell(cur.name, col=cur), Relationship.AND) \
                .append(FilterListCell(instance.get(cur.name)), Relationship.EQUAL)
        return f_list

    async def find(self, *cols: List[BaseProperty]):
        pass

    async def save(self, instance: ModelInstance):
        pass

    async def update(self, instance: ModelInstance):
        pass


class DataModel(_DataModel, metaclass=_DataModelMeta):
    col: tuple
    mapping: dict
    tableName: str
    _db: Type[DB] = DB
    pkName: Optional[str] = None
    pkCol: Optional[BaseProperty] = None

    def __new__(cls, *args, **kwargs) -> ModelInstance:
        return cls.instanceBuilder(cls, *args, **kwargs)

    @classmethod
    def getAsyncExecutor(cls, work=None) -> AsyncModelExecutor:
        return AsyncModelExecutor(cls, work)
