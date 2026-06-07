# BeeAtlas FDM Infrastructure (Docker Compose)

## Оглавление
1. [Общее описание](#1-общее-описание)
2. [Два режима запуска](#2-два-режима-запуска)
3. [Архитектура и сервисы](#3-архитектура-и-сервисы)
4. [Требования](#4-требования)
5. [Быстрый старт](#5-быстрый-старт)
6. [Submodules и локальная разработка](#6-submodules-и-локальная-разработка)
7. [Режимы аутентификации](#7-режимы-аутентификации)
8. [Конфигурация](#8-конфигурация)
9. [Управление средой](#9-управление-средой)
10. [Порты и URL](#10-порты-и-url)
11. [Postman](#11-postman)
12. [Известные ограничения локального стенда](#12-известные-ограничения-локального-стенда)
13. [Лицензия](#13-лицензия)

---

## 1. Общее описание

`beeatlas-fdm-infrastructure` — репозиторий для поднятия **BeeAtlas FDM** одной командой Docker Compose.

Все сервисы находятся в сети `fdm-network` и используют общую инфраструктуру:

| Компонент | Назначение |
|-----------|------------|
| **PostgreSQL** (`postgres`) | Единая БД `fdm_db`, отдельные **схемы** на сервис (`init-schemas.sql`) |
| **RabbitMQ** (`rabbitmq`) | Очереди и exchange; конфиг в `rabbitmq/definitions.json` |
| **Redis** (`redis`) | Кэш для `architect-graph-service`; Authentik (профиль `AUTHENTIC_AUTH`) |
| **Neo4j** (`neo4j`) | Граф архитектуры для `architect-graph-service` |
| **MinIO** (`document-service-minio`) | S3-хранилище для `document-service` |
| **Gateway** (`gateway`) | Единая точка входа API |
| **Frontend** (`beeatlas-frontend`) | UI BeeAtlas |

Общие переменные окружения — в **`common.env`**.

---

## 2. Два режима запуска

| Файл | Когда использовать |
|------|-------------------|
| **`docker-compose.yml`** | Локальная **сборка** из submodules (`services/*/Dockerfile`) |
| **`docker-compose-run.yml`** | Запуск **готовых образов** из GHCR (`ghcr.io/tech-beeline/...:latest`) |

```bash
# Локальная сборка
docker compose up -d --build

# Готовые образы
docker compose -f docker-compose-run.yml pull
docker compose -f docker-compose-run.yml up -d
```

Обновление всех образов из registry:

```bash
docker compose -f docker-compose-run.yml pull
docker compose -f docker-compose-run.yml up -d --pull always --force-recreate
```

> **Важно:** изменения в submodule (например, миграции Flyway) попадут в `docker-compose-run.yml` только после **сборки и push образа** в GHCR. Для проверки свежего кода используйте `docker-compose.yml` или локальный `docker build`.

---

## 3. Архитектура и сервисы

### Инфраструктура

- `postgres`, `rabbitmq`, `redis`, `neo4j`
- `document-service-minio`, `document-service-minio-init`
- `on-premises` — Structurizr On-Premises (порт 8087)
- `mcp-gateway` — MCP gateway (Unla)

### Java / Spring Boot

| Сервис | Схема Postgres | Назначение |
|--------|----------------|------------|
| `gateway` | — | API Gateway, маршрутизация, demo/authentik auth |
| `fdm-auth-backend` | `user_auth` | Аутентификация и роли |
| `capability-backend` | `capability` | Business / Tech Capability |
| `products-service` | `product` | Продукты, контейнеры, операции |
| `techradar-backend` | `techradar` | Техрадар, технологии, процессы |
| `architect-graph-service` | — (Neo4j) | Архитектурный граф, RabbitMQ, Redis |
| `cx-service` | `cx` | Customer Journey |
| `notifications-service` | `notification` | Уведомления |
| `document-service` | `documents` | Документы (S3/MinIO) |
| `fdm-pack-loader` | `pack_loader` | Загрузка пакетов |
| `events-history` | `entity_events` | История событий сущностей |
| `fdm-bpm` | `processes` (+ Camunda) | BPM / процессы |

### Python / Node / прочее

| Сервис | Назначение |
|--------|------------|
| `structurizr-backend` | API диаграмм (FastAPI) |
| `ff-manager` | Feature flags (схема `ff`) |
| `obs-dashboard` | Генерация Grafana E2E-дашбордов по CJ |
| `beeatlas-frontend` | Frontend |

Схемы создаются при **первом** старте Postgres из `init-schemas.sql`:

`product`, `capability`, `user_auth`, `techradar`, `pack_loader`, `entity_events`, `processes`, `cx`, `notification`, `documents`, `ff`.

RabbitMQ при первом старте загружает очереди из `rabbitmq/definitions.json` (в т.ч. graph-очереди, `user_drop_cache`, `capability.exchange`).

---

## 4. Требования

| Компонент | Версия |
|-----------|--------|
| Docker Engine | 20.10+ |
| Docker Compose (v2) | 2.0+ |
| Git | для submodules |
| Java 17 / Maven | только при сборке без Docker |

Убедитесь, что свободны порты **3000**, **5433**, **5434**, **5672**, **6379**, **7474**, **7687**, **8080–8096**, **15672** (при необходимости — переопределите через `*_SERVICE_PORT` в compose).

---

## 5. Быстрый старт

### 5.1 Клонирование с submodules

```bash
git clone --recurse-submodules https://github.com/tech-beeline/beeatlas-fdm-infrastructure.git
cd beeatlas-fdm-infrastructure
```

Если submodules не подтянулись:

```bash
git submodule update --init --recursive
```

### 5.2 DEMO (рекомендуется для первого запуска)

Gateway по умолчанию с `DEMO_AUTH=true` — запросы без OAuth-токена.

**Локальная сборка:**

```bash
docker compose up -d --build
```

**Готовые образы:**

```bash
docker compose -f docker-compose-run.yml up -d
```

После старта в БД появляются тестовые данные auth/products (миграции в submodules).

### 5.3 AUTHENTIC (Authentik)

Поднимает `redis`, `authentik-postgres`, `authentik-server`, `authentik-worker` через профиль Compose.

```powershell
$env:AUTHENTIC_AUTH="true"
docker compose --profile true up -d --build
```

Authentik UI: `http://localhost:5000` (user `akadmin`, pass из `AUTHENTIK_BOOTSTRAP_PASSWORD` в compose).

### 5.4 Проверка

```bash
docker compose ps
curl -s http://localhost:8080/actuator/health
curl -s http://localhost:8081/actuator/health   # fdm-auth-backend
```

---

## 6. Submodules и локальная разработка

Исходники микросервисов — git submodules в `services/` (см. `.gitmodules`).

Typical workflow:

```bash
# обновить submodule до последнего main
cd services/techradar-service && git pull origin main && cd ../..

# пересобрать один сервис
docker compose build techradar-backend
docker compose up -d techradar-backend
```

Для `docker-compose-run.yml` после push в GitHub дождитесь нового образа в GHCR и выполните `pull` (см. раздел 2).

---

## 7. Режимы аутентификации

### DEMO_AUTH

- `DEMO_AUTH=true` на gateway
- Тестовый пользователь без Bearer-токена

### AUTHENTIC_AUTH (Authentik)

- `AUTHENTIC_AUTH=true` + `docker compose --profile true`
- Redis с паролем `redis-password` (см. `common.env`)
- Получение токена — через Authentik OAuth2 (authorize → token → `Authorization: Bearer ...`)

---

## 8. Конфигурация

### `common.env`

Общие настройки для большинства Java-сервисов:

- Postgres: `SPRING_DATASOURCE_*`
- RabbitMQ: `SPRING_RABBITMQ_HOST=rabbitmq` (имя **сервиса**, не `container_name`)
- Neo4j, Redis, URL интеграций между сервисами

Переопределения для отдельных сервисов — в секции `environment` в compose.

### Ключевые переменные по сервисам

| Сервис | Переменные |
|--------|------------|
| **gateway** | `DEMO_AUTH`, `AUTHENTIC_AUTH`, `QUEUE_USER_DROP_CACHE_NAME` |
| **architect-graph-service** | `SPRING_REDIS_*`, `INTEGRATION_PRODUCT_SERVER_URL`, RabbitMQ exchange |
| **fdm-bpm** | отдельные datasource для Camunda / processes / git |
| **ff-manager** | `FF_DB_*`, `FF_*_API_BASE_URL` |
| **obs-dashboard** | `GRAFANA_URL`, `E2E_TEMPLATE_URL` (URL вида `{GRAFANA_URL}/d/{uid}/...`), `CX_SERVICE_URL`, `PRODUCT_SERVICE_URL` |

### Где задавать переменные

- файл `.env` в корне (Docker Compose подхватывает автоматически)
- PowerShell: `$env:VAR="value"` перед `docker compose ...`

---

## 9. Управление средой

```bash
# остановка (данные сохраняются)
docker compose down
docker compose -f docker-compose-run.yml down

# полная очистка томов (чистая БД, RabbitMQ, Neo4j…)
docker compose down -v

# логи
docker compose logs -f gateway
docker compose logs -f techradar-backend

# перезапуск одного сервиса
docker compose restart capability-backend
```

> `down` **не удаляет** тома. `down -v` — удаляет `postgres-data`, `rabbitmq-data` и др.; `init-schemas.sql` выполнится только при **первом** создании volume Postgres.

После `down -v` Flyway накатывает миграции заново. Для techradar на чистой БД миграция V19 вставляет процессы только для `tech_id`, которые уже есть в таблице `tech`.

---

## 10. Порты и URL

| Компонент | Host URL | Примечание |
|-----------|----------|------------|
| **Gateway** | http://localhost:8080 | API / Swagger |
| **Frontend** | http://localhost:3000 | beeatlas-frontend |
| **fdm-auth-backend** | http://localhost:8081 | |
| **capability-backend** | http://localhost:8082 | |
| **architect-graph-service** | http://localhost:8083 | |
| **products-service** | http://localhost:8084 | |
| **techradar-backend** | http://localhost:8085 | |
| **structurizr-backend** | http://localhost:8086/docs | OpenAPI |
| **Structurizr On-Premises** | http://localhost:8087 | |
| **cx-service** | http://localhost:8088 | |
| **notifications-service** | http://localhost:8089 | |
| **document-service** | http://localhost:8091 | |
| **fdm-pack-loader** | http://localhost:8092 | |
| **events-history** | http://localhost:8093 | |
| **fdm-bpm** | http://localhost:8094 | |
| **ff-manager** | http://localhost:8095 | |
| **obs-dashboard** | http://localhost:8096 | Node.js API |
| **PostgreSQL** | localhost:5433 | `postgres/postgres`, БД `fdm_db` |
| **Authentik Postgres** | localhost:5434 | профиль AUTHENTIC |
| **RabbitMQ UI** | http://localhost:15672 | `guest/guest` |
| **Neo4j Browser** | http://localhost:7474 | `neo4j/password` |
| **Neo4j Bolt** | bolt://localhost:7687 | |
| **MinIO API / Console** | :9000 / :9001 | если порты не переопределены |
| **Authentik UI** | http://localhost:5000 | профиль AUTHENTIC |
| **MCP Gateway** | http://localhost:18080 | Unla |

Порты настраиваются через переменные `*_SERVICE_PORT` в compose.

---

## 11. Postman

В папке `postman/` — коллекция для Gateway.

- Import → файл из `postman/`
- Переменная окружения `baseUrl` = `http://localhost:8080`

---

## 12. Известные ограничения локального стенда

| Тема | Детали |
|------|--------|
| **Grafana** | В compose **нет** сервиса Grafana; URL в `common.env` — заглушка. `obs-dashboard` требует реальный Grafana и корректный `E2E_TEMPLATE_URL` для полной работы |
| **obs-dashboard** | При старте проверяет формат `E2E_TEMPLATE_URL` (`{GRAFANA_URL}/d/{uid}/...`). Без Grafana API publish дашбордов не заработает |
| **GHCR образы** | Тег `:latest` кэшируется локально — используйте `pull --force` или `docker rmi` перед pull |
| **init-schemas.sql** | Только при **первом** создании volume Postgres; на существующей БД схемы добавляйте вручную |
| **RabbitMQ definitions** | На существующем volume RabbitMQ новые exchange/очереди из JSON могут не подтянуться — пересоздайте volume или добавьте вручную |
| **Внешние интеграции** | CMDB, staging-sequence, ambassador и др. в `common.env` — mock URL, сервисов в compose нет |

---

## 13. Лицензия

Проект распространяется под **Apache License 2.0**. См. файл `LICENSE`.

---

## Краткий чек-лист

| Шаг | Команда |
|-----|---------|
| Клон с submodules | `git clone --recurse-submodules …` |
| DEMO (build) | `docker compose up -d --build` |
| DEMO (GHCR) | `docker compose -f docker-compose-run.yml up -d` |
| Обновить образы | `docker compose -f docker-compose-run.yml pull && … up -d --force-recreate` |
| AUTHENTIC | `$env:AUTHENTIC_AUTH="true"; docker compose --profile true up -d` |
| Остановка | `docker compose down` |
| Чистая БД | `docker compose down -v` |
| Логи | `docker compose logs -f <service-name>` |
