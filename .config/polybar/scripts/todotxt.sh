#!/bin/sh

duetoday=$(grep "due:$(date -I)" ~/.todo/todo.txt | grep -c -v "x")
dueweek=0
weekday=0

pri_a=$(/usr/bin/todo.sh lsp A | wc -l)
pri_a=$((pri_a - 2))
pri_b=$(/usr/bin/todo.sh lsp B | wc -l)
pri_b=$((pri_b - 2))
pri_c=$(/usr/bin/todo.sh lsp C | wc -l)
pri_c=$((pri_c - 2))
pri_others=$(/usr/bin/todo.sh ls | wc -l)
pri_others=$((pri_others - pri_a - pri_b - pri_c - 2))

while [ "$weekday" -le 7 ]; do
	dueweek=$((dueweek + $(grep "due:$(date -I --date="$weekday day")" ~/.todo/todo.txt | grep -c -v "x")))
	weekday=$((weekday + 1))
done

echo "$duetoday %{F#f38ba8}A$pri_a %{F#b4befe}B$pri_b %{F#89dceb}C$pri_c %{F#66ffffff}$pri_others"

# if [ "$dueweek" -gt 0 ]; then
# 	echo "$duetoday $dueweek"
# else
# 	echo "$dueweek"
# fi
