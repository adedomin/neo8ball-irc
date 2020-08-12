#!/usr/bin/bash
# Copyright 2020 Anthony DeDominic <adedomin@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[[ -n "$4" ]] && set -- "$1" "$2" "$3" "$4 site:developer.mozilla.org" "$5"

"${PLUGIN_PATH?}/search.sh" "$@" \
| sed 's/\s*|[^:]*::/ ::/'
