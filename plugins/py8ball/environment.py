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

from os import environ
from pathlib import Path


def get_persistant_location() -> Path:
    """
    Gets either XDG_CONFIG_HOME or the legacy PERSIST_LOC
    Environment variable.

    Returns:
        Pathlib object of the path stored in XDG_CONFIG_HOME

    Raises:
        KeyError when neither varible exists.
    """
    ret = environ.get('XDG_DATA_HOME')
    if ret is None:
        return Path(environ['PERSIST_LOC'])
    else:
        path = Path(ret) / "neo8ball"
        path.mkdir(parents=True, exist_ok=True)
        return path


def check_channel_list(env: str, channel: str) -> bool:
    """
    Check if a given environment variable contains a channel.

    Args:
        env: The name of the environment variable.
        channel: The IRC channel name.

    Returns:
        True if channel is in environment variable.
    """
    try:
        channel_list = environ[env]
    except KeyError:
        return False

    return True if channel in channel_list.split() else False
