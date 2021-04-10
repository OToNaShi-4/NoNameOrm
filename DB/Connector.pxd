cdef enum ConnectorType:
    AioMysql


cdef class BaseConnector:
    cdef:
        object _pool
        ConnectorType Type
        bint isAsync
        object selectCon
        public dict _config

cdef class AioMysqlConnector(BaseConnector):
    pass
