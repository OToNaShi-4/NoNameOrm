import asyncio

from NonameOrm.DB.Generator cimport  sqlType, BaseSqlGenerator
from NonameOrm.Error.DBError import WriteOperateNotInAffairs

from NonameOrm.Model.ModelExcutor cimport AsyncModelExecutor
import logging

_loop: asyncio.unix_events.SelectorEventLoop = asyncio.get_event_loop()
_logger = logging.getLogger(__package__)

cdef class BaseConnector:
    def process(self, *args, **kwargs):
        pass

    async def asyncProcess(self, *args, **kwargs):
        pass

cdef class AioMysqlConnector(BaseConnector):
    def __init__(self, *args, **kwargs) -> None:
        self._config = kwargs
        self.isAsync = True
        self.Type = AioMysql
        self.selectCon = None
        self._pool = _loop.run_until_complete(self._init_mysql(*args, **kwargs))

    async def _init_mysql(self, *args, **kwargs) -> None:
        import aiomysql
        pool = await aiomysql.create_pool(*args, **kwargs)
        self.selectCon = await pool.acquire()
        return pool

    @property
    def config(self):
        return self._config

    @property
    def getCon(self):
        return self._pool.acquire

    async def releaseCon(self, con):
        await self._pool.release(con)

    async def execute(self, str sql, con=None):
        if not con:
            con = self.selectCon
        async with con.cursor() as cur:
            await cur.execute(sql)
            return await cur.fetchall()

    async def asyncProcess(self, *args, **kwargs):
        # 获取异步执行对象
        cdef AsyncModelExecutor executor = kwargs.get('executor')
        assert isinstance(executor, AsyncModelExecutor), '需要传入executor参数,且必须为AsyncModelExecutor实例'

        # 获取SQL生成器
        cdef BaseSqlGenerator sql = executor.sql

        # 判断非查询行为是否处于事务模式下
        if sql.currentType != sqlType.SELECT and 'con' not in kwargs:
            raise WriteOperateNotInAffairs()

        # 获取数据库链接
        cdef:
            object res
            str sqlTemp
            list data
        con = kwargs.get('con') if 'con' in kwargs else self.selectCon
        async with con.cursor() as cur:
            sqlTemp, data = sql.Build()
            _logger.info(sqlTemp)
            logging.info(data)
            await cur.execute(sqlTemp, data)
            if sql.currentType != sqlType.INSERT:
                res = await cur.fetchall()
            else:
                res = cur.lastrowid
        # 处理查询结果
        return executor.process(res)
