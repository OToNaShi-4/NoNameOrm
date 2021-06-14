import ast
from enum import Enum
from typing import List, TypedDict, Tuple, Dict

import astor
from typed_ast import ast3
import re
from numba import jit

import logging

log = logging.getLogger(__package__)
from case_convert import pascal_case

typeMatcher = re.compile(r'\(.*\)')


async def generate_table():
    from NonameOrm.DB.DB import DB
    from NonameOrm.DB.Generator import TableGenerator
    from NonameOrm.Model.DataModel import DataModel, _DataModelMeta, MiddleDataModel
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


class Null(Enum):
    yes = 'yes'
    no = 'no'


class Key(Enum):
    UNI = 'UNI'
    PRI = 'PRI'


class Extra(Enum):
    auto_increment = 'auto_increment'


class ColAnnounce(TypedDict):
    Field: str
    Type: str
    Null: Null
    Key: Key
    Default: str
    Extra: Extra


# from NonameOrm.Model.ModelProperty import *

typeMap: dict = {
    Type.bigint.value: 'IntProperty',
    Type.int.value: 'IntProperty',
    Type.decimal.value: 'FloatProperty',
    Type.json.value: 'JsonProperty',
    Type.float.value: 'FloatProperty',
    Type.text.value: 'StrProperty',
    Type.longtext.value: 'StrProperty',
    Type.tinyint.value: 'IntProperty',
    Type.tinytext.value: 'StrProperty',
    Type.varchar.value: 'StrProperty'
}

from NonameOrm.Model.ModelProperty import *

supportTypeMap: Dict[str, type(Enum)] = {
    'IntProperty': strSupportType,
    'FloatProperty': floatSupportType,
    'JsonProperty': jsonSupportType,
    'StrProperty': strSupportType,
}


def tableAnnounceToAstModule(colAnnounce: Tuple[ColAnnounce], tableName: str) -> ast3.Module:
    # 创建AST根节点
    module: ast3.Module = ast.Module(body=[])
    # 创建导入节点并添加到根节点末尾
    module.body.append(ast.ImportFrom(module='NonameOrm.Model.ModelProperty', names=[ast.alias('*', None)], level=0))
    module.body.append(ast.ImportFrom(module='NonameOrm.Model.DataModel', names=[ast.alias('DataModel', None)], level=0))
    # 创建类定义节点
    classDefNode: ast3.ClassDef = ast.ClassDef(
        bases=[ast.Name(id='DataModel', ctx=ast.Load())],
        keyword=[],
        name=pascal_case(tableName),
        body=[colAnnounceToAstNode(col) for col in colAnnounce],
        decorator_list=[]
    )
    module.body.append(classDefNode)
    return module


def colAnnounceToAstNode(colAnnounce: ColAnnounce) -> ast.stmt:
    return ast.Assign(
        targets=[ast.Name(id=colAnnounce['Field'], ctx=ast.Store)],
        value=_getColValueNode(colAnnounce),
        type_comment=''
    )


def _getColValueNode(colAnnounce: ColAnnounce) -> ast.expr:
    """
    用于创建数据列声明节点

    :param colAnnounce: 数据库列声明字典
    :return: ast.expr 节点
    """
    node: ast3.Call = ast.Call(
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

    if typeArgs := typeMatcher.findall(colAnnounce['Type']):
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

        # 处理字段类型
        try:
            typeName = typeMatcher.sub('', colAnnounce['Type'])
            colType = supportTypeMap[typeMap[typeName]][typeName]
            node.keywords.append(
                ast.keyword(
                    arg='targetType',
                    value=ast.Attribute(
                        ctx=ast.Load,
                        attr=typeName,
                        value=ast.Name(
                            ctx=ast.Load,
                            id=supportTypeMap[typeMap[typeName]].__name__
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
        colAnnounce: Tuple[ColAnnounce] = await db.executeSql(f'desc {tableName}', dictCur=True)
        module: ast3.Module = tableAnnounceToAstModule(colAnnounce, tableName)
        with open((filePath if filePath.endswith('/') else filePath + '/') + f'{pascal_case(tableName)}.py', 'w') as f:
            sourceCode = astor.to_source(module)
            f.write(sourceCode)
