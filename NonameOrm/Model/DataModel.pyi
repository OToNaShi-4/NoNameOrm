from typing import Type, Optional, List, Tuple, Dict, Union

from NonameOrm.DB.DB import DB
from NonameOrm.Model.ModelExcutor import AsyncModelExecutor, ModelExecutor
from NonameOrm.Model.ModelProperty import BaseProperty, ForeignKey
from pydantic import BaseModel


class ModelInstance(dict):
    def __init__(self, *args, **kwargs): ...

    def __getattribute__(self, name): ...

    def __setattr__(self, key, value): ...


class _DataModel:
    @classmethod
    def instanceBuilder(cls: DataModel, *args, **kwargs) -> ModelInstance: ...


class _DataModelMeta(type):
    def __new__(cls, name, bases: tuple, attrs: dict, **kwargs): ...


class DataModel(_DataModel, ModelInstance, metaclass=_DataModelMeta):
    col: Tuple[BaseProperty]
    mapping: Dict[str, BaseProperty]
    tableName: str
    _db: Type[DB] = DB
    pkName: Optional[str] = None
    pkCol: Optional[BaseProperty] = None
    fk: List[ForeignKey]
    MODEL: Union[DataModel, BaseModel]

    def __new__(cls, *args, **kwargs) -> ModelInstance: ...

    @classmethod
    def getAsyncExecutor(cls, work=None) -> AsyncModelExecutor: ...

    @classmethod
    def getExecutor(cls, work=None) -> Union[AsyncModelExecutor, ModelExecutor]: ...
