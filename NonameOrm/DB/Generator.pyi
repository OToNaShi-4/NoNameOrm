from typing import List, Tuple

from NonameOrm.Model import DataModel
from NonameOrm.Model.ModelProperty import BaseProperty, FilterListCell, ForeignKey


class JoinCell:
    def __init__(self, fk: ForeignKey, joinType): ...


class BaseSqlGenerator:
    def Build(self): ...


class SqlGenerator(BaseSqlGenerator):
    selectCol: List[BaseProperty]
    limit: str
    joinList: List[JoinCell]
    target: DataModel

    def __init__(self): ...

    def values(self, *args) -> SqlGenerator: ...

    def insert(self, model: DataModel) -> SqlGenerator: ...

    def select(self, *args: List[BaseProperty]) -> SqlGenerator: ...

    def update(self, target: DataModel) -> SqlGenerator: ...

    def set(self, *args) -> SqlGenerator: ...

    def From(self, target: DataModel) -> SqlGenerator: ...

    def where(self, args: FilterListCell = None) -> SqlGenerator: ...

    def Build(self) -> Tuple[str and List[str]]: ...

    def Limit(self, count: int, offset: int) -> SqlGenerator: ...

    def join(self, foreignKey: ForeignKey, joinType=None) -> SqlGenerator: ...

    def leftJoin(self, foreignKey: ForeignKey) -> SqlGenerator: ...

    def rightJoin(self, foreignKey: ForeignKey) -> SqlGenerator: ...

    def innerJoin(self, foreignKey: ForeignKey) -> SqlGenerator: ...


class TableGenerator(BaseSqlGenerator):
    model: DataModel

    def Build(self): ...


class CustomColAnnounce(BaseSqlGenerator):
    def __init__(self, sql: str): ...

