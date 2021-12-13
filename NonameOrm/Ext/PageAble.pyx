# cython_ext: language_level=3
# cython: c_string_type=unicode, c_string_encoding=utf8
from NonameOrm.DB.DB import DB
from NonameOrm.DB.Generator cimport SqlGenerator
from NonameOrm.Model.DataModel cimport InstanceList
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.ModelProperty cimport FilterListCell

from NonameOrm.Ext.Dict cimport DictPlus

cdef class Page(DictPlus):
    """
    Page实例类
    本类继承自dict，拥有字典的一切行为

    额外支持通过 . 获取字典内容
    若获取的内容与字典类成员方法,参数相冲突，则优先选取字典内元素
    """
    def __init__(self, int page, int pageSize, list content=[], int total=0) -> object:
        super().__init__()
        self['page'] = page
        self['pageSize'] = pageSize
        self['content'] = content
        self['total'] = total

cdef class PageAble:
    """
    分页控制器

    本类支持链式调用
    """

    def __init__(self, target, int page=1, int pageSize=10, bint findForeign=False):
        """

        :param target:
        :param page:
        :param findForeign:
        :param pageSize:
        """
        assert pageSize > 0, "pageSize参数必须为大于零的整数"
        assert page > 0, "page参数必须为大于零的整数"

        self.target = target
        self.executor = target.getExecutor()
        self.page = page
        self.pageSize = pageSize
        self.deep = findForeign

    def filter(self, FilterListCell args=None):
        """
        设置过滤条件

        :param args: FilterListCell
        :return: PageAble
        """
        self.executor.sql.select(*self.target.col)
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

    def _getCount(self):
        cdef:
            str sqlTemp
            list args
        sqlTemp, args = SqlGenerator.build_where(self.executor.sql.whereCol)
        return DB.getInstance() \
            .executeSql(f"select count({self.target.pkName}) from {self.target.tableName} {sqlTemp}", args=tuple(args))


    async def _asyncExecute(self):
        cdef:
            Page page = Page(self.page, self.pageSize)  # 创建空page实例


        page.total = (await self._getCount())[0][0]  # 获取当前过滤条件下一共有多少条数据

        # 计算总共有多少页数据
        page.totalPage = int(page.total / self.pageSize) + 1 if page.total % self.pageSize else int(page.total / self.pageSize)

        if not page.total or self.page > page.totalPage:
            # 若分页不可能存在数据则直接返回
            return page

        # 将分页载入Sql中
        self.executor.sql.Limit(self.pageSize, self.pageSize * (self.page - 1))

        page.content = await self.executor.execute()  # 将查询结果放入page实例内

        if self.deep and len(page.content):
            # 判断是否有必要查找外键，若有则进行外键查找
            await self.executor.findListForeignKey(<InstanceList> page.content)

        return page

    cpdef Page _execute(self):
        cdef:
            Page page = Page(self.page, self.pageSize)  # 创建空page实例


        page.total = self._getCount()[0][0]  # 获取当前过滤条件下一共有多少条数据

        # 计算总共有多少页数据
        page.totalPage = int(page.total / self.pageSize) + 1 if page.total % self.pageSize else int(page.total / self.pageSize)

        if not page.total or self.page > page.totalPage:
            # 若分页不可能存在数据则直接返回
            return page

        # 将分页载入Sql中
        self.executor.sql.Limit(self.pageSize, self.pageSize * (self.page - 1))

        page.content = self.executor.execute()  # 将查询结果放入page实例内

        if self.deep and len(page.content):
            # 判断是否有必要查找外键，若有则进行外键查找
            self.executor.findListForeignKey(<InstanceList> page.content)

        return page

    def execute(self):
        """
        链式调用尽头
        正式进行数据获取

        :return: Page
        """
        if DB.getInstance().connector.isAsync:
            return self._asyncExecute()
        else:
            return self._execute()