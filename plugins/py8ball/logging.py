# Copyright (C) 2021  Anthony DeDominic <adedomin@gmail.com>

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from enum import Enum
from functools import partial
from os.path import basename
import inspect


class LogLevel(Enum):
    """Enum of valid loglevels (commands)."""

    DEBUG = ':logd'
    INFO = ':logi'
    WARNING = ':logw'
    ERROR = ':loge'


def log(level: LogLevel, out: str):
    callee_frame = inspect.stack()[1]
    callee = basename(callee_frame.filename)
    print(f'{level.value} {callee}: {out}')


log_d = partial(log, LogLevel.DEBUG)
log_i = partial(log, LogLevel.INFO)
log_w = partial(log, LogLevel.WARNING)
log_e = partial(log, LogLevel.ERROR)
