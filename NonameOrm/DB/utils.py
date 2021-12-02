from NonameOrm.DB.DB import DB


class SqliteContextManager:
    """
        只为了包装 sqlite 来给上下文管理使用
    """

    def __init__(self, con):
        self.con = con

    def acquire(self):
        if DB.getInstance().connector.isAsync:
            return self._async_acquire()
        return self._acquire()

    async def _async_acquire(self):
        return self.con

    def _acquire(self):
        return self.con

    def __enter__(self):
        return self._acquire()

    def __exit__(self, exc_type, exc_val, exc_tb):
        pass

    async def __aenter__(self):
        return await self._async_acquire()

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        pass
