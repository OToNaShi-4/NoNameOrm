import functools

from NonameOrm.DB.DB import DB

def use_database(fun):
    @functools.wraps(fun)
    async def warp(self, *args, **kwargs):
        async with DB.getInstance().connector.getCon() as self.con:
            try:
                res = await fun(self, *args, **kwargs)
                await self.con.commit()
                return res
            except Exception as e:
                await self.con.rollback()
                raise e

    return warp
