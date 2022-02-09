from typing import Callable, Coroutine, TypeVar, Generic

from NonameOrm.DB.Connector import BaseConnector

T = TypeVar('T')

class DB(Generic[T]):
    def __init__(self, connector: T, *args, **kwargs): ...

    @classmethod
    def create(cls, *args, **kwargs) -> DB: ...

    @property
    def execute(self) -> Coroutine or Callable: ...

    def GenerateTable(self) -> DB: ...

    @property
    def instance(self) -> DB: ...

    @property
    def connector(self) -> T:...

    @property
    def ConnectorType(self): ...

    @classmethod
    def getInstance(cls) -> DB: ...

    @property
    def executeSql(self)-> Callable or Coroutine:...

    @classmethod
    def getInstanceWithCheck(cls) -> DB: ...
