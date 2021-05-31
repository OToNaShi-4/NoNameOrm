from typing import List


async def generate_table():
    from NonameOrm.DB.DB import DB
    from NonameOrm.DB.Generator import TableGenerator
    from NonameOrm.Model.DataModel import DataModel, _DataModelMeta,MiddleDataModel
    modelList: List[DataModel] = _DataModelMeta.ModelList
    db = DB.getInstance()
    dbName = db.connector.config.get('db')
    res = await db.executeSql(f"SELECT TABLE_NAME FROM information_schema.`TABLES` WHERE TABLE_SCHEMA = '{dbName}';")
    nameList: List[str] = [i[0] for i in res]

    con = await db.connector.getCon()
    try:
        for model in modelList:
            if model.tableName in nameList or model == DataModel or model == MiddleDataModel:
                continue
            await db.executeSql(*TableGenerator(model).Build(), con)
    except Exception as e:
        await con.rollback()
        raise e
    await con.commit()
    await db.connector.releaseCon(con)
