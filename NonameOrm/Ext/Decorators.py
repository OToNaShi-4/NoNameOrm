import functools
import inspect
from typing import Awaitable

from NonameOrm.DB.DB import DB


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
