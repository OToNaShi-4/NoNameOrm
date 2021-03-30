from typing import Optional, Type, List

from Model.ModelExcutor import AsyncModelExecutor
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
    def __init__(self, *args, **kwargs):
        cdef:
            str k
            BaseProperty v
            cdef dict data = kwargs


        if len(args):
            if isinstance(args[0], zip):
                super().__init__(args[0])
            elif isinstance(args[0], dict):
                data = args[0]
                super().__init__()
            else:
                super().__init__()
        else:
            super().__init__()

        for k, v in object.__getattribute__(self, 'object').mapping.items():
            if k in data:
                self[v.name] = data[k]
            elif k in self:
                continue
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


class DataModel(_DataModel, metaclass=_DataModelMeta):
    _db: Type[DB] = DB
    pkName: Optional[str] = None
    pkCol: Optional[BaseProperty] = None

    def __new__(cls, *args, **kwargs) -> ModelInstance:
        return cls.instanceBuilder(*args, **kwargs)

    @classmethod
    def getAsyncExecutor(cls, work=None) -> AsyncModelExecutor:
        return AsyncModelExecutor(cls, work)
