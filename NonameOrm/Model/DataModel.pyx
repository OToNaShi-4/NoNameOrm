from typing import Optional, Type, List

from NonameOrm.DB.DB cimport DB
from NonameOrm.Model.ModelExcutor cimport AsyncModelExecutor
from NonameOrm.Model.ModelExcutor import ModelExecutor
from NonameOrm.Model.ModelProperty import ForeignKey, ForeignType
from pydantic import create_model

from NonameOrm.Ext.Decorators import pydantic_support
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
    """
        数据模型元类
        在生成数据模型子类时，将会在这对模型进行预处理操作
    """
    ModelList: List['DataModel'] = []  # 模型列表，存放所定义的所有模型

    def __new__(cls, str name, bases: tuple, attrs: dict, **kwargs):
        # 根据模型类定义，得到表的定义内容，并进行归总
        attrs['col'], attrs['mapping'], attrs['fk'] = _DataModelMeta.getPropertyObj(cls, attrs)

        # 判断当前模型是否定义了表名，若没有则根据模型类名生成表名
        # 生成规则如下，去除Model结尾，并将名称转为蛇型命名
        # 例子：UserWalletModel -> user_wallet
        if not attrs.get('tableName'):
            attrs['tableName'] = get_lower_case_name(name)

        # 根据所得的定义，生成模型类
        Class = type.__new__(cls, name, bases, attrs)

        # 将生成的模型类添加进模型列表
        _DataModelMeta.ModelList.append(Class)

        # 往模型里注入相关的内容
        # 注入模型实例类到模型类的  modelInstance  成员中
        setattr(Class, 'modelInstance', _DataModelMeta.buildModelInstance(Class, attrs['col'], name))
        # 注入Pydantic模型到模型类的  MODEL  成员中
        setattr(Class, 'MODEL', _DataModelMeta.buildPydanticModel(Class, attrs['col'], name, attrs['fk']))
        return Class

    @staticmethod
    def buildModelInstance(cls, list cols: List[BaseProperty], str name) -> Type[ModelInstance]:
        """
            在这里会生成模型的 模型实例类
        """
        cdef dict temp = dict()

        return type(name + 'Instance', (ModelInstance,), {'object': cls, '_temp': {}})

    @staticmethod
    def buildPydanticModel(cls, list cols: List[BaseProperty], str name, list fk: List[ForeignKey]):
        """
            以数据模型为基础
            生成Pydantic模型
        """
        cdef:
            BaseProperty prop
            dict types = {}
            int index
            list temp

        # 处理字段类型声明
        for index in range(len(cols)):
            prop = cols[index]
            temp = [Optional[prop._Type] if prop.Null else prop._Type]
            if prop.hasDefault:
                temp.append(prop.Default)
            else:
                temp.append(Ellipsis)
            types[prop.name] = tuple(temp)

        # 处理外键类型声明
        for foregin in fk:
            if foregin['Type'] == ForeignType.ONE_TO_ONE:
                types[foregin['name']] = (Optional[foregin['target'].MODEL], None)
            else:
                types[foregin['name']] = (List[foregin['target'].MODEL], [])

        Class = create_model(name, **types)

        # 往类里注入魔法方法，使其支持字典的部分特性
        pydantic_support(Class)
        return Class

    @staticmethod
    def getPropertyObj(type cls, attrs: dict):
        """
            根据表定义，将相关的property 和 外键
            进行归类并返回
            同时返回他们 名字 与 其本身的映射字典
        """
        cdef list property_list = []  # 字段列表
        cdef list fk = []  # 外键列表
        cdef dict mapping = {}  # 映射字典
        cdef str key

        for key, item in attrs.items():
            if isinstance(item, BaseProperty):
                property_list.append(item)
                mapping[key] = item
            elif isinstance(item, ForeignKey):
                fk.append(item)
                mapping[key] = item
        return property_list, mapping, fk


cdef class ModelInstance(dict):
    """
    模型实例基类
    其子类会在DataModel被创建之时自动创建并继承此类
    本类及其子类需要通过实例化模型类时实例化

    本类继承自字典《dict》实例拥有字典的所有能力
    遇到
    """

    def __init__(self, *args, **kwargs):
        cdef:
            str k
            cdef dict data = kwargs



        if len(args):
            if isinstance(args[0], zip):
                super().__init__(args[0])
            elif isinstance(args[0], dict):
                data = <dict> args[0]
                if kwargs.get('check', True):
                    super().__init__()
            else:
                super().__init__()

        from NonameOrm.Model.ModelProperty import ForeignType
        for k, v in self.object.mapping.items():
            if k in data:
                if isinstance(v, ForeignKey) and data[k] is not None:
                    if v.Type == ForeignType.ONE_TO_ONE:
                        self[k] = v.target(data[k], check=kwargs.get('check', True))
                    elif v.Type == ForeignType.ONE_TO_MANY:
                        self[k] = [v.target(i, check=kwargs.get('check', True)) for i in data[k]]
                    elif v.Type == ForeignType.MANY_TO_MANY:
                        self[k] = [v.directTarget(i, check=kwargs.get('check', True)) for i in data[k]]
                elif not kwargs.get('check', True):
                    self[k] = data[k]
                elif isinstance(v, BaseProperty):
                    self[k] = v.toObjValue(data[k])
            elif not kwargs.get('check', True):
                continue
            elif k in self:
                self[k] = v.toObjValue(self[k])
            elif isinstance(v, ForeignKey):
                continue
            else:
                self[v.name] = v.toObjValue(v.Default)

    def __getattribute__(self, str name):
        try:
            return self[name]
        except Exception:
            return object.__getattribute__(self, name)

    def __setattr__(self, key, value):
        if key in self.object.mapping:
            self[key] = value
            return
        raise KeyError()

cdef class InstanceList(list):
    """
    实例列表，内部只有一种对象，就是模型实例的实例
    """

    cdef int len(self):
        return len(self)


class DataModel(_DataModel, metaclass=_DataModelMeta):
    """
    本类为无实例类，无法实例化
    在调用本类的实例化方法时，将会创建本类相对应的模型实例类的实例即

    isinstance(DataModel(), DataModel) -> False
    isinstance(DataModel(), ModelInstance) -> True

    模型实例类 与 模型类 与 模型实例之间的关系需要注意
    """

    _db: Type[DB] = DB
    pkName: Optional[str] = None
    pkCol: Optional[BaseProperty] = None

    def __new__(cls, *args, **kwargs) -> ModelInstance:
        return cls.instanceBuilder(*args, **kwargs)

    @classmethod
    def getAsyncExecutor(cls, work=None) -> AsyncModelExecutor:
        return AsyncModelExecutor(cls, work)

    @classmethod
    def getExecutor(cls, work=None):
        if DB.getInstance().connector.isAsync:
            return cls.getAsyncExecutor(work)
        return ModelExecutor(cls, work)


class MiddleDataModel(DataModel):

    @classmethod
    def instanceBuilder(cls, *args, **kwargs) -> ModelInstance:
        pass

    @classmethod
    def getOtherModelBy(cls, model: DataModel) -> DataModel:
        return cls.getOtherFkBy(model).target

    @classmethod
    def getOtherFkBy(cls, model) -> ForeignKey:
        return cls.fk[0] if cls.fk[0].target is not model else cls.fk[1]
