# cython: language_level=3
from .BaseOrmError import BaseOrmError


class PropertyUsageError(BaseOrmError):
    def _process(self,  cls, *args, **kwargs) -> None:
        self.msg = f'Property类只能在Model类中被实例化，在{cls.__name__}中则无法正常工作'


class PropertyVerifyError(BaseOrmError):
    def _process(self, data, Type, *args, **kwargs):
        self.msg = f'数据 {data} 并不是 {Type} 类型或无法被 {Type} 类型转化'


class FloatPropertyOutOfRangeError(BaseOrmError):
    def _process(self, size: tuple, value: float, *args, **kwargs):
        self.msg = f'浮点数据整数位限制为{size[0]}位，小数位为{size[1]}位，传入数据{value}超出限制'


class PrimaryKeyOverLimitError(BaseOrmError):
    msg = '每个MODEL对象只允许拥有一个主键约束'

class ForeignKeyDependError(BaseOrmError):
    msg = "外键实例依赖于DataModel子类，无法在非DataModel中创建"