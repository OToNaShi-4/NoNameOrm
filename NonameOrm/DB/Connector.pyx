import asyncio
import multiprocessing
import threading
from asyncio import AbstractEventLoop, Task

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

cdef class PyMysqlConnector(BaseConnector):
    def __init__(self):
        self.isAsync = False

    cdef init_pymysql(self):
        pass

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
        self.init_sqlite(**kwargs)
        self.isUsing = False
        self.conMap = {}

    def init_sqlite(self, path: str, showLog: bool = True):
        self.path = path
        self.isReady = True

        # self.con.row_factory = dict_factory

    def releaseCon(self, task: Task) -> None:
        """
            task call back
        """
        con = self.conMap.get(task)
        print(task)
        if task.exception():
            # if the task run fail, roll back all the change
            async def wrap():
                await con.rollback()
                await con.close()
                del self.conMap[task]
            asyncio.create_task(wrap())
        else:
            # if the task run success, commit all the change
            async def wrap():
                await con.commit()
                await con.close()
                del self.conMap[task]
            asyncio.create_task(wrap())

    async def getCon(self):
        import aiosqlite
        current_task = asyncio.current_task()
        con = self.conMap.get(current_task)
        if not con:
            con = await aiosqlite.connect(self.path)
            current_task.add_done_callback(self.releaseCon)
            self.conMap[current_task] = con
        return con

    @property
    def paramsHolder(self):
        return '?'

    def autoFiledAnnounce(self, col):
        return 'INTEGER '

    def GenerateTable(self):
        if self.loop.is_running():
            asyncio.create_task(generate_table())
        else:
            self.loop.run_until_complete(generate_table())

    async def getTableNameList(self):
        cur = await (await self.getCon()).execute('select tbl_name as name from sqlite_master where type = "table";')
        data = [dict_factory(cur, i) for i in await cur.fetchall()]
        return [table['name'] for table in data]

    async def execute(self, str sql, con=None, bint dictCur=False, tuple args=()):
        while not self.isReady:
            await asyncio.sleep(0.3)
        cur = await (await self.getCon()).cursor()
        cur.useDict = dictCur
        sql = sql.replace('%s', '?')
        await cur.execute(sql, args)

        cdef tuple i

        if dictCur:
            # 当需要返回 dict 格式时
            return [dict_factory(cur, i) for i in await cur.fetchall()]

        return tuple(await cur.fetchall())

    async def asyncProcess(self, *args, **kwargs):

        while not self.isReady:
            await asyncio.sleep(0.3)
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

        cur = await (await self.getCon()).cursor()

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
        self.conMap = {}
        if not loop.is_running():
            loop.run_until_complete(self._init_mysql(*args, **kwargs))
        else:
            loop.create_task(self._init_mysql(*args, **kwargs))

    async def _init_mysql(self, *args, **kwargs) -> None:
        import aiomysql
        pool = await aiomysql.create_pool(*args, **kwargs)
        self.isReady = True
        self._pool= pool

    def GenerateTable(self):
        if self.loop.is_running():
            self.loop.create_task(generate_table())
        else:
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

    async def getCon(self):
        """
        获取链接实例

        :return:
        """
        task = asyncio.current_task()
        if not self.conMap.get(task):
            self.conMap[task] = await self._pool.acquire()
            task.add_done_callback(self._releaseCon)
        return self.conMap.get(task)

    async def getSelectCon(self):
        return await self._pool.acquire()

    def _releaseCon(self, task: Task):
        con = self.conMap.get(task)
        if task.exception():
            async def wrap():
                await con.rollback()
                await self._pool.release(con)
        else:
            async def wrap():
                await con.commit()
                await self._pool.release(con)
        self.loop.create_task(wrap())

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
            con = await self.getCon()
        async with con.cursor(DictCursor if dictCur else Cursor) as cur:
            await cur.execute(sql, args)
            res = await cur.fetchall()
        return res

    async def asyncProcess(self, *args, **kwargs):
        # 获取异步执行对象
        cdef AsyncModelExecutor executor = kwargs.get('executor')
        assert isinstance(executor, AsyncModelExecutor), '需要传入executor参数,且必须为AsyncModelExecutor实例'

        # 获取SQL生成器
        cdef BaseSqlGenerator sql = executor.sql

        # 获取数据库链接
        cdef:
            object res
            str sqlTemp
            tuple data

        if 'con' in kwargs:
            con = kwargs.get('con')
        else:
            con = await self.getCon()

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

        # 处理查询结果
        return executor.process(res)
