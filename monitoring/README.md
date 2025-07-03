# KBot Monitoring Stack

Цей проєкт містить повноцінний моніторинговий стек для Telegram бота kbot з використанням OpenTelemetry, Prometheus, Fluentbit, Grafana Loki та Grafana.

## Компоненти стеку

- **OpenTelemetry Collector** - збір трасів, метрик та логів
- **Prometheus** - збір та зберігання метрик
- **Fluentbit** - збір логів з контейнерів та нод кластеру
- **Grafana Loki** - зберігання логів
- **Grafana** - візуалізація метрик та логів

## Структура проєкту

```
monitoring/
├── docker-compose.yaml          # Локальний стек без kbot
├── docker-compose.kbot.yaml     # Локальний стек з kbot
├── otel-collector-config.yaml   # Конфігурація OTEL Collector
├── prometheus.yml               # Конфігурація Prometheus
├── fluentbit.conf               # Конфігурація Fluentbit
├── parsers.conf                 # Парсери для Fluentbit
├── loki-config.yaml             # Конфігурація Loki
├── grafana/                     # Конфігурація Grafana
│   ├── provisioning/
│   │   ├── datasources/
│   │   └── dashboards/
│   └── dashboards/
├── k8s/                         # Kubernetes маніфести
│   ├── namespace.yaml
│   ├── otel-collector.yaml
│   ├── prometheus.yaml
│   ├── fluentbit.yaml
│   ├── loki.yaml
│   ├── grafana.yaml
│   ├── kbot.yaml
│   └── kustomization.yaml
└── flux/                        # Flux GitOps конфігурація
    └── gotk-sync.yaml
```

## Рівні розгортання

### Junior (3 бали) - Локальне розгортання

Для локального розгортання моніторингового стеку:

1. **Підготовка:**
   ```bash
   cd monitoring
   export TELE_TOKEN="your_telegram_bot_token"
   ```

2. **Запуск стеку:**
   ```bash
   # Запуск тільки моніторингового стеку
   docker-compose up -d
   
   # Або запуск з kbot
   docker-compose -f docker-compose.kbot.yaml up -d
   ```

3. **Доступ до сервісів:**
   - Grafana: http://localhost:3000 (admin/admin)
   - Prometheus: http://localhost:9090
   - Loki: http://localhost:3100
   - KBot metrics: http://localhost:8080/metrics

### Middle (7 балів) - Kubernetes розгортання

1. **Підготовка кластеру:**
   ```bash
   # Створення namespace
   kubectl apply -f k8s/namespace.yaml
   
   # Створення секрету з токеном
   kubectl create secret generic kbot-secret \
     --from-literal=tele-token="your_telegram_bot_token" \
     -n monitoring
   ```

2. **Розгортання стеку:**
   ```bash
   # Розгортання всіх компонентів
   kubectl apply -k k8s/
   
   # Або окремо
   kubectl apply -f k8s/otel-collector.yaml
   kubectl apply -f k8s/prometheus.yaml
   kubectl apply -f k8s/fluentbit.yaml
   kubectl apply -f k8s/loki.yaml
   kubectl apply -f k8s/grafana.yaml
   kubectl apply -f k8s/kbot.yaml
   ```

3. **Портфорвардинг для доступу:**
   ```bash
   kubectl port-forward svc/grafana 3000:3000 -n monitoring
   kubectl port-forward svc/prometheus 9090:9090 -n monitoring
   kubectl port-forward svc/loki 3100:3100 -n monitoring
   ```

### Senior (10 балів) - Flux GitOps розгортання

1. **Встановлення Flux:**
   ```bash
   # Встановлення Flux CLI
   curl -s https://fluxcd.io/install.sh | sudo bash
   
   # Bootstrap Flux в кластері
   flux bootstrap github \
     --owner=your-username \
     --repository=kbot \
     --branch=main \
     --path=./monitoring/k8s \
     --personal
   ```

2. **Розгортання через GitOps:**
   ```bash
   # Застосування Flux конфігурації
   kubectl apply -f flux/gotk-sync.yaml
   
   # Перевірка статусу
   flux get kustomizations
   flux get sources git
   ```

3. **Автоматичне розгортання:**
   - Зміни в Git репозиторії автоматично розгортаються в кластері
   - Flux відстежує зміни кожну хвилину
   - Kustomization застосовується кожні 10 хвилин

### Principal (20 балів) - Наскрізний TraceID

Проєкт вже інструментований з наскрізним TraceID через OpenTelemetry:

- Кожна команда Telegram створює span з унікальним TraceID
- Метрики та логи пов'язані через TraceID
- Всі компоненти підтримують distributed tracing

## Інструментація kbot

KBot інструментований для експорту:

### Метрики Prometheus:
- `telegram_commands_total` - кількість команд по типу та користувачу
- `telegram_messages_total` - загальна кількість повідомлень
- `telegram_response_time_seconds` - час відповіді на команди

### Траси OpenTelemetry:
- Кожна команда створює span з атрибутами
- TraceID передається через весь стек
- Підтримка baggage для додаткового контексту

### Логи:
- Структуровані логи з метаданими
- Інтеграція з Kubernetes labels
- Централізований збір через Fluentbit

## Дашборди Grafana

### KBot Overview Dashboard
- Графік швидкості команд Telegram
- Статус сервісу kbot
- Логи в реальному часі
- Метрики продуктивності

### Доступ до дашборду:
1. Відкрийте Grafana (http://localhost:3000)
2. Логін: admin/admin
3. Дашборд "KBot Overview" буде доступний автоматично

## Моніторинг та алерти

### Ключові метрики для моніторингу:
- `up{job="kbot"}` - доступність сервісу
- `rate(telegram_commands_total[5m])` - швидкість команд
- `histogram_quantile(0.95, telegram_response_time_seconds)` - 95-й перцентиль часу відповіді

### Приклади алертів:
```yaml
# Приклад Prometheus Rule
groups:
  - name: kbot
    rules:
      - alert: KBotDown
        expr: up{job="kbot"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "KBot is down"
```

## Troubleshooting

### Перевірка статусу компонентів:
```bash
# Docker Compose
docker-compose ps

# Kubernetes
kubectl get pods -n monitoring
kubectl logs -f deployment/kbot -n monitoring
```

### Перевірка метрик:
```bash
# Prometheus
curl http://localhost:9090/api/v1/targets

# KBot metrics
curl http://localhost:8080/metrics
```

### Перевірка логів:
```bash
# Loki
curl http://localhost:3100/ready

# Fluentbit
kubectl logs -f daemonset/fluentbit -n monitoring
```

## Розширення

### Додавання нових метрик:
1. Додайте метрики в `internal/telemetry/telemetry.go`
2. Оновіть дашборд Grafana
3. Додайте алерти в Prometheus Rules

### Додавання нових джерел логів:
1. Оновіть конфігурацію Fluentbit
2. Додайте нові парсери
3. Оновіть Loki queries в Grafana

## Ліцензія

MIT License - дивіться LICENSE файл в корені проєкту. 