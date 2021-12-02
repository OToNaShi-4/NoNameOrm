import enum
from asyncio import BaseEventLoop, AbstractEventLoop
from typing import Callable, Union, Optional, Type

from NonameOrm.Model.DataModel import DataModel


class GeneratorRunner:
    """
          数据任务执行器

          :return:
          """

    loop: AbstractEventLoop

    def __init__(self, loop: AbstractEventLoop): ...

    def run_group(self, *args): ...

    def run(self): ...

    async def arun(self):
        """
               执行异步创建

               :return:
       """
        ...


class RunnerTask:
    """
        数据生成任务
    """

    _model: Type[DataModel]
    generator: Callable
    count: int

    def __init__(
            self,
            model: Union[Type[DataModel], None],
            generator: Callable
    ): ...

    @property
    def model(self) -> Type[DataModel]: ...


def create_task(
        generator: Callable,
        model: Optional[Type[DataModel]] = None,
        count: Optional[int] = 1,
        group: Union[str, enum] = None
): ...


def data_task(
        model: Optional[Type[DataModel]] = None,
        count: Optional[int] = 1,
        group: Union[str, enum] = None
):...


