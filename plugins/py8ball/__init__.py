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

from functools import wraps
from typing import Callable, Optional

from .arguments import get_argsl
from .logging import log_e


LEN_LIMIT = 350


def guard_large_int(inp: str,
                    max_size: Optional[int] = 2**31-1,
                    min_size: Optional[int] = -(2**31)) -> int:
    """
    Convert an input up to [min_size, max_size].

    Args:
        inp: The user controlled input to coerce into an int.
        max_size: The maxium integer size (default signed 32bit max).
        min_size: The minimum integer size (default signed 32bit min).

    Returns:
        The input converted into an int.

    Raises:
        OverflowError if max or min are exceeded.
        ValueError if argument is not an integer.
    """
    max_s_str = str(max_size)
    min_s_str = str(min_size)
    if inp[0] == '-':
        if len(inp) > len(min_s_str):
            raise OverflowError(f'Argument exceeds minimum size: {min_s_str}.')
        elif len(inp) == len(min_s_str) and inp > min_s_str:
            raise OverflowError(f'Argument exceeds minimum size: {min_s_str}.')
    else:
        if len(inp) > len(max_s_str):
            raise OverflowError(f'Argument exceeds maximum size: {max_s_str}.')
        elif len(inp) == len(max_s_str) and inp > max_s_str:
            raise OverflowError(f'Argument exceeds maximum size: {max_s_str}.')
    return int(inp)


def main_decorator(func: Callable) -> Callable:
    """
    Decorate a plugin entry point that handles parsing command line arguments.

    This allows the user to fetch the command line arguments they want to use,
    using kwargs.
    If you want, say --message=value only, define your main()
    as `main(message):`
    If you want the "command" name, you'd use main(*, command):
    Regexps would be main(*, match, regexp):
    see Example below.

    See:
        .arguments.Flags: for all command line arguments possible.
                          Strip leading double slash for the kwarg
                          name to use in your main().

    Example:
        @main_decorator
        def main(*, command, message, nick, reply, ...etc):
            print(command)
            print(message)
            # ... etc

    Args:
        func: A "main" function for a neo8ball plugin that uses pure kwargs.

    Returns:
        Wrapped callable which returns an exit code.
    """
    argspec = func.__code__.co_varnames

    @wraps(func)
    def w() -> int:
        try:
            new_args = {}
            for flag, value in get_argsl():
                real_flag = flag.value[2:]
                if real_flag in argspec:
                    new_args[real_flag] = value
            ret = func(**new_args)
        except ValueError as e:
            log_e(str(e))
            return 1

        return ret
    return w
