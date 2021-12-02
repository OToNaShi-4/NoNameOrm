from NonameOrm.Model.ModelExcutor cimport ModelExecutor

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

cdef class Sqlite3Connector(BaseConnector):

    cdef:
        object con

    cdef init_sqlite(self, str path, bint showLog)
    cpdef str autoFiledAnnounce(self, col)
    cpdef list getTableNameList(self)

cdef class AioMysqlConnector(BaseConnector):
    cdef :
        object loop
    pass


cdef class AioSqliteConnector(BaseConnector):
    cdef:
        object loop
        object con
        bint isUsing

