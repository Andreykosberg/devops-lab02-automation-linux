#!/bin/bash
# Погода (температура и влажность) для заданного города -> index.html дефолтного сайта nginx
# Использование: ./weather.sh <город>
# Источник данных: wttr.in (JSON, формат j1), разбор через jq
# Запускается по cron раз в минуту (см. crontab -l)

set -euo pipefail

CITY="${1:?Укажите город, например: ./weather.sh Perm}"
OUT="/var/www/html/index.html"

JSON="$(curl -s "wttr.in/${CITY}?format=j1")"

if [ -z "$JSON" ]; then
    echo "Ошибка: нет ответа от wttr.in" >&2
    exit 1
fi

TEMP_C="$(echo "$JSON" | jq -r '.current_condition[0].temp_C')"
HUMIDITY="$(echo "$JSON" | jq -r '.current_condition[0].humidity')"

cat > "$OUT" <<HTML
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Погода: ${CITY}</title></head>
<body>
<h1>Погода в городе ${CITY}</h1>
<p>Температура: ${TEMP_C} &deg;C</p>
<p>Влажность: ${HUMIDITY}%</p>
<p><small>Обновлено: $(date '+%Y-%m-%d %H:%M:%S')</small></p>
</body>
</html>
HTML
