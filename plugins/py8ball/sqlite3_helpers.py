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

import sqlite3
from functools import wraps
from pathlib import Path
from typing import Union, Callable


def escape_fts5(query: str) -> str:
    """
    Prevent any of the weird query features of Sqlite3 FTS5 Virtual Tables.

    Args:
        query: The query to be passed to an FTS5 vtable.

    Returns:
        Same string, with double quotes escaped.
        Single quotes are escaped by prepared statements.
    """
    ret = []
    for part in query.split(' '):
        ret.append(f'''"{part.replace('"', '""')}"''')
    return ' '.join(ret)


class Sqlite3Manager():
    """Manager that opens and closes a database for a function."""

    def __init__(self,
                 dbpath: Union[str, Path] = ':memory:',
                 kwarg: str = 'db'):
        """Init state of manager."""
        self.dbpath = dbpath
        self.kwarg = kwarg

    def apply(self, func: Callable) -> Callable:
        """
        Wrap a function such that it will automatically open & close a db.

        Example:
            my_manager_instance = Sqlite3Manager(db_path)
            @my_manager_instance.apply
            def my_db_func(arg1, arg2, db):
                stmt = db.execute("SELECT y FROM x LIMIT 1;")
                # ... do stuff with stmt, db, etc ...

        Args:
            func: the function to decorate

        Returns:
            Callable that has been wrapped.

        Raises:
             sqlite3.Error on any sqlite specific error condition.
        """
        @wraps(func)
        def wrap(*args, **kwargs):
            db = sqlite3.connect(self.dbpath)
            kwargs[self.kwarg] = db
            try:
                with db:
                    retval = func(*args, **kwargs)
            finally:
                db.close()
            return retval
        return wrap
