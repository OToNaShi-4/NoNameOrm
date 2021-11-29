from NonameOrm.DB.Connector import AioMysqlConnector


class SqliteContextManager:

    def __init__(self, con):
        self.con = con

    async def acquire(self):
        return self.con

    async def __aenter__(self):
        return await self.acquire()

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        pass
