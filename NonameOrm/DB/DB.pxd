from NonameOrm.DB.Connector cimport BaseConnector


cdef class DB:
    cdef:
        public BaseConnector _connector
    pass