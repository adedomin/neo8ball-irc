#!/usr/bin/env bash
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
fi
