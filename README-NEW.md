# KBot - Telegram Bot with Monitoring Stack

KBot - це Telegram бот на Go з повноцінним моніторинговим стеком, що включає OpenTelemetry, Prometheus, Fluentbit, Grafana Loki та Grafana.

## 🚀 Швидкий старт

### Локальне розгортання (Junior - 3 бали)

```bash
# Клонування репозиторію
git clone https://github.com/your-username/kbot.git
cd kbot

# Запуск моніторингового стеку
cd monitoring
export TELE_TOKEN="your_telegram_bot_token"
./deploy.sh local with-kbot
```

### Kubernetes розгортання (Middle - 7 балів)

```bash
# Розгортання в Kubernetes
export TELE_TOKEN="your_telegram_bot_token"
./monitoring/deploy.sh k8s

# Портфорвардинг для доступу
kubectl port-forward svc/grafana 3000:3000 -n monitoring
```

### Flux GitOps розгортання (Senior - 10 балів)

```bash
# Розгортання через Flux
export GITHUB_USER="your-username"
export GITHUB_REPO="kbot"
export TELE_TOKEN="your_telegram_bot_token"
./monitoring/deploy.sh flux
```

## 📊 Моніторинговий стек

### Компоненти:
- **OpenTelemetry Collector** - збір трасів, метрик та логів
- **Prometheus** - збір та зберігання метрик
- **Fluentbit** - збір логів з контейнерів та нод кластеру
- **Grafana Loki** - зберігання логів
- **Grafana** - візуалізація метрик та логів

### Метрики:
- `telegram_commands_total` - кількість команд по типу та користувачу
- `telegram_messages_total` - загальна кількість повідомлень
- `telegram_response_time_seconds` - час відповіді на команди

### Траси:
- Наскрізний TraceID для кожної команди
- Distributed tracing через OpenTelemetry
- Інтеграція з метриками та логами

## 🎯 Функціональність бота

### Доступні команди:
- `/start` - привітання та інструкції
- `/help` - список доступних команд
- `/hello` - персональне привітання
- `/version` - версія програми
- `/ping` - перевірка доступності

### Особливості:
- Інструментація з OpenTelemetry
- Експорт метрик Prometheus
- Структуровані логи
- Наскрізний TraceID

## 📈 Дашборди Grafana

### KBot Overview
- Графік швидкості команд Telegram
- Статус сервісу kbot
- Логи в реальному часі

### KBot Detailed Monitoring
- Детальні метрики по типах команд
- Перцентилі часу відповіді
- Розподіл команд
- Логи помилок

## 🛠️ Розробка

### Залежності:
```go
go.opentelemetry.io/otel v1.21.0
github.com/prometheus/client_golang v1.17.0
gopkg.in/telebot.v3 v3.3.8
github.com/spf13/cobra v1.9.1
```

### Збірка:
```bash
# Локальна збірка
go build -o kbot main.go

# Docker збірка
docker build -t kbot .

# Запуск
./kbot kbot
```

## 📁 Структура проєкту

```
kbot/
├── cmd/                    # CLI команди
│   ├── kbot.go            # Основна логіка бота
│   ├── root.go            # Коренева команда
│   └── version.go         # Версія
├── internal/
│   └── telemetry/         # Інструментація
│       └── telemetry.go   # OpenTelemetry та Prometheus
├── monitoring/            # Моніторинговий стек
│   ├── docker-compose.yaml
│   ├── k8s/              # Kubernetes маніфести
│   ├── flux/             # Flux GitOps
│   └── grafana/          # Дашборди
├── main.go               # Точка входу
├── Dockerfile            # Docker образ
└── go.mod               # Go модулі
```

## 🔧 Конфігурація

### Змінні середовища:
- `TELE_TOKEN` - токен Telegram бота (обов'язково)

### Порти:
- `8080` - метрики Prometheus
- `4317` - OTLP gRPC
- `4318` - OTLP HTTP
- `9090` - Prometheus UI
- `3000` - Grafana
- `3100` - Loki

## 🚨 Моніторинг та алерти

### Ключові метрики:
- `up{job="kbot"}` - доступність сервісу
- `rate(telegram_commands_total[5m])` - швидкість команд
- `histogram_quantile(0.95, telegram_response_time_seconds)` - 95-й перцентиль

### Приклад алерту:
```yaml
- alert: KBotDown
  expr: up{job="kbot"} == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "KBot is down"
```

## 🐛 Troubleshooting

### Перевірка статусу:
```bash
# Локальний стек
./monitoring/deploy.sh status

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

## 📚 Документація

Детальна документація доступна в [monitoring/README.md](monitoring/README.md)

## 🤝 Внесок

1. Fork проєкту
2. Створіть feature branch (`git checkout -b feature/amazing-feature`)
3. Commit зміни (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Відкрийте Pull Request

## 📄 Ліцензія

Цей проєкт ліцензований під MIT License - дивіться [LICENSE](LICENSE) файл для деталей.

## 🙏 Подяки

- [OpenTelemetry](https://opentelemetry.io/) - для інструментації
- [Prometheus](https://prometheus.io/) - для збору метрик
- [Grafana](https://grafana.com/) - для візуалізації
- [Fluentbit](https://fluentbit.io/) - для збору логів
- [Telebot](https://github.com/tucnak/telebot) - для Telegram API 