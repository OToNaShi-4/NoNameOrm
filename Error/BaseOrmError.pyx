class BaseOrmError(BaseException):
    msg: str

    def __init__(self, *args, **kwargs):
        self._process(*args, **kwargs)
        super().__init__(self.msg, *args, **kwargs)

    def _process(self, *args, **kwargs) -> None:
        pass
