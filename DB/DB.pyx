import asyncio
from typing import Coroutine, Callable

from DB.Generator import SqlGenerator
from Error.DBError import *
from DB.Connector cimport BaseConnector, ConnectorType
from Ext import generate_table

cdef public DB instance = None

cdef class DB:
    def __init__(self, *args, **kwargs):
        if not kwargs.get('cr'):
            raise DBInstanceCreateError()
        self._connector = kwargs.get('connector')

    @classmethod
    def create(cls, *args, **kwargs) -> DB:
        if isinstance(cls.getInstance(), DB):
            raise DBInstanceError()
        kwargs['cr'] = True
        global instance
        instance = DB(cls, *args, **kwargs)
        return instance

    @staticmethod
    def GenerateTable():
        loop = asyncio.get_event_loop()
        loop.run_until_complete(generate_table())

    @property
    def connector(self):
        return self._connector

    @property
    def execute(self)-> Coroutine or Callable:
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
    def getInstance(cls) -> DB:
        return instance

    @classmethod
    def getInstanceWithCheck(cls) -> DB:
        if not instance:
            raise
        return instance
