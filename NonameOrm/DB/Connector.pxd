cdef enum ConnectorType:
    AioMysql


cdef class BaseConnector:
    cdef:
        public object _pool
        ConnectorType Type
        public bint isAsync
        object selectCon
        public dict _config
        int count

cdef class AioMysqlConnector(BaseConnector):
    cdef :
        object loop
    pass


cdef class AioSqliteConnector(BaseConnector):
    cdef:
        object loop
        object con
        bint isUsing

