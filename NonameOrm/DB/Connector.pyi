from asyncio import Task
from typing import Optional, Any, Awaitable, Dict

from aiomysql import Connection as AsyncMysqlConnection

from aiosqlite.core import Connection as AsyncSqliteConnection

from NonameOrm.Model.ModelExcutor import AsyncModelExecutor


class BaseConnector:
    """
        数据库连接器基类，无任何功能，需要继承实现
    """
    isAsync: bool

    def getCon(self): ...

    def execute(self, sql: str, con: Any = None, args: tuple = ()): ...

    def process(self, *args, **kwargs):
        pass

    def releaseCon(self, con: Any): ...

    def asyncProcess(self, *args, **kwargs):
        pass


class AioSqliteConnector(BaseConnector):
    """
        异步AioSqlite连接器

        基于 aiosqlite 封装
    """

    conMap:Dict[Task:AsyncSqliteConnection]


    async def getCon(self) -> AsyncSqliteConnection: ...

    async def execute(self, sql: str, con: Optional[AsyncSqliteConnection] = None, args: tuple = ()): ...

    def releaseCon(self, con: AsyncMysqlConnection) -> Awaitable: ...

    async def asyncProcess(self,
                           executor:AsyncModelExecutor,
                           ): ...



class AioMysqlConnector(BaseConnector):
    """
        异步mysql 连接器

        基于 aiomysql 封装
    """
    def __init__(self, *args, **kwargs): ...

    @property
    def config(self) -> dict: ...

    async def getCon(self) -> AsyncMysqlConnection: ...

    def releaseCon(self, con: AsyncMysqlConnection) -> Awaitable: ...

    async def execute(self, sql: str, con: AsyncMysqlConnection = None, args: tuple = ()): ...

    async def asyncProcess(self, *args, **kwargs): ...
