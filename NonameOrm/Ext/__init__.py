import ast
import asyncio
import os
from enum import Enum
from typing import List, Tuple, Dict

import astor
import re

import logging

from case_convert import pascal_case

log = logging.getLogger(__package__)

typeMatcher = re.compile(r'\(.*\)')


async def async_generate_table():
    from NonameOrm.DB.DB import DB
    from NonameOrm.DB.Generator import TableGenerator
    from NonameOrm.Model.DataModel import DataModel, _DataModelMeta, MiddleDataModel

    db = DB.getInstance()
    while not db.connector.isReady:
        await asyncio.sleep(0.3)

    modelList: List[DataModel] = _DataModelMeta.ModelList
    nameList: List[str] = await db.connector.getTableNameList()

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


def _generate_table():
    from NonameOrm.DB.DB import DB
    from NonameOrm.DB.Generator import TableGenerator
    from NonameOrm.Model.DataModel import DataModel, _DataModelMeta, MiddleDataModel

    modelList: List[DataModel] = _DataModelMeta.ModelList
    db = DB.getInstance()
    nameList: List[str] = db.connector.getTableNameList()

    con = db.connector.getCon()
    try:
        for model in modelList:
            if model.tableName in nameList or model == DataModel or model == MiddleDataModel:
                continue
            db.executeSql(*TableGenerator(model).Build(), con)
    except Exception as e:
        con.rollback()
        raise e
    con.commit()
    db.connector.releaseCon(con)


def generate_table():
    from NonameOrm.DB.DB import DB

    if DB.getInstance().connector.isAsync:
        return async_generate_table()

    return _generate_table()


class Type(Enum):
    int = 'int'
    bigint = 'bigint'
    float = 'float'
    decimal = 'decimal'
    datetime = 'datetime'
    timestamp = 'timestamp'
    json = 'json'
    varchar = 'varchar'
    text = 'text'
    longtext = 'longtext'
    tinyint = 'tinyint'
    tinytext = 'tinytext'
    bit = 'bit'


class Null(Enum):
    yes = 'yes'
    no = 'no'


class Key(Enum):
    UNI = 'UNI'
    PRI = 'PRI'


class Extra(Enum):
    auto_increment = 'auto_increment'





typeMap: dict = {
    Type.bigint.value   : 'IntProperty',
    Type.int.value      : 'IntProperty',
    Type.decimal.value  : 'FloatProperty',
    Type.json.value     : 'JsonProperty',
    Type.float.value    : 'FloatProperty',
    Type.text.value     : 'StrProperty',
    Type.longtext.value : 'StrProperty',
    Type.tinyint.value  : 'IntProperty',
    Type.tinytext.value : 'StrProperty',
    Type.varchar.value  : 'StrProperty',
    Type.bit.value      : 'BoolProperty',
    Type.timestamp.value: 'TimestampProperty',
    Type.datetime.value : 'TimestampProperty'
}

from NonameOrm.Model.ModelProperty import *

supportTypeMap: Dict[str, type(Enum)] = {
    'IntProperty'      : strSupportType,
    'FloatProperty'    : floatSupportType,
    'JsonProperty'     : jsonSupportType,
    'StrProperty'      : strSupportType,
    'BoolProperty'     : boolSupportType,
    'TimestampProperty': timestampSupportType
}


def tableAnnounceToAstModule(colAnnounce: Tuple[dict], tableName: str) -> ast.Module:
    # 创建AST根节点
    module: ast.Module = ast.Module(body=[])
    # 创建导入节点并添加到根节点末尾
    module.body.append(ast.ImportFrom(module='NonameOrm.Model.ModelProperty', names=[ast.alias('*', None)], level=0))
    module.body.append(
        ast.ImportFrom(module='NonameOrm.Model.DataModel', names=[ast.alias('DataModel', None)], level=0))

    # 创建类定义节点
    classDefNode: ast.ClassDef = ast.ClassDef(
        bases=[ast.Name(id='DataModel', ctx=ast.Load())],
        keyword=[],
        name=pascal_case(tableName),
        body=[colAnnounceToAstNode(col) for col in colAnnounce],
        decorator_list=[]
    )
    module.body.append(classDefNode)
    return module


def colAnnounceToAstNode(colAnnounce: dict) -> ast.stmt:
    return ast.Assign(
        targets=[ast.Name(id=colAnnounce['Field'], ctx=ast.Store)],
        value=_getColValueNode(colAnnounce),
        type_comment=''
    )


