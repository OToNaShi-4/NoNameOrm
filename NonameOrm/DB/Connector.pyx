import asyncio
import multiprocessing
import threading
from asyncio import AbstractEventLoop

from NonameOrm.DB.Generator cimport  sqlType, BaseSqlGenerator
from NonameOrm.DB.utils import SqliteContextManager
from NonameOrm.Error.DBError import WriteOperateNotInAffairs
from NonameOrm.Ext import generate_table
import sqlite3

from NonameOrm.Model.ModelExcutor cimport AsyncModelExecutor
import logging

from aiomysql import Cursor, DictCursor

_logger = logging.getLogger(__package__)

lock = multiprocessing.Lock()

def dict_factory(cursor, tuple row):
    d = {}
    cdef int idx

    for idx, col in enumerate(cursor.description):
        d[col[0]] = row[idx]
    return d

cdef class BaseConnector:
    def process(self, *args, **kwargs):
        pass

    async def asyncProcess(self, *args, **kwargs):
        pass

    def GenerateTable(self):
        pass

    @property
    def paramsHolder(self):
        return '%s'

cdef class Sqlite3Connector(BaseConnector):
    def __init__(self, str path, bint showLog = True):
        self.isAsync = False
        self.init_sqlite(path, showLog)
        self.path = path

    cdef init_sqlite(self, str path, bint showLog):
        self.con = sqlite3.connect(path, timeout=99999, check_same_thread=False)

        if showLog:
            self.con.set_trace_callback(_logger.debug)

    def releaseCon(self, con):
        con.commit()
        pass

    def getCon(self):
        if threading.current_thread() == threading.main_thread():
            return self.con
        else:
            return sqlite3.connect(self.path)

    @property
    def paramsHolder(self):
        return '?'

    cpdef str autoFiledAnnounce(self, col):
        return 'INTEGER '

    def GenerateTable(self):
        generate_table()

    cpdef list getTableNameList(self):
        cdef tuple table

        cur = self.con.execute('select tbl_name from sqlite_master where type = "table";')
        return [table[0] for table in cur.fetchall()]

    def execute(self, str sql, con=None, bint dictCur=False, tuple args=()):
        cur = self.con.cursor()
        sql = sql.replace('%s', '?')

        if not args: args = ()

        cur.execute(sql, args)

        cdef tuple i

        if dictCur:
            # 当需要返回 dict 格式时
            return (dict_factory(cur, i) for i in cur.fetchall())

        return tuple(cur.fetchall())

    def process(self, ModelExecutor executor, con=None):

        # 获取SQL生成器
        cdef BaseSqlGenerator sql = executor.sql

        # 获取数据库链接
        cdef:
            object res
            str sqlTemp
            object data
        sqlTemp, data = sql.Build()

        sqlTemp = sqlTemp.replace('%s', '?')

        cur = self.con.cursor()

        with lock:
            if isinstance(data, tuple):
                cur.execute(sqlTemp, data)
            else:
                cur.executemany(sqlTemp, data)
            self.con.commit()

        if sql.currentType != sqlType.INSERT:
            if sql.currentType == sqlType.SELECT:
                res = [dict_factory(cur, i) for i in cur.fetchall()]
            else:
                res = cur.fetchall()

        else:
            res = cur.lastrowid

        # 处理查询结果
        return executor.process(res)

