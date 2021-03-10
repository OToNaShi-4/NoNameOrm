from typing import Optional, Type, List, Dict
from .ModelProperty import BaseProperty
from DB.DBConnecter import *

cdef str get_lower_case_name(str text):
    cdef list lst = []
    for index, char in enumerate(text):
        if char.isupper() and index != 0:
            lst.append("_")
        lst.append(char)

    return "".join(lst).lower()

cdef class _DataModel(object):
    cdef tuple _col
    cdef dict _mapping
    modelInstance: Type[ModelInstance]
    cdef str pkName

    @classmethod
    def instanceBuilder(cls: DataModel, *args, **kwargs) -> ModelInstance:
        return cls.modelInstance(*args, **kwargs)

    @property
    def col(self) -> tuple:
        return self._col

    @property
    def mapping(self) -> dict:
        return self._mapping

class _DataModelMeta(type):

    def __new__(cls, str name, bases: tuple, attrs: dict, **kwargs):
        attrs['_col'], attrs['_mapping'] = _DataModelMeta.getPropertyObj(cls, attrs)
        attrs['modelInstance'] = _DataModelMeta.buildModelInstance(cls, attrs['_col'], name)
        if not attrs.get('tableName'):
            attrs['tableName'] = get_lower_case_name(cls.__name__)
        return type.__new__(cls, name, bases, attrs)

    @staticmethod
    def buildModelInstance(cls, list cols: List[BaseProperty], str name) -> Type[ModelInstance]:
        cdef dict temp = dict()

        return type(name + 'Instance', (ModelInstance,), {'dataModel': cls, '_temp': {}})

    @staticmethod
    def getPropertyObj(type cls, attrs: dict):
        cdef list temp = []
        cdef dict mapping = {}
        cdef str key
        for key, item in attrs.items():
            if isinstance(item, BaseProperty):
                temp.append(item)
                mapping[item.name] = item
        return temp, mapping


cdef class ModelInstance(dict):
    dataModel: Optional[DataModel]
    cdef dict _temp

    def __cinit__(self, *args, **kwargs):
        cdef str k
        v: BaseProperty
        for k, v in self.dataModel.mapping:
            self[k] = None
            pass

    def __getattribute__(self, str name):
        item = self.get(name)
        if item:
            return item
        else:
            return object.__getattribute__(self.dataModel, name)

    def __setattr__(self, key, value):
        if key in self.dataModel.mapping:
            self[key] = value
        raise KeyError()


class DataModel(_DataModel, metaclass=_DataModelMeta):
    _col: tuple
    _mapping: dict
    _tableName: str
    _db: Type[DB] = DB

    def __new__(cls, *args, **kwargs) -> ModelInstance:
        return cls.instanceBuilder(cls, *args, **kwargs)

