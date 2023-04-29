# Cute Fem Bot Mind

## Конфиг и данные

Всё находится в папке `data`. Конфиг кладётся там в файл `config.yml`.

## Тесты

> информация ниже - по памяти и я не проверял.

```bash
$ mix test_unit

# эти тесты отрабатывают на тестовой ДБ.
# Возможно, тут надо будет пробрасывать `MIX_ENV=test`, чтобы случайно не поломалась продовая база.
$ mix test_integration
```

## Деплой

Сборка образа:

```bash
sudo docker build -t cute-fem-bot .
```

Запуск:

```bash
sudo docker run \
    # В этом пути должен лежать config.yml и будет использоваться база main.db
    -v /path/to/data:/app/data \
    # Чтобы таймзоны работали, используются системные
    -v /usr/share/zoneinfo:/usr/share/zoneinfo \
    -d cute-fem-bot
```

### Remote

```bash
docker exec -it <container> /bin/sh

# inside of container
./dist/bin/cute_fem_bot remote
```
