# cute-fem-bot

## Деплой

Подготовка вольюма:

```shell
sudo docker volume create cute-fem-bot-state
```

Сборка образа:

```shell
sudo docker build -t cute-fem-bot .
```

Запуск в режиме long-polling:

```shell
# UPDATE_APPROACH could be omitted
sudo docker run \
    -e UPDATE_APPROACH=long-polling \
    -v cute-fem-bot-state:/data \
    -d cute-fem-bot
```

Запуск в режиме webhook (нужно настраивать церты и проксирование):

```shell
sudo docker run \
    -e UPDATE_APPROACH=webhook \
    -e PUBLIC_PATH=https://public-bot-base-path.com \
    -p 80:3000 \
    -v cute-fem-bot-state:/data \
    -d cute-fem-bot
```
