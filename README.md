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
sudo docker run -v /home/username/cute-fem-bot/data:/data -v /usr/share/zoneinfo:/usr/share/zoneinfo -d cute-fem-bot
```


## TODO

- Сохранять пользовательское форматирование при отправке его текста в предложку
- При постинге сжатых картинок постить их дополнительно и разжатыми?
