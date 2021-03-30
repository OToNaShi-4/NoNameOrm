cdef enum ConnectorType:
    AioMysql


cdef class BaseConnector:
    cdef:
        object _pool
        ConnectorType Type
        bint isAsync
        object selectCon

cdef class AioMysqlConnector(BaseConnector):
    pass