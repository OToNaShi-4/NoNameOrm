from Error.DBError import *
from DB.Connector cimport BaseConnector

cdef class DB:

    def __init__(self, BaseConnector connector, *args, **kwargs):
        if not kwargs.get('cr'):
            raise DBInstanceCreateError()

    @classmethod
    def create(cls, *args, **kwargs) -> DB:
        if cls._instance:
            raise DBInstanceError()
        cls._instance = DB(cls, cr=True * args, **kwargs)
        return cls._instance

    @classmethod
    def getInstance(cls) -> DB:
        return cls._instance

    @classmethod
    def getInstanceWithCheck(cls) -> DB:
        if not cls._instance:
            raise
        return cls._instance

def use_database(fun):
    def warp(self, *args, **kwargs):
        pass
