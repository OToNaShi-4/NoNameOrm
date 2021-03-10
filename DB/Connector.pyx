import asyncio

_loop: asyncio.unix_events.SelectorEventLoop = asyncio.get_event_loop()

cdef class BaseConnector:
    _pool: object

    cdef public getCursor(self):
        pass

    cdef public getConnect(self):
        pass

cdef class MysqlConnector(BaseConnector):
    def __init__(self, *args, **kwargs) -> None:
        _loop.run_until_complete(MysqlConnector._init_mysql(*args, **kwargs))
        pass

    @staticmethod
    async def _init_mysql(*args, **kwargs) -> None:
        import aiomysql
        return await aiomysql.create_pool(*args, **kwargs)
