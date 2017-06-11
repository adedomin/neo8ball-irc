# common function used in plugins
URI_ENCODE() {
    curl -Gso /dev/null \
        -w '%{url_effective}' \
        --data-urlencode @- '' <<< "$1" |
    cut -c 3- |
    sed 's/%0A$//g'
}
export -f URI_ENCODE

# $1 - date in time
# turn a date into relative from now
# timestamp, e.g. 1 minute ago, ect.
reladate() {
    local unit past_suffix
    declare -i thn now diff amt
    thn=$(date --date "$1" +%s)
    now=$(date +%s)

    diff=$(( now - thn ))
    if (( diff > 0 )); then 
        past_suffix="ago"
    else
        past_suffix="from now"
        diff=$(( -diff ))
    fi

    if (( diff >= 31536000 )); then
        unit='year'
        amt=$(( diff / 31536000 ))
    elif (( diff >= 2592000 )); then
        unit='month'
        amt=$(( diff / 2592000 ))
    elif (( diff >= 86400 )); then
        unit='day'
        amt=$(( diff / 86400 ))
    elif (( diff >= 3600 )); then
        unit='hour'
        amt=$(( diff / 3600 ))
    elif (( diff >= 60 )); then
        unit='minute'
        amt=$(( diff / 60 ))
    else
        unit='second'
        amt=diff
    fi
    
    (( amt > 1 )) && unit+='s'

    echo "$amt $unit $past_suffix"
}
export -f reladate
