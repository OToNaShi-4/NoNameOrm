from enum import Enum
from typing import Any, TypedDict, Optional

from NonameOrm.Model import DataModel
from NonameOrm.Model import FilterListCell


class InsertCell(TypedDict):
    name: str
    value: Any


class NullDefault: ...


_null: NullDefault


class BaseProperty:
    name: str
    _Type: type
    isPk: bool
    Null: bool
    _default: Any
    targetType: Any
    model: DataModel

    def __init__(self, name: str = None, pk: bool = False, default: Any = _null, Null: bool = True, *args, **kwargs): ...

    def _init(*args, **kwargs): ...

    def __set_name__(self, owner, name: str) -> None: ...

    def sizeChecker(self, value: Any) -> bool: ...

    def verifier(self, value: Any) -> bool: ...

    def insertCell(self, value) -> InsertCell: ...

    def updateCell(self, value) -> InsertCell: ...

    def toDBValue(self, value) -> Any: ...

    def toObjValue(self, value): ...

    def __eq__(self, other) -> FilterListCell: ...

    def __ne__(self, other) -> FilterListCell: ...

    def __lt__(self, other) -> FilterListCell: ...

    def __gt__(self, other) -> FilterListCell: ...

    def __le__(self, other) -> FilterListCell: ...

    def __ge__(self, other) -> FilterListCell: ...

    # def setFilter(self, other, relationship) -> FilterListCell: ...

    @property
    def hasDefault(self) -> bool: ...

    @property
    def Default(self) -> Any: ...

    @property
    def dbName(self) -> str: ...

    @property
    def objName(self) -> str: ...


class IntProperty(BaseProperty): ...


class StrProperty(BaseProperty): ...


class FloatProperty(BaseProperty): ...


class BoolProperty(BaseProperty): ...


class JsonProperty(BaseProperty): ...


class ForeignType(Enum):
    ONE_TO_ONE = 1
    ONE_TO_MANY = 2
    MANY_TO_MANY = 3


class ForeignKey(dict):
    from NonameOrm import Model
    target: Model.DataModel.DataModel
    bindCol: BaseProperty
    Type: ForeignType
    owner: Model.DataModel.DataModel
    targetBindCol: Optional[BaseProperty]
    name:str

    def __init__(self, target, Type: ForeignType = ForeignType.ONE_TO_ONE, bindCol: Optional[BaseProperty] = None, targetBindCol: Optional[BaseProperty] = None): ...

    def __set_name__(self, owner, name): ...

    def __getattribute__(self, item: str): ...

    @property
    def directTarget(self) -> Model.DataModel.DataModel:...

