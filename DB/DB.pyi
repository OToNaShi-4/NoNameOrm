from ctypes import Union
from typing import Callable, Coroutine

from DB.Connector import BaseConnector


class DB:
    def __init__(self, connector: BaseConnector, *args, **kwargs): ...

    @classmethod
    def create(cls, *args, **kwargs) -> DB: ...

    @property
    def execute(self) -> Coroutine or Callable: ...

    @property
    def instance(self) -> DB: ...

    @property
    def connector(self) -> BaseConnector:...

    @property
    def ConnectorType(self): ...

    @classmethod
    def getInstance(cls) -> DB: ...

    @property
    def executeSql(self)-> Callable or Coroutine:...

    @classmethod
    def getInstanceWithCheck(cls) -> DB: ...
