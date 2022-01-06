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

Запуск:

```shell
sudo docker run \
    -e PUBLIC_PATH=http://99.99.99.99:80 \
    -p 80:3000 \
    -v cute-fem-bot-state:/data \
    cute-fem-bot
```
