from Error.PropertyError import *
from .DataModel import *
from enum import Enum

cdef class NullDefault:
    pass

cdef NullDefault _null = NullDefault()

cdef class BaseProperty:
    Type: type
    cdef public str name
    cdef type _Type
    cdef public bint isPk
    cdef public bint Null
    cdef object default
    cdef public str targetType

    def __cinit__(self,
                  str name = None,
                  bint pk = False,
                  object default = _null,
                  bint Null = True,
                  *args, **kwargs):

        if name:
            self.name = name

        self._Type = self.Type
        self.isPk = pk
        self.Null = Null
        self.default = default
        self._init(*args, **kwargs)

    def _init(*args, **kwargs):
        pass

    def __set_name__(self, owner, name: str) -> None:
        if not issubclass(owner, DataModel):
            raise PropertyUsageError(owner)
        self.name = name

    cpdef public bint sizeChecker(self,object value):
        return True

    cpdef public bint verifier(self,object value):
        if isinstance(value, self._Type):
            return self.sizeChecker(value)
        try:
            res = self._Type(value)
            return self.sizeChecker(value)
        except Exception:
            raise PropertyVerifyError(value, self._Type)

    cpdef public toDBValue(self, value):
        return value if value else 'null'

    cpdef public toObjValue(self, value):
        return value

    @property
    def hasDefault(self):
        return not self.default == _null

    @property
    def dbName(self) -> str:
        return self.name

    @property
    def objName(self) -> str:
        return self.name


class intSupportType(Enum):
    int = 'int'
    bigint = 'int'


class IntProperty(BaseProperty):
    Type: type = int
    supportType: intSupportType = intSupportType

    def _init(self, targetType: intSupportType = intSupportType.varchar, *args, **kwargs):
        self.targetType = targetType


class strSupportType(Enum):
    varchar = 'varchar'
    text = 'text'
    longText = 'longtext'
    tinyText = 'tinytext'


class StrProperty(BaseProperty):
    Type: type = str
    supportType: strSupportType = strSupportType

    def _init(self, targetType: strSupportType = strSupportType.varchar, *args, **kwargs):
        self.targetType = targetType


class floatSupportType(Enum):
    float = 'float'
    decimal = 'decimal'


class FloatProperty(BaseProperty):
    Type: type = float
    SupportType: floatSupportType = floatSupportType
    size: tuple

    def _init(self, targetType: floatSupportType = floatSupportType.float, tuple size = None, *args, **kwargs):
        self.targetType = targetType
        self.size = size



class boolSupportType(Enum):
    tinyInt = 'tinyint'
    bit = 'bit'
    varchar = 'varchar'


class BoolProperty(BaseProperty):
    Type: type = bool
    SupportType: boolSupportType = boolSupportType

    def _init(self, targetType: boolSupportType = boolSupportType.tinyInt, *args, **kwargs):
        self.targetType = targetType

    def toObjValue(self, object value) -> bool:
        if self.targetType == boolSupportType.tinyInt:
            return bool(value)
        elif self.targetType == boolSupportType.varchar:
            if value == 'True' or value == 'true' or value == '1':
                return True
            else:
                return False
        elif self.targetType == boolSupportType.bit:
            return value == b'\x01'
