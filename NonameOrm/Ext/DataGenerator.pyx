import asyncio
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
    """
        数据生成执行器
        自动根据数据库链接实例的isSync 成员变量判断执行异步任务还是同步
    """
    cdef object loop # 事件循环实例

    def __init__(self, loop=None):
        self.loop = loop
        pass

    def run_group(self, *args):
        """
            执行任务组
        """
        pass

    def run(self):
        # 判断链接对象是否为异步链接
        if DB.getInstance().connector.isAsync:
            if self.loop.is_running(): # 判断事件循环是否已经启动了
                self.loop.create_task(self.arun())
            else:
                # 同步等待生成器处理完全部数据生成任务
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
        while not DB.getInstance().connector.isReady:
            await asyncio.sleep(0.3)

        cdef:
            int index, time
            RunnerTask task
            ModelInstance instance
            AsyncModelExecutor executor

        for index in range(len(tasks)):
            task: RunnerTask = tasks[index]

            con = await DB.getInstance().connector.getCon()
            executor = task.model.getExecutor(con)

            for time in range(task.count):
                instance = task.generator(time=time + 1)
                await executor.save(instance)

            await con.commit()

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
        int count: Optional[int] = 1,
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
