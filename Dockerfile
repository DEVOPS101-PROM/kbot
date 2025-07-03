# syntax=docker/dockerfile:1.4
# Цей Dockerfile призначений для створення образів kbot для Linux

# --- Етап Збирача (Builder) ---
FROM quay.io/projectquay/golang:1.24 AS builder

# Аргументи для збірки
ARG TARGETOS
ARG TARGETARCH

# Встановлення робочої директорії
WORKDIR /app

# Копіювання залежностей
COPY go.mod go.sum ./

# Завантаження Go модулів
RUN echo "Завантаження Go модулів в етапі збирача..." && \
    go mod download && \
    go mod verify

# Копіювання вихідного коду
COPY . .

# Компіляція
RUN echo "Запуск компіляції kbot для ${TARGETOS}/${TARGETARCH}..." && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -a -v -o bin/kbot -ldflags "-X 'github.dev/DEVOPS101-PROM/kbot/cmd.appVersion=${VERSION}' -extldflags '-static'"

# --- Етап Фінального Образу ---
FROM scratch AS final

# Встановлення робочої директорії
WORKDIR /app

# Копіювання бінарного файлу
COPY --from=builder /app/bin/kbot .

# Копіювання SSL сертифікатів
COPY --from=builder /etc/ssl/certs /etc/ssl/certs

# Точка входу
ENTRYPOINT ["/app/kbot", "kbot"]
