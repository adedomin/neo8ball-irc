#!/usr/bin/env bash
# Copyright 2016 prussian <genunrest@gmail.com>
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

responses=(
"Signs point to yes."
"Yes."
"Reply hazy, try again".
"Without a doubt."
"My sources say no."
"As I see it, yes."
"You may rely on it."
"Concentrate and ask again."
"Outlook not so good."
"It is decidedly so."
"Better not tell you now."
"Very doubtful."
"Yes - definitely."
"It is certain."
"Cannot predict now."
"Most likely."
"Ask again later."
"My reply is no."
"Outlook good."
"Don't count on it."
)

reg="(.*) or (.*)\?" # decide
reg2="(.*)\?" # regular 8ball msg
if [[ "$4" =~ $reg ]]; then
    echo ":m $1 $3: ${BASH_REMATCH[($RANDOM % 2)+1]}"
elif [[ "$4" =~ $reg2 ]]; then
    echo ":m $1 $3: ${responses[$((RANDOM % 20))]}"
else
    echo ":mn $3 Try asking a question? (add a '?' to your question)"
fi
