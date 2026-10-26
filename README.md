# Лаб. П02 — Автоматизация в Linux (bash, cron, nginx)

Bash-скрипт, который по названию города выводит текущую температуру и влажность
(через `wttr.in` и `jq`), установка `nginx`, запуск скрипта по `cron` раз в минуту
с сохранением результата в `index.html` дефолтного сайта.

## Стенд

Та же VM, что и в лабораторной П01: Ubuntu Server 24.04.3 LTS в **Oracle VirtualBox**
(`devops-lab01`, 1 vCPU, ~2 ГБ RAM), сеть NAT. Проброс портов:

| Правило | Host | Guest |
|---|---|---|
| `ssh`  | `127.0.0.1:2223` | `22` (SSH) |
| `http` | `127.0.0.1:8080` | `80` (nginx) |

Работа выполнена пользователем `andrey` (пароль `andrey`, группа `sudo`), под ним же
настроен `cron`.

## Содержимое

| Файл | Назначение |
|---|---|
| `weather.sh` | скрипт: город → температура/влажность → `index.html` |
| `screenshots/` | подтверждение работы |

## Задание и как оно выполнено

> Написать bash-скрипт, который принимает в качестве входящего параметра город.
> Выводит температуру и влажность в текущий день в этом городе. Установить nginx.
> Скрипт запускать по крону раз в минуту, вывод сохранять в `index.html` дефолтного
> сайта. Источник данных: [wttr.in](https://github.com/chubin/wttr.in) (JSON, `jq`).

| # | Шаг | Как выполнено |
|---|---|---|
| 1 | Скрипт принимает город параметром | `weather.sh <город>`, `CITY="${1:?...}"` — скриншот 2 |
| 2 | Температура и влажность за текущий день | `curl -s "wttr.in/${CITY}?format=j1"`, разбор через `jq '.current_condition[0].temp_C / .humidity'` — скриншот 3 |
| 3 | Установка nginx | `sudo apt-get install -y nginx jq`, `systemctl is-active nginx` → `active` — скриншот 1 |
| 4 | Запуск по cron раз в минуту | `crontab -e`: `* * * * * /home/andrey/weather.sh Perm > /dev/null 2>&1` — скриншот 4 |
| 5 | Результат в `index.html` дефолтного сайта | скрипт пишет в `/var/www/html/index.html` (стоит раньше `index.nginx-debian.html` в директиве `index` nginx по умолчанию) |
| 6 | Демонстрация города | по заданию — `Perm` (`wttr.in/Perm`) |

## Скрипт `weather.sh`

```bash
#!/bin/bash
set -euo pipefail

CITY="${1:?Укажите город, например: ./weather.sh Perm}"
OUT="/var/www/html/index.html"

JSON="$(curl -s "wttr.in/${CITY}?format=j1")"

TEMP_C="$(echo "$JSON" | jq -r '.current_condition[0].temp_C')"
HUMIDITY="$(echo "$JSON" | jq -r '.current_condition[0].humidity')"

cat > "$OUT" <<HTML
<!DOCTYPE html>
...
<p>Температура: ${TEMP_C} &deg;C</p>
<p>Влажность: ${HUMIDITY}%</p>
...
HTML
```

Полный текст — в файле [`weather.sh`](./weather.sh).

## Развёртывание (команды, выполненные на VM)

```bash
sudo apt-get install -y nginx jq                       # nginx + jq
sudo chown andrey:andrey /var/www/html                 # чтобы cron (не root) мог писать index.html
sudo chmod u+w /var/www/html

./weather.sh Perm                                       # ручной запуск
cat /var/www/html/index.html                             # проверка результата
curl -s 127.0.0.1                                        # проверка через nginx локально

(crontab -l 2>/dev/null; echo "* * * * * /home/andrey/weather.sh Perm > /dev/null 2>&1") | crontab -
crontab -l
```

На хосте добавлен проброс порта: `VBoxManage controlvm devops-lab01 natpf1 "http,tcp,127.0.0.1,8080,,80"`,
после чего `curl http://127.0.0.1:8080/` с хоста отдаёт ту же страницу, и значение `Обновлено: ...`
меняется каждую минуту — это подтверждает, что `cron` действительно перезапускает скрипт
(скриншот 5: два последовательных запроса с разницей в 2 минуты показывают разные метки времени).

## Что отличается от лекции / не выполнено

- Результат сохраняется в `/var/www/html/index.html`, а не в `index.nginx-debian.html`:
  `index.html` стоит первым в директиве `index` конфигурации nginx по умолчанию, поэтому
  именно он будет отдан клиенту; трогать системный `index.nginx-debian.html` не требуется.
- Для записи `index.html` от имени обычного пользователя (`andrey`, под которым работает
  `cron`) каталог `/var/www/html` сделан доступным на запись владельцу (`chown`/`chmod u+w`),
  без изменения прав на весь nginx или запуска cron от root.
- Город для демонстрации — `Perm`, как явно указано в задании (`wttr.in/Perm`).

## Скриншоты

1. `screenshots/01-nginx-jq-install.png` — установка `nginx`/`jq`, `systemctl is-active nginx`, версии.
2. `screenshots/02-weather-script.png` — содержимое `weather.sh`.
3. `screenshots/03-manual-run-perm.png` — `jq`-разбор JSON от `wttr.in/Perm`, ручной запуск скрипта,
   содержимое `index.html`, ответ nginx (`curl 127.0.0.1`).
4. `screenshots/04-cron.png` — `crontab -l` (запуск раз в минуту) и запись в `/var/log/syslog`,
   подтверждающая реальный запуск по cron.
5. `screenshots/05-port-forward-live.png` — проброс порта VirtualBox `8080→80` и два запроса
   с хоста к `127.0.0.1:8080` с разницей в 2 минуты — метка времени в ответе меняется,
   значит страница обновляется автоматически по cron.
