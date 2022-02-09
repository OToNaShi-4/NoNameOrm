import functools
import inspect
from typing import Awaitable

from NonameOrm.DB.DB import DB
from pydantic import BaseModel


def pydantic_support(obj: BaseModel) -> BaseModel:
    """
        装饰器，也可当函数使用
        装饰后的pydantic模型可以被 NonameOrm 所使用
    """
    setattr(obj, '__getitem__', lambda self, item: getattr(self, item))  # 使模型可以通过['xxx']访问成员
    setattr(obj, '__setitem__', lambda self, item, value: setattr(self, item, value))  # 使模型可以通过 x['xx'] = xxx 来变更成员
    setattr(obj, 'get', lambda self, item, default: getattr(self, item))  # 使模型可以使用get('xxx',xxx)获取成员
    setattr(obj, '__contains__', lambda self, item: hasattr(self, item))  # 使模型可以使用 in 操作附判断是否含有成员
    return obj


def use_database(fun):
    if inspect.iscoroutinefunction(fun):
        @functools.wraps(fun)
        async def wrap(*args, **kwargs):
            con = await DB.getInstance().connector.getCon()
            try:
                return await fun(*args, **kwargs)
            except Exception as e:
                await con.rollback()
                raise e
    else:
        @functools.wraps(fun)
        def wrap(*args, **kwargs):
            con = DB.getInstance().connector.getCon()
            try:
                return fun(*args, **kwargs)
            except Exception as e:
                con.rollback()
                raise e
    return wrap
