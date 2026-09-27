# Стенд: локальний менеджер репозиторіїв (TASK-55.1)

Навчальний стенд для вправ секції «12 — Репозиторії Maven і Nexus». Нічого корпоративного не потрібно:
все піднімається локально на твоїй машині або в CI.

## Що тут є

| Файл | Навіщо |
| --- | --- |
| `docker-compose.yml` | Nexus піднімається однією командою, дані живуть у томі |
| `setup-repos.sh` | Створює три репозиторії: `qa-releases` (hosted), `qa-central` (proxy на Central), `qa-public` (group) |
| `settings.xml` | Приклад налаштувань із вузьким `mirrorOf` і поясненням, чому пароль шифрують |
| `lib/` | Твоя власна бібліотека `qa-demo-lib`, яку ти деплоїш у внутрішній репозиторій |
| `consumer/` | Споживач, який залежить від неї — саме на ньому видно, звідки Maven тягне артефакт |
| `.github/workflows/verify.yml` | Автоперевірка стенда: підняти, задеплоїти, розвʼязати в чистому кеші, негативний тест |

## Docker-шлях (повний, зі справжнім Nexus)

```bash
docker compose up -d          # підняти стенд
bash setup-repos.sh           # створити репозиторії (ідемпотентно)
ADMIN=admin:qa-stand-admin
curl -u $ADMIN http://localhost:8081/service/rest/v1/repositories | head
```

Далі: UI на http://localhost:8081 (логін `admin`, пароль `qa-stand-admin`).

Деплой свого артефакту і перевірка, що його видно саме зі стенда:

```bash
mvn -s settings.xml -Dmaven.repo.local=/tmp/local-repo -f lib/pom.xml deploy
curl -u admin:qa-stand-admin -o /dev/null -w '%{http_code}\n' \
  http://localhost:8081/repository/qa-releases/qa/mentorship/qa-demo-lib/1.0.0/qa-demo-lib-1.0.0.pom
# очікуємо 200
```

Споживач у **чистому** локальному кеші (щоб не підглядав у `~/.m2`):

```bash
mvn -s settings.xml -Dmaven.repo.local=/tmp/consumer-repo -f consumer/pom.xml -X dependency:resolve | grep qa-public
```

Якщо в логах видно `qa-public` — залежність прийшла зі стенда, а не з Central.

## Шлях без Docker (спрощений)

Потрібні лише файлова система і локальний кеш Maven:

```bash
# 1) свій "репозиторій" — звичайна папка у файловій системі
mkdir -p ~/qa-m2-repo/qa/mentorship/qa-demo-lib/1.0.0
cp lib/pom.xml ~/qa-m2-repo/qa/mentorship/qa-demo-lib/1.0.0/qa-demo-lib-1.0.0.pom

# 2) вказуємо Maven брати залежності звідси
mvn -Dmaven.repo.local=$HOME/.m2/repository \
    -DremoteRepositories=file://$HOME/qa-m2-repo \
    -f consumer/pom.xml dependency:resolve
```

На цьому шляху проходять щонайменше два сценарії: робота з локальним кешем
(`~/.m2/repository`) і конфлікт версій (`mvn dependency:tree` показує дві версії однієї бібліотеки).

## Класичні пастки, на яких спотикаються всі

1. **Maven 3.8+ блокує http-репозиторії.** Локальний Nexus працює по `http://localhost:8081`, і Maven
   відмовляється з ним працювати, поки в `settings.xml` не дозволити це явно (блок
   `maven-default-http-blocker` зі `blocked=false`). У цьому стенді дозвіл уже стоїть — і в коментарі
   написано, чому в продакшені так робити не можна.
2. **`mirrorOf` ширший, ніж треба.** Якщо написати `<mirrorOf>*</mirrorOf>`, mirror перехопить і
   внутрішні репозиторії — залежність, якої немає в Central, «зникне» (сценарій 3 з TASK-55.2).
3. **`id` сервера ≠ `id` репозиторію.** Maven шукає пароль за id; розбіжність дає 401, хоча пароль
   правильний (сценарій 2 з TASK-55.2).

## Чому тут немає корпоративних систем

Стенд навмисно замкнений на собі: proxy дивиться в публічний Maven Central, hosted і group — локальні.
Жодних VPN, жодних внутрішніх хостів, жодних справжніх паролів. Це вимога, а не компроміс: вправи не
мають залежати від того, до якої мережі підключений студент.

## Автоперевірка у CI

Workflow `.github/workflows/verify.yml` робить те саме на чистій машині:
піднімає Nexus, створює репозиторії, деплоїть артефакт, розвʼязує його в чистому кеші **і** перевіряє
негативний випадок — без внутрішнього репозиторію збірка мусить упасти. Якщо прогін зелений, стенд справний.
