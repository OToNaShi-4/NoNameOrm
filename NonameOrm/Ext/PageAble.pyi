from typing import List, Optional, TypedDict, Union, Awaitable, Self, Callable, Type, Any, TypeVar, Generic

from NonameOrm.DB.Generator import SqlGenerator
from NonameOrm.Model.DataModel import DataModel, ModelInstance
from NonameOrm.Model.ModelProperty import FilterListCell

from NonameOrm.Ext.Dict import DictPlus


class _Page(TypedDict):
    page: int
    pageSize: int
    content: List[Union[DataModel, ModelInstance]]
    total: int
    totalPage: int

T = TypeVar('T')

class Page(dict, Generic[T]):
    """
    Page实例类
    本类继承自dict，拥有字典的一切行为

    额外支持通过 . 获取字典内容
    若获取的内容与字典类成员方法,参数相冲突，则优先选取字典内元素
    """
    page: int
    pageSize: int
    content: List[Union[T, ModelInstance]]
    total: int
    totalPage: int

    def __getattr__(self, item: str): ...

    def __getitem__(self, item: str): ...

    def __setattr__(self, key: str, value: Any): ...

    def __init__(self, page: int, pageSize: int, content=None, total: int = 0):
        pass





class _PageAble(Generic[T]):
    """
    分页控制器

    本类支持链式调用
    """

    def __init__(self, target: T, page: Optional[int] = 1, pageSize: Optional[int] = 10, findForeign: Optional[bool] = False):
        """

        :param target:
        :param page:
        :param findForeign:
        :param pageSize:
        """
        pass

    def filter(self, args: Optional[FilterListCell] = None) -> Union["_PageAble"[T], Self[T]]:
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

    def setPage(self, page: int, pageSize: Optional[int] = 0) -> Self:
        """
        设置分页

        :param page: 当前页数
        :param pageSize: 页面大小 默认可不传
        :return: PageAble
        """
        pass

    def editSql(self, callable: Callable[[SqlGenerator], None]) -> Self: ...

    @property
    def sql(self) -> SqlGenerator: ...

    def execute(self) -> Union[Page[T], Awaitable[Page[T]]]:
        """
        链式调用尽头
        正式进行数据获取
        """
        pass

def PageAble(target: T, page: int = 1, pageSize: int = 10, findForeign: bool = False) -> _PageAble[T]: ...
