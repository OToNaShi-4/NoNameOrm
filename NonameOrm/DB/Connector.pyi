from asyncio import Task

from aiomysql import Connection


class BaseConnector:
    isAsync: bool

    def process(self, *args, **kwargs):
        pass

    async def asyncProcess(self, *args, **kwargs):
        pass


class AioMysqlConnector(BaseConnector):
    def __init__(self, *args, **kwargs): ...

    @property
    def config(self) -> dict: ...

    async def getCon(self) -> Connection: ...

    def releaseCon(self, con: Connection) -> Task: ...

    async def execute(self, sql: str, con: Connection = None, args: tuple = ()): ...

    async def asyncProcess(self, *args, **kwargs): ...
