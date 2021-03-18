import asyncio

_loop: asyncio.unix_events.SelectorEventLoop = asyncio.get_event_loop()

cdef class BaseConnector:
    _pool: object

    def process(self, *args, **kwargs):
        pass

    async def asyncProcess(self, *args, **kwargs):
        pass

cdef class MysqlConnector(BaseConnector):
    def __init__(self, *args, **kwargs) -> None:
        self._pool = _loop.run_until_complete(MysqlConnector._init_mysql(*args, **kwargs))

    @staticmethod
    async def _init_mysql(*args, **kwargs) -> None:
        import aiomysql
        return await aiomysql.create_pool(*args, **kwargs)
