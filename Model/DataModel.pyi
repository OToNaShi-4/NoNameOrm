from typing import Type, Optional

from DB.DB import DB
from Model.ModelExcutor import AsyncModelExecutor
from Model.ModelProperty import BaseProperty


class ModelInstance(dict):
    def __init__(self, *args, **kwargs):...

    def __getattribute__(self, name):...

    def __setattr__(self, key, value):...

class _DataModel:
    @classmethod
    def instanceBuilder(cls: DataModel, *args, **kwargs) -> ModelInstance:...

class _DataModelMeta(type):
    def __new__(cls, name, bases: tuple, attrs: dict, ** kwargs):...


class DataModel(_DataModel,ModelInstance, metaclass=_DataModelMeta):
    col: tuple
    mapping: dict
    tableName: str
    _db: Type[DB] = DB
    pkName: Optional[str] = None
    pkCol: Optional[BaseProperty] = None

    def __new__(cls, *args, **kwargs) -> ModelInstance:...

    @classmethod
    def getAsyncExecutor(cls, work=None) -> AsyncModelExecutor:...

