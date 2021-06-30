# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8
cdef class DictPlus(dict):
    __slots__ = ()

    def __getattribute__(self, item):
        try:
            return self[item]
        except AttributeError:
            return object.__getattribute__(self, item)

    def __getattr__(self, item):
        try:
            return self[item]
        except AttributeError:
            return object.__getattribute__(self, item)

    def __setattr__(self, key, value):
        self[key] = value

    def __setitem__(self, key, value):
        self[key] = value
