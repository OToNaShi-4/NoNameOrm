from Error.DBError import *


cdef class DB:
    cdef DB _instance

    def __cinit__(self):
        pass

    @classmethod
    def create(cls, *args, **kwargs) -> DB:
        if cls._instance:
            raise DBInstanceError()
        cls._instance = DB()
        return cls._instance

    @classmethod
    def getInstance(cls) -> DB:
        return cls._instance

    @classmethod
    def getInstanceWithCheck(cls) -> DB:
        if not cls._instance:
            raise
        return cls._instance

