import functools

from NonameOrm.DB.DB import DB

def use_database(fun):
    @functools.wraps(fun)
    async def warp(self, *args, **kwargs):
        self.con = await DB.getInstance().connector.getCon()
        try:
            res = await fun(self, *args, **kwargs)
        except Exception as e:
            await self.con.rollback()
            raise e
        else:
            await self.con.commit()
            return res
        DB.getInstance().releaseCon(self.con)
    return warp
