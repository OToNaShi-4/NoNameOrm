from typing import List, Optional, TypedDict, Union

from NonameOrm.Model.DataModel import DataModel, ModelInstance
from NonameOrm.Model.ModelProperty import FilterListCell

from NonameOrm.Ext.Dict import DictPlus


class _Page(TypedDict):
    page: int
    pageSize: int
    content: List[Union[DataModel, ModelInstance]]
    total: int
    totalPage: int


class Page(_Page):
    """
    Page实例类
    本类继承自dict，拥有字典的一切行为

    额外支持通过 . 获取字典内容
    若获取的内容与字典类成员方法,参数相冲突，则优先选取字典内元素
    """

    def __init__(self, page: int, pageSize: int, content=None, total: int = 0):
        pass


class PageAble:
    """
    分页控制器

    本类支持链式调用
    """

    def __init__(self, target: Type[DataModel], page: Optional[int] = 1, pageSize: Optional[int] = 10, findForeign: Optional[bool] = False):
        """

        :param target:
        :param page:
        :param findForeign:
        :param pageSize:
        """
        pass

    def filter(self, args: Optional[FilterListCell] = None) -> "PageAble":
        """
        设置过滤条件

        :param args: FilterListCell
        :return: PageAble
        """
        pass

    def findForeign(self) -> 'PageAble':
        pass

    def orderBy(self, *order: List[str]) -> 'PageAble':
        pass

    def setPage(self, page: int, pageSize: Optional[int] = 0) -> 'PageAble':
        """
        设置分页

        :param page: 当前页数
        :param pageSize: 页面大小 默认可不传
        :return: PageAble
        """
        pass

    def execute(self) -> Page:
        """
        链式调用尽头
        正式进行数据获取

        :return: Page
        """
        pass
