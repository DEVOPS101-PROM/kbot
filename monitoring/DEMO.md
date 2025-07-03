# Демонстрація моніторингового стеку KBot

Цей документ містить покрокові інструкції для демонстрації повноцінного моніторингового стеку KBot.

## 🎯 Цілі демонстрації

1. **Junior (3 бали)**: Показати локальне розгортання стеку
2. **Middle (7 балів)**: Показати Kubernetes розгортання
3. **Senior (10 балів)**: Показати Flux GitOps розгортання
4. **Principal (20 балів)**: Показати наскрізний TraceID

## 🚀 Швидка демонстрація (Junior)

### Крок 1: Підготовка
```bash
# Клонування репозиторію
git clone https://github.com/your-username/kbot.git
cd kbot

# Встановлення залежностей
go mod tidy
```

### Крок 2: Запуск стеку
```bash
cd monitoring
export TELE_TOKEN="your_telegram_bot_token"
./deploy.sh local with-kbot
```

### Крок 3: Перевірка компонентів
```bash
# Перевірка контейнерів
docker ps

# Перевірка метрик kbot
curl http://localhost:8080/metrics

# Перевірка Prometheus
curl http://localhost:9090/api/v1/targets
```

### Крок 4: Доступ до Grafana
1. Відкрийте http://localhost:3000
2. Логін: `admin` / `admin`
3. Дашборд "KBot Overview" буде доступний автоматично

### Крок 5: Тестування бота
1. Знайдіть свого бота в Telegram
2. Відправте команди: `/start`, `/help`, `/hello`, `/ping`
3. Спостерігайте за метриками в Grafana

## 🐳 Kubernetes демонстрація (Middle)

### Крок 1: Підготовка кластеру
```bash
# Перевірка кластеру
kubectl cluster-info

# Створення namespace
kubectl apply -f monitoring/k8s/namespace.yaml
```

### Крок 2: Розгортання стеку
```bash
export TELE_TOKEN="your_telegram_bot_token"
./monitoring/deploy.sh k8s
```

### Крок 3: Перевірка розгортання
```bash
# Перевірка подів
kubectl get pods -n monitoring

# Перевірка сервісів
kubectl get svc -n monitoring

# Логи kbot
kubectl logs -f deployment/kbot -n monitoring
```

### Крок 4: Доступ до сервісів
```bash
# Портфорвардинг Grafana
kubectl port-forward svc/grafana 3000:3000 -n monitoring &

# Портфорвардинг Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring &

# Портфорвардинг Loki
kubectl port-forward svc/loki 3100:3100 -n monitoring &
```

### Крок 5: Демонстрація логів
```bash
# Перевірка логів Fluentbit
kubectl logs -f daemonset/fluentbit -n monitoring

# Перевірка логів kbot
kubectl logs -f deployment/kbot -n monitoring
```

## 🔄 Flux GitOps демонстрація (Senior)

### Крок 1: Встановлення Flux
```bash
# Встановлення Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Перевірка встановлення
flux version
```

### Крок 2: Bootstrap Flux
```bash
export GITHUB_USER="your-username"
export GITHUB_REPO="kbot"
export TELE_TOKEN="your_telegram_bot_token"

./monitoring/deploy.sh flux
```

### Крок 3: Перевірка GitOps
```bash
# Перевірка джерел
flux get sources git

# Перевірка kustomizations
flux get kustomizations

# Перевірка синхронізації
flux get kustomizations kbot-monitoring
```

### Крок 4: Демонстрація автоматичного розгортання
```bash
# Зміна версії в Git
git commit -m "Update kbot version" --allow-empty
git push

# Спостерігання за автоматичним розгортанням
flux get kustomizations kbot-monitoring --watch
```

## 🔍 Наскрізний TraceID демонстрація (Principal)

### Крок 1: Перевірка трасів
```bash
# Відправте команди боту
# Перевірте траси в OpenTelemetry Collector
kubectl logs -f deployment/otel-collector -n monitoring
```

### Крок 2: Аналіз TraceID
1. Відкрийте Grafana
2. Перейдіть до Explore
3. Виберіть Loki як джерело даних
4. Виконайте запит: `{service_name="kbot"}`
5. Знайдіть TraceID в логах

