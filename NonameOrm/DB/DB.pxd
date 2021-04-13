from NonameOrm.DB.Connector cimport BaseConnector


cdef class DB:
    cdef:
        BaseConnector _connector
    pass