# distutils: language = c++

cimport pydarts

from libcpp.vector cimport vector
from libc.stdlib cimport malloc, free

from collections import Counter

DEFAULT_MAX_RESULT = 1024


class PyDartsError(Exception):
    pass


cdef class PyDarts:
    cdef DoubleArray *_da

    def __cinit__(self):
        self._da = new DoubleArray()
        if self._da is NULL:
            raise MemoryError()

    def __dealloc__(self):
        self._da.clear()

    def __init__(self, keys=None):
        if keys is None:
            return

        if len(keys) == 0:
            raise PyDartsError('Keys is empty')

        self._build(keys)

    def _load(self, src):
        if self._da.open(src.encode('utf-8')) < 0:
            raise PyDartsError('Failed to open dict')

    cdef void _build(self, keys):
        cdef const char** _m_keys = <const char**>malloc(len(keys) * sizeof(char*))

        keys = sorted([k.encode('utf-8') for k in keys])
        for i, key in enumerate(keys):
            _m_keys[i] = key

        ret = self._da.build(len(keys), _m_keys)

        free(_m_keys)

        if ret < 0:
            raise PyDartsError('Failed to build dict')

    cpdef list search(self, text, longest=True, max_result=DEFAULT_MAX_RESULT):
        cdef result_pair_type* matched = <result_pair_type*>malloc(len(text) * sizeof(result_pair_type))
        cdef int size
        cdef list matched_len
        cdef list ret = []

        cdef int i
        for i in range(len(text)):
            t = text[i:].encode('utf-8')
            size = self._da.commonPrefixSearch(t, matched, max_result)
            if int(size) == 0:
                continue

            matched_len = [matched[i].length for i in range(size)]
            if longest:
                matched_len = [max(matched_len)]

            ret += [t[:_len] for _len in matched_len]

        free(matched)

        return [(k.decode('utf-8'), v) for k, v in Counter(ret).items()]

    def save(self, dst):
        ret = self._da.save(dst.encode('utf-8'))
        if ret < 0:
            raise PyDartsError('Failed to save dict')

    @classmethod
    def build(cls, dst, keys):
        cls(keys).save(dst)

    @classmethod
    def load(cls, src):
        return cls()._load(src)
