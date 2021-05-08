from aiomysql import Connection


class BaseConnector:
    def process(self, *args, **kwargs):
        pass

    async def asyncProcess(self, *args, **kwargs):
        pass


class AioMysqlConnector(BaseConnector):
    def __init__(self, *args, **kwargs): ...

    @property
    def config(self) -> dict: ...

    async def getCon(self) -> Connection: ...

    async def releaseCon(self, con: Connection) -> None: ...

    async def execute(self, sql: str, con: Connection = None): ...

    async def asyncProcess(self, *args, **kwargs):...

