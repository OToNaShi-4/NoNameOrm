# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8
cdef class DictPlus(dict):
    __slots__ = ()

    def __getattribute__(self, item):
        try:
            return self[item]
        except Exception:
            return object.__getattribute__(self, item)

    def __getattr__(self, item):
        try:
            return self[item]
        except Exception:
            return object.__getattribute__(self, item)

    def __setattr__(self, key, value):
        self.__setitem__(key,value)


