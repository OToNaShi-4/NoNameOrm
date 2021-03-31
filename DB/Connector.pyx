import asyncio

from DB.Generator cimport SqlGenerator, sqlType
from Error.DBError import WriteOperateNotInAffairs
from Model.ModelExcutor cimport AsyncModelExecutor

_loop: asyncio.unix_events.SelectorEventLoop = asyncio.get_event_loop()

cdef class BaseConnector:
    _pool: object

    def process(self, *args, **kwargs):
        pass

    async def asyncProcess(self, *args, **kwargs):
        pass

cdef class AioMysqlConnector(BaseConnector):
    def __init__(self, *args, **kwargs) -> None:
        self.isAsync = True
        self.Type = AioMysql
        self.selectCon = None
        self._pool = _loop.run_until_complete(self._init_mysql(*args, **kwargs))

    async def _init_mysql(self, *args, **kwargs) -> None:
        import aiomysql
        pool = await aiomysql.create_pool(*args, **kwargs)
        self.selectCon = await pool.acquire()
        return pool

    async def asyncProcess(self, *args, **kwargs):
        # 获取异步执行对象
        cdef AsyncModelExecutor executor = kwargs.get('executor')
        assert isinstance(executor, AsyncModelExecutor), '需要传入executor参数,且必须为AsyncModelExecutor实例'

        # 获取SQL生成器
        cdef SqlGenerator sql = executor.sql

        # 判断非查询行为是否处于事务模式下
        # if sql.currentType != sqlType.SELECT and 'con' not in kwargs:
        #     raise WriteOperateNotInAffairs()

        # 获取数据库链接
        cdef object res
        con = kwargs.get('con') if 'con' in kwargs else self.selectCon
        async with con.cursor() as cur:
            print(sql.Build())
            await cur.execute(*sql.Build())
            if sql.currentType != sqlType.INSERT:
                res = await cur.fetchall()
            else:
                res = cur.lastrowid

        # 处理查询结果
        return executor.process(res)
