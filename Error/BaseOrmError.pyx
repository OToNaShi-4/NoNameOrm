class BaseOrmError(BaseException):
    msg: str

    def __init__(self, *args, **kwargs):
        self._process(*args, **kwargs)
        super().__init__(self.msg, *args, **kwargs)

    def _process(self, *args, **kwargs) -> None:
        self.msg = '这是个默认错误，没有任何意义'
