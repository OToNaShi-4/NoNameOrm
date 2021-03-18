from DB.Connector cimport BaseConnector

cdef class DB:
    cdef:
        DB _instance
        BaseConnector connector