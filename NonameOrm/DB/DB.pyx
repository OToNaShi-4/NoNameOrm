# from typing import Coroutine, Callable
#
from typing import Generic, TypeVar

from NonameOrm.Error.DBError import DBInstanceCreateError, DBInstanceError

cdef public DB instance = None

cdef class DB:
    def __init__(self, *args, **kwargs):
        if not kwargs.get('cr'):
            raise DBInstanceCreateError()
        self._connector = kwargs.get('connector')
        global loop

    @classmethod
    def create(cls, *args, **kwargs):
        if isinstance(cls.getInstance(), DB):
            raise DBInstanceError()
        kwargs['cr'] = True
        global instance
        instance = DB(cls, *args, **kwargs)
        return instance

    def GenerateTable(self):
        self._connector.GenerateTable()
        return self

    @property
    def connector(self):
        return self._connector

    @property
    def getCon(self):
        return self._connector.getCon()

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


