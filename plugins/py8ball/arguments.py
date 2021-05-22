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
from typing import Optional
from sys import argv


class Flag(Enum):
    """All possible flags neo8ball currently uses."""

    REPLY = '--reply'
    NICK = '--nick'
    USER = '--user'
    HOST = '--host'
    CMODE = '--cmode'
    MESSAGE = '--message'
    COMMAND = '--command'
    REGEXP = '--regexp'
    MATCH = '--match'


def get_argsl(arglist: Optional[list[str]] = argv[1:]) -> list[(Flag, str)]:
    """
    Neo8ball argument parser; list version.

    Args:
        arglist: (optional) A list of command line arguments, sans argv0.
                 Default: sys.argv[1:]

    Returns:
        List of (Flag, value) tuple of all parsed arguments.

    Raises:
        ValueError If a given command line argument is unexpected or has
                   no value.
    """
    args = []
    for arg in arglist:
        values = arg.split('=', maxsplit=1)
        if len(values) == 2:
            flag = Flag(values[0])
            args.append((flag, values[1]))
        else:
            raise ValueError(f"'{arg}' did not have a value.")
    return args


def get_args(arglist: Optional[list[str]] = argv[1:]) -> dict[Flag, str]:
    """
    Neo8ball argument parser; dict version.

    Args:
        arglist: (optional) A list of command line arguments, sans argv0.
                 Default: sys.argv[1:]

    Returns:
        A Dictionary of Flag enums mapping to their textual value.

    Raises:
        ValueError for unknown command line Flag(s).
    """
    return dict(get_argsl(arglist))
