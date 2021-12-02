import enum
from typing import Type, Optional, Union, Callable, Dict, List

from NonameOrm.DB.DB cimport DB
from NonameOrm.Model.DataModel import DataModel
from NonameOrm.Model.DataModel cimport ModelInstance
from NonameOrm.Model.ModelExcutor cimport AsyncModelExecutor, ModelExecutor

cdef list tasks = []  # 任务列表

cdef dict taskGroup = {}  # 任务分组

tasks: List['RunnerTask']
taskGroup: Dict[Union[str, enum], List['RunnerTask']]

cdef class GeneratorRunner:
    cdef object loop

    def __init__(self, loop=None):
        self.loop = loop
        pass

    def run_group(self, *args):
        pass

    def run(self):
        if DB.getInstance().connector.isAsync:
            self.loop.run_until_complete(self.arun())
        else:
            self._run()

    cdef _run(self):
        cdef:
            int index, time
            RunnerTask task
            ModelInstance instance
            ModelExecutor executor

        for index in range(len(tasks)):
            task: RunnerTask = tasks[index]

            executor = task.model.getExecutor()

            for time in range(task.count):
                instance = task.generator(time=time + 1)
                executor.save(instance)

    async def arun(self):
        """
        执行异步创建

        :return:
        """
        cdef:
            int index, time
            RunnerTask task
            ModelInstance instance
            AsyncModelExecutor executor

        for index in range(len(tasks)):
            task: RunnerTask = tasks[index]

            executor = task.model.getExecutor()

            for time in range(task.count):
                instance = task.generator(time=time + 1)
                await executor.save(instance)

cdef class RunnerTask:
    """
        生成任务
    """

    cdef:
        object _model  # 模型对象
        object generator  # 实例生成函数
        int count  # 执行次数

    def __init__(self, model, int count, generator):
        self._model = model
        self.count = count
        self.generator = generator

    @property
    def model(self) -> DataModel:
        if not self._model:
            self._model = self.generator(time=1).object

        return self._model
def data_task(
        model: Optional[Type[DataModel]] = None,
        count: Optional[int] = 1,
        group: Union[str, enum] = None
):
    """
    创建 数据生成任务
    装饰器

    :return:
    """
    def inner(fun):
        create_task(fun, model, count, group)
        return fun
    return inner

def create_task(
        generator: Callable,
        model: Optional[Type[DataModel]] = None,
        count: Optional[int] = 1,
        group: Union[str, enum] = None):
    """
       创建 数据生成任务

       :return:
   """
    cdef RunnerTask task = RunnerTask(model=model, count=count, generator=generator)

    if group:
        if group not in taskGroup: taskGroup[group] = []  # 创建分组
        taskGroup[group].append(task)  # 加入分组

    tasks.append(task)
