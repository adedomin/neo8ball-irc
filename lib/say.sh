filename=$(date +%s)
espeak --stdout "$4" > "$5/${filename}.wav"
echo ":w $1 ${filename}.wav"
