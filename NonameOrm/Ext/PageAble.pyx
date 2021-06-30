# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelExcutor cimport BaseModelExecutor
from NonameOrm.Model.ModelProperty cimport FilterListCell

from NonameOrm.Ext.Dict cimport DictPlus

cdef class Page(DictPlus):
    """
    Page实例类
    本类继承自dict，拥有字典的一切行为

    额外支持通过 . 获取字典内容
    若获取的内容与字典类成员方法,参数相冲突，则优先选取字典内元素
    """
    def __init__(self, int page, int pageSize, list content=[], int total=0):
        super().__init__()
        self.page = page
        self.pageSize = pageSize
        self.content = content
        self.total = total

cdef class PageAble:
    """
    分页控制器

    本类支持链式调用
    """
    cdef:
        object target
        BaseModelExecutor executor
        FilterListCell filter
        int page, pageSize
        bint deep

    def __init__(self, target: DataModel, int page=0, int pageSize=10, bint findForeign=False):
        """

        :param target:
        :param page:
        :param findForeign:
        :param pageSize:
        """
        assert pageSize > 0, "pageSize参数必须为大于零的整数"
        assert page > 0, "page参数必须为大于零的整数"

        self.target = target
        self.executor = target.getAsyncExecutor()
        self.page = page
        self.pageSize = pageSize
        self.deep = findForeign

    def filter(self, FilterListCell args=None):
        """
        设置过滤条件

        :param args: FilterListCell
        :return: PageAble
        """
        self.filter = args
        self.executor.sql.where(args)
        return self

    def findForeign(self):
        self.deep = True
        return self

    def orderBy(self, *order):
        self.executor.sql.orderBy(*order)
        return self

    def setPage(self, int page, int pageSize=0):
        """
        设置分页

        :param page: 当前页数
        :param pageSize: 页面大小 默认可不传
        :return: PageAble
        """
        self.page = page
        if pageSize > 0:
            self.pageSize = pageSize
        return self

    def execute(self):
        """
        链式调用尽头
        正式进行数据获取

        :return: Page
        """
        pass