cdef class AioSqliteConnector(BaseConnector):
    def __init__(self, loop: AbstractEventLoop, **kwargs):
        self.loop = loop
        self.isAsync = True
        loop.run_until_complete(self.init_sqlite(**kwargs))
        self.isUsing = False

    async def init_sqlite(self, path: str, showLog: bool = True):
        import aiosqlite

        self.con = await aiosqlite.connect(path)

        if showLog:
            await self.con.set_trace_callback(_logger.debug)

        # self.con.row_factory = dict_factory

    async def releaseCon(self, con):
        pass

    @property
    def getCon(self):
        return SqliteContextManager(self.con).acquire

    @property
    def paramsHolder(self):
        return '?'

    def autoFiledAnnounce(self, col):
        return 'INTEGER '

    def GenerateTable(self):
        self.loop.run_until_complete(generate_table())

    async def getTableNameList(self):
        cur = await self.con.execute('select tbl_name from sqlite_master where type = "table";')
        return [table['name'] for table in await cur.fetchall()]

    async def execute(self, str sql, con=None, bint dictCur=False, tuple args=()):
        cur = await self.con.cursor()
        cur.useDict = dictCur
        sql = sql.replace('%s', '?')
        await cur.execute(sql, args)

        cdef tuple i

        if dictCur:
            # 当需要返回 dict 格式时
            return [dict_factory(cur, i) for i in await cur.fetchall()]

        return tuple(await cur.fetchall())

    async def asyncProcess(self, *args, **kwargs):
        cdef AsyncModelExecutor executor = kwargs.get('executor')
        assert isinstance(executor, AsyncModelExecutor), '需要传入executor参数,且必须为AsyncModelExecutor实例'

        # 获取SQL生成器
        cdef BaseSqlGenerator sql = executor.sql

        # 获取数据库链接
        cdef:
            object res
            str sqlTemp
            object data
            bint useSelectCon = False

        sqlTemp, data = sql.Build()

        sqlTemp = sqlTemp.replace('%s', '?')

        cur = await self.con.cursor()

        if isinstance(data, tuple):
            await cur.execute(sqlTemp, data)
        else:
            await cur.executemany(sqlTemp, data)

        if sql.currentType != sqlType.INSERT:
            if sql.currentType == sqlType.SELECT:
                res = [dict_factory(cur, i) for i in await cur.fetchall()]
            else:
                res = await cur.fetchall()
        else:
            res = cur.lastrowid

        # 处理查询结果
        return executor.process(res)

cdef class AioMysqlConnector(BaseConnector):
    def __init__(self, loop: AbstractEventLoop, *args, **kwargs) -> None:
        self._config = kwargs
        self.isAsync = True
        self.Type = AioMysql
        self.selectCon = None
        self.loop = loop
        self._pool = loop.run_until_complete(self._init_mysql(*args, **kwargs))

    async def _init_mysql(self, *args, **kwargs) -> None:
        import aiomysql
        pool = await aiomysql.create_pool(*args, **kwargs)
        return pool

    def GenerateTable(self):
        self.loop.run_until_complete(generate_table())
        pass

    async def getTableNameList(self):
        dbName = self._config.get('db')
        res = await self.execute(f"SELECT TABLE_NAME FROM information_schema.`TABLES` WHERE TABLE_SCHEMA = '{dbName}';")
        return [i[0] for i in res]

    @property
    def config(self):
        return self._config

    def autoFiledAnnounce(self, col):
        cdef str typeArgs = str(col.typeArgs).replace(",", "") if str(col.typeArgs).endswith(",)") else str(col.typeArgs) if len(col.typeArgs) else ''
        return (col.targetType + typeArgs + " ") + 'AUTO_INCREMENT'

    @property
    def getCon(self):
        """
        获取链接实例

        :return:
        """
        return self._pool.acquire

    async def getSelectCon(self):
        return await self._pool.acquire()

    def releaseCon(self, con):
        """
        释放链接实例

        :param con: 数据库链接实例
        :return:
        """
        return self._pool.release(con)

    async def execute(self, str sql, con=None, bint dictCur=False, tuple args=()):
        cdef bint userSelectCon = False
        if not con:
            userSelectCon = True
            con = await self.getSelectCon()
        async with con.cursor(DictCursor if dictCur else Cursor) as cur:
            await cur.execute(sql, args)
            res = await cur.fetchall()

        if userSelectCon:
            await con.commit()
            self.releaseCon(con)

        return res

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
            bint useSelectCon = False

        if 'con' in kwargs:
            con = kwargs.get('con')
        else:
            useSelectCon = True
            con = await self.getSelectCon()

        async with con.cursor(DictCursor if sql.currentType == sqlType.SELECT else Cursor) as cur:
            sqlTemp, data = sql.Build()

            if isinstance(data, tuple):
                await cur.execute(sqlTemp, data)
            else:
                await cur.executemany(sqlTemp, data)
            if sql.currentType != sqlType.INSERT:
                res = await cur.fetchall()
            else:
                res = cur.lastrowid

        if useSelectCon:
            await con.commit()
            self.releaseCon(con)
        # 处理查询结果
        return executor.process(res)
