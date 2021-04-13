import asyncio
# from typing import Coroutine, Callable
#
from NonameOrm.Error.DBError import DBInstanceCreateError, DBInstanceError
from NonameOrm.Ext import generate_table

cdef public DB instance = None

cdef class DB:
    def __init__(self, *args, **kwargs):
        if not kwargs.get('cr'):
            raise DBInstanceCreateError()
        self._connector = kwargs.get('connector')

    @classmethod
    def create(cls, *args, **kwargs):
        if isinstance(cls.getInstance(), DB):
            raise DBInstanceError()
        kwargs['cr'] = True
        global instance
        instance = DB(cls, *args, **kwargs)
        return instance

    def GenerateTable(self):

        loop = asyncio.get_event_loop()
        loop.run_until_complete(generate_table())
        return self

    @property
    def connector(self):
        return self._connector

    @property
    def execute(self):
        if self._connector.isAsync:
            return self.connector.asyncProcess
        else:
            return self.connector.process

    @property
    def executeSql(self):
        return self.connector.execute

    @property
    def instance(self):
        return instance

    @property
    def ConnectorType(self):
        return self.connector.Type

    @classmethod
    def getInstance(cls):
        return instance

    @classmethod
    def getInstanceWithCheck(cls):
        if not instance:
            raise
        return instance
