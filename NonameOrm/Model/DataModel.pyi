from typing import Type, Optional, List, Tuple, Dict

from NonameOrm.DB.DB import DB
from NonameOrm.Model.ModelExcutor import AsyncModelExecutor
from NonameOrm.Model.ModelProperty import BaseProperty, ForeignKey


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
    col: Tuple[BaseProperty]
    mapping: Dict[str,BaseProperty]
    tableName: str
    _db: Type[DB] = DB
    pkName: Optional[str] = None
    pkCol: Optional[BaseProperty] = None
    fk: List[ForeignKey]

    def __new__(cls, *args, **kwargs) -> ModelInstance:...

    @classmethod
    def getAsyncExecutor(cls, work=None) -> AsyncModelExecutor:...