### Крок 3: Кореляція метрик та логів
1. В Prometheus виконайте запит: `telegram_commands_total`
2. Порівняйте з логами за TraceID
3. Покажіть зв'язок між метриками та трасами

## 📊 Демонстрація дашбордів

### KBot Overview Dashboard
1. Відкрийте Grafana
2. Перейдіть до "KBot Overview"
3. Покажіть:
   - Графік швидкості команд
   - Статус сервісу
   - Логи в реальному часі

### KBot Detailed Monitoring Dashboard
1. Перейдіть до "KBot Detailed Monitoring"
2. Покажіть:
   - Розподіл команд по типах
   - Перцентилі часу відповіді
   - Кількість активних користувачів
   - Логи помилок

## 🚨 Демонстрація алертів

### Створення тестового алерту
```yaml
# prometheus-rules.yaml
groups:
  - name: kbot
    rules:
      - alert: KBotHighResponseTime
        expr: histogram_quantile(0.95, telegram_response_time_seconds) > 1
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "KBot response time is high"
```

### Тестування алерту
```bash
# Симуляція високого часу відповіді
# Відправте багато команд боту одночасно
```

## 🧪 Тестування стійкості

### Тест навантаження
```bash
# Створення навантаження
for i in {1..100}; do
  curl -X POST "http://localhost:8080/metrics" &
done
wait

# Спостерігання за метриками
```

### Тест відмовостійкості
```bash
# Видалення поду kbot
kubectl delete pod -l app=kbot -n monitoring

# Спостерігання за автоматичним відновленням
kubectl get pods -n monitoring --watch
```

## 📈 Метрики для демонстрації

### Ключові метрики:
```promql
# Швидкість команд
rate(telegram_commands_total[5m])

# Час відповіді
histogram_quantile(0.95, telegram_response_time_seconds)

# Доступність
up{job="kbot"}

# Кількість повідомлень
telegram_messages_total
```

### Запити Loki:
```logql
# Всі логи kbot
{service_name="kbot"}

# Логи помилок
{service_name="kbot"} |= "error"

# Логи з TraceID
{service_name="kbot"} |~ "trace_id"
```

## 🎬 Сценарій демонстрації

### 1. Вступ (2 хв)
- Представлення проєкту
- Показ структури
- Пояснення компонентів

### 2. Локальне розгортання (3 хв)
- Запуск стеку
- Показ Grafana
- Тестування бота

### 3. Kubernetes розгортання (5 хв)
- Розгортання в кластері
- Показ логів
- Демонстрація масштабування

### 4. GitOps розгортання (3 хв)
- Bootstrap Flux
- Автоматичне розгортання
- Демонстрація CI/CD

### 5. Наскрізний TraceID (2 хв)
- Показ трасів
- Кореляція метрик та логів
- Демонстрація distributed tracing

### 6. Дашборди та алерти (3 хв)
- Показ дашбордів
- Демонстрація алертів
- Тестування навантаження

### 7. Висновки (2 хв)
- Підсумки
- Переваги рішення
- Можливості розширення

## 🔧 Troubleshooting

### Поширені проблеми:
```bash
# Проблема з портами
sudo lsof -i :3000
sudo lsof -i :9090

# Проблема з контейнерами
docker logs otel-collector
docker logs prometheus

# Проблема з Kubernetes
kubectl describe pod -n monitoring
kubectl get events -n monitoring
```

### Корисні команди:
```bash
# Очищення
./monitoring/deploy.sh cleanup

# Перевірка статусу
./monitoring/deploy.sh status

# Перезапуск стеку
docker-compose restart
```

## 📝 Чек-лист демонстрації

- [ ] Локальний стек запущений
- [ ] Grafana доступна
- [ ] Prometheus збирає метрики
- [ ] Loki збирає логи
- [ ] KBot відповідає на команди
- [ ] Kubernetes розгортання працює
- [ ] Flux GitOps налаштований
- [ ] TraceID відстежується
- [ ] Дашборди показують дані
- [ ] Алерти працюють
- [ ] Тести навантаження пройдені 