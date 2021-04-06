# cython: c_string_type=unicode, c_string_encoding=utf8
# cython_ext: language_level=3
import json
from typing import Optional

from Error.PropertyError import *

from enum import Enum

import Model.DataModel

cdef class NullDefault:
    pass

cdef NullDefault _null = NullDefault()

cdef class FilterListCell:
    def __init__(self, cell = '', Relationship relationship = Relationship.NONE, BaseProperty col = None):
        if <str> cell == '':
            raise
        self.value = cell
        self.relationship = relationship
        self.next = None
        self.col = col

    cpdef FilterListCell append(self, FilterListCell cell, Relationship relationship):
        if self.next:
            return self.next.append(cell, relationship)
        if self.col and not cell.col:
            cell.value = self.col.toDBValue(cell.value)
        self.next = cell
        self.relationship = relationship
        return self

    def check(self):
        if self.next:
            self.next.check()

    def __and__(self, other):
        return self._add(other, AND)

    def __or__(self, other):
        return self._add(other, OR)

    cpdef _add(self, object other, Relationship relationship):
        if issubclass(other.__class__, BaseProperty):
            self.append(FilterListCell(other.name, col=other), relationship)
        elif issubclass(other.__class__, FilterListCell):
            self.append(other, relationship)
        else:
            self.append(FilterListCell(other), relationship)
        return self

cdef class BaseProperty:
    def __init__(self,
                 str name = None,
                 bint pk = False,
                 default = _null,
                 bint Null = True,
                 *args, **kwargs):

        if name:
            self.name = name
        self._Type = self.Type
        self.isPk = pk
        self.Null = Null
        self._default = default
        self._init(*args, **kwargs)

    def _init(*args, **kwargs):
        pass

    def __set_name__(self, owner, name: str) -> None:
        import Model.DataModel
        if not issubclass(owner, Model.DataModel.DataModel):
            raise PropertyUsageError(owner)
        self.name = name
        self.model = owner
        if self.isPk:
            if owner.pkName and owner.pkCol:
                raise PrimaryKeyOverLimitError()
            owner.pkCol = self
            owner.pkName = self.name

    cpdef public bint sizeChecker(self, object value):
        return True

    cpdef public bint verifier(self, object value):
        if isinstance(value, self._Type):
            return self.sizeChecker(value)
        try:
            res = self._Type(value)
            return self.sizeChecker(value)
        except Exception:
            raise PropertyVerifyError(value, self._Type)

    def insertCell(self, value):
        return {
            'col':self,
            'value': self.toDBValue(value)
        }

    def updateCell(self,value):
        return {
            'name':self.name,
            'value': self.toDBValue(value)
        }

    cdef public toDBValue(self, value):
        return value if value else 'null'

    cdef public toObjValue(self, value):
        return value

    def __eq__(self, other) -> FilterListCell:
        return self.setFilter(other, EQUAL)

    def __ne__(self, other) -> FilterListCell:
        return self.setFilter(other, NOTEQUAL)

    def __lt__(self, other) -> FilterListCell:
        return self.setFilter(other, SMALLER)

    def __gt__(self, other) -> FilterListCell:
        return self.setFilter(other, BIGGER)

    def __le__(self, other) -> FilterListCell:
        return self.setFilter(other, SMALLER_EQUAL)

    def __ge__(self, other) -> FilterListCell:
        return self.setFilter(other, BIGGER_EQUAL)

    cdef FilterListCell setFilter(self, object other, Relationship relationship):
        f = FilterListCell(self.name, col=self)
        if issubclass(BaseProperty, other.__class__):
            f.append(FilterListCell(other.name, col=other), relationship)
        else:
            f.append(FilterListCell(self.toDBValue(other)), relationship)
        return f

    @property
    def hasDefault(self):
        return not self._default == _null

    @property
    def Default(self):
        return self._default

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

    def _init(self, targetType: intSupportType = intSupportType.int, *args, **kwargs):
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


class jsonProperty(Enum):
    varchar = 'varchar'
    text = 'text'
    longtext = 'longtext'
    tinytext = 'tinytext'


class JsonProperty(BaseProperty):
    Type = dict
    SupportType: jsonProperty = jsonProperty

    def _init(self, targetType: jsonProperty = jsonProperty.text, *args, **kwargs):
        self.targetType = targetType

    def toObjValue(self, object value):
        if isinstance(value,dict) or isinstance(value,list):
            return value
        return json.loads(value)

    def toDBValue(self, value) -> str:
        if isinstance(value,str) or isinstance(value,bytes):
            return value
        return json.dumps(value)

class ForeignType(Enum):
    ONE_TO_ONE = 1
    ONE_TO_MANY = 2
    MANY_TO_MANY = 3


class ForeignKey(dict):
    __slots__ = ()
    import Model.DataModel
    target: Model.DataModel.DataModel
    bindCol: BaseProperty
    Type: ForeignType
    owner: Model.DataModel.DataModel
    targetBindCol: Optional[BaseProperty]
    name: str

    def __init__(self,
                 target,
                 Type: ForeignType = ForeignType.ONE_TO_ONE,
                 bindCol: Optional[BaseProperty] = None,
                 targetBindCol: Optional[BaseProperty] = None
                 ):
        super().__init__()
        self['target'] = target
        self['bindCol'] = bindCol
        self['Type'] = Type
        self['targetBindCol'] = targetBindCol

    def __set_name__(self, owner, name):
        self.name = name
        if not issubclass(owner, Model.DataModel.DataModel):
            raise ForeignKeyDependError()
        self['owner'] = owner
        if not self.bindCol:
            self['bindCol'] = owner.pkCol
        if not self.targetBindCol:
            self['targetBindCol'] = self.target.pkCol

    def __getattribute__(self, str item):
        return object.__getattribute__(self, 'get')(item, None)