def _getColValueNode(colAnnounce: dict) -> ast.expr:
    """
    用于创建数据列声明节点

    :param colAnnounce: 数据库列声明字典
    :return: ast.expr 节点
    """
    node: ast.Call = ast.Call(
        func=ast.Name(id=typeMap[typeMatcher.sub('', colAnnounce['Type'])], ctx=ast.Load()),
        args=[],
        keywords=[]
    )
    if colAnnounce['Key'] == Key.PRI.value:
        # 添加主键声明参数
        node.keywords.append(ast.keyword(arg='pk', value=ast.Constant(value=True)))
        if colAnnounce['Extra'] == Extra.auto_increment.value:
            # 判断是否自增字段，是则添加自增声明参数
            node.keywords.append(ast.keyword(arg='default', value=ast.Name(id='auto_increment', ctx=ast.Load())))

    if colAnnounce['Default']:
        # 判断字段是否有默认值，有则添加默认值
        node.keywords.append(ast.keyword(arg='default', value=ast.Constant(value=colAnnounce['Default'])))

    typeArgs = typeMatcher.findall(colAnnounce['Type'])
    if typeArgs:
        # 判断是否有类型参数，有则添加类型参数节点
        node.keywords.append(
            ast.keyword(
                arg='typeArgs',
                value=ast.Tuple(
                    ctx=ast.Load,
                    elts=[ast.Constant(value=x) for i in typeArgs for x in re.findall(r'\d+', i)]
                )
            )
        )
        typeName = typeMatcher.sub('', colAnnounce['Type'])
        # 处理字段类型
        try:
            colType = supportTypeMap[typeMap[typeName]]
            node.keywords.append(
                ast.keyword(
                    arg='targetType',
                    value=ast.Attribute(
                        ctx=ast.Load,
                        attr=typeName,
                        value=ast.Name(
                            ctx=ast.Load,
                            id=colType.__name__
                        )
                    )
                )
            )
        except Exception:
            log.info(f'无匹配类型{typeName},故略过')
            pass

    return node


async def generate_model(filePath: str):
    """
    自动侦测数据库表结构，并生成相应的模型类文件

    :param filePath: 模型类文件生成路径
    :return: void
    """
    from NonameOrm.DB.DB import DB

    db = DB.getInstance()
    dbName = db.connector.config.get('db')
    res: Tuple[Tuple[str]] = await db.executeSql(f"SELECT TABLE_NAME FROM information_schema.`TABLES` WHERE TABLE_SCHEMA = '{dbName}';")
    for i in range(len(res)):
        tableName: str = res[i][0]
        colAnnounce: Tuple[dict] = await db.executeSql(f'desc {tableName}', dictCur=True)
        await _saveAstModuleByTableName(tableName, colAnnounce, filePath)


async def autoGenerate(filePath: str):
    """
    自动匹配本地数据模型与数据库表结构的差异，自动更新

    :param filePath: 模型类文件生成路径
    :return: void
    """
    from NonameOrm.DB.DB import DB

    db = DB.getInstance()
    dbName = db.connector.config.get('db')
    tableTuple: Tuple[Tuple[str]] = await db.executeSql(f"SELECT TABLE_NAME FROM information_schema.`TABLES` WHERE TABLE_SCHEMA = '{dbName}';")
    con = await db.connector.getCon()
    pyFiles = _getAllPyFilesByPath(filePath)
    for (tableName,) in tableTuple:
        colAnnounce: Tuple[dict] = await db.executeSql(f'desc {tableName}', dictCur=True)
        if pascal_case(tableName) + '.py' in pyFiles:
            with open('', 'r') as f:
                await _updateModelAst(ast.parse(f.read()), tableName, colAnnounce)
        else:

            await _saveAstModuleByTableName(tableName, colAnnounce, filePath)


async def _updateModelAst(moduleAst: ast.Module, tableName: str, filePath: str, colAnnounceList: List[dict]):
    """
    用于更新DataModel文件

    :param modelAst:
    :param tableName:
    :param filePath:
    :return:
    """
    colAssignMap: Dict[str:ast.Assign] = _getColAssignFromAstModule(moduleAst)
    for colAnnounce in colAnnounceList:
        if colAnnounce['Field'] in colAssignMap:
            del colAssignMap[colAnnounce['Field']]
            continue

    with open((filePath if filePath.endswith('/') else filePath + '/') + f'{pascal_case(tableName)}.py', '+') as f:
        sourceCode = astor.to_source(moduleAst)
        f.write(sourceCode)


async def _saveAstModuleByTableName(tableName: str, colAnnounce, filePath):
    """
    根据数据库表名自动分析并生成对应的NonameOrm模型文件

    :param tableName: 数据库表名
    :param db: 数据库实例
    :param filePath: 模型文件生成路径
    :return: void
    """
    module: ast.Module = tableAnnounceToAstModule(colAnnounce, tableName)
    with open((filePath if filePath.endswith('/') else filePath + '/') + f'{pascal_case(tableName)}.py', 'w') as f:
        sourceCode = astor.to_source(module)
        f.write(sourceCode)


def _getColAssignFromAstModule(module: ast.Module) -> Dict[str, ast.Assign]:
    """
    从

    :param module:
    :return:
    """
    colAssignMap: Dict[str, ast.Assign] = dict()
    for node in ast.walk(module):
        if isinstance(node, ast.Assign) and node.targets[0].id.endswith('Property'):
            colAssignMap[node.targets[0].id] = node
    return colAssignMap


def _getAllPyFilesByPath(path: str) -> List[str]:
    """
    获取指定路径下所有python文件名

    :param path: 系统路径
    :return: List[str]
    """
    pyFiles = []
    for i, j, k in os.walk(path):
        pyFiles.extend([file for file in k if file.endswith('.py')])
    return pyFiles
