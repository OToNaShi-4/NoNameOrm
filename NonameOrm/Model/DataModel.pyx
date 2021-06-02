from typing import Optional, Type, List

from NonameOrm.DB.DB cimport DB
from NonameOrm.Model.ModelExcutor cimport AsyncModelExecutor
from NonameOrm.Model.ModelProperty import ForeignKey
from .ModelProperty cimport *

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
    ModelList: List['DataModel'] = []

    def __new__(cls, str name, bases: tuple, attrs: dict, **kwargs):
        attrs['col'], attrs['mapping'], attrs['fk'] = _DataModelMeta.getPropertyObj(cls, attrs)
        if not attrs.get('tableName'):
            attrs['tableName'] = get_lower_case_name(name)
        Class = type.__new__(cls, name, bases, attrs)
        _DataModelMeta.ModelList.append(Class)
        setattr(Class, 'modelInstance', _DataModelMeta.buildModelInstance(Class, attrs['col'], name))
        return Class

    @staticmethod
    def buildModelInstance(cls, list cols: List[BaseProperty], str name) -> Type[ModelInstance]:
        cdef dict temp = dict()

        return type(name + 'Instance', (ModelInstance,), {'object': cls, '_temp': {}})

    @staticmethod
    def getPropertyObj(type cls, attrs: dict):
        cdef list temp = []
        cdef list fk = []
        cdef dict mapping = {}
        cdef str key

        for key, item in attrs.items():
            if isinstance(item, BaseProperty):
                temp.append(item)
                mapping[key] = item
            elif isinstance(item, ForeignKey):
                fk.append(item)
                mapping[key] = item
        return temp, mapping, fk


cdef class ModelInstance(dict):
    def __init__(self, *args, **kwargs):
        cdef:
            str k
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

        from NonameOrm.Model.ModelProperty import ForeignType
        for k, v in object.__getattribute__(self, 'object').mapping.items():
            if k in data:
                if isinstance(v, BaseProperty):
                    self[k] = v.toObjValue(data[k])
                elif isinstance(v,ForeignKey):
                    if v.Type == ForeignType.ONE_TO_ONE:
                        self[k] = v['target'](data[k])
                    elif v.Type == ForeignType.ONE_TO_MANY:
                        self[k] = [v.target(i) for i in data[k]]
                    elif v.Type == ForeignType.MANY_TO_MANY:
                        self[k] = [v.directTarget(i) for i in data[k]]

            elif k in self:
                self[k] = v.toObjValue(self[k])
            else:
                self[v.name] = v.Default

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


class MiddleDataModel(DataModel):

    @classmethod
    def instanceBuilder(cls, *args, **kwargs) -> ModelInstance:
        pass

    @classmethod
    def getOtherModelBy(cls, model:DataModel) -> DataModel:
        return cls.getOtherFkBy(model).target

    @classmethod
    def getOtherFkBy(cls,model) -> ForeignKey:
        return cls.fk[0] if cls.fk[0].target is not model else cls.fk[1]
