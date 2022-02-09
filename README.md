# NoName Orm
一款同时支持异步和同步的数据库orm

## 数据库支持
    1.Mysql (aiomysql)
    2.Sqlite (aiosqlite, sqlite3)

## 特性
    1. 支持以PYTHON的风格书写过滤语句。(如： User.id == 3)
    2. 查询结果(数据实例)可以被多种后端框架直接解析。(数据实例继承与DICT和LIST)
    3. 基于Python本身语法提供的分支预测支持
    4. 支持 Pydantic 模型， 能很好的支持 fastapi 特性
    5. 使用Cython编写，拥有非常可观的性能



### Document
    https://www.showdoc.com.cn/1420185181111322/6953605288730408