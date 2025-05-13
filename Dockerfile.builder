# syntax=docker/dockerfile:1.4
# Цей Dockerfile призначений для створення багатоархітектурних образів kbot,
# які можна запускати. Він використовує Makefile для компіляції.

# --- Етап Збирача (Builder) ---
# Використовуємо офіційний образ golang з Alpine для компіляції.
# Alpine містить 'make' за замовчуванням.
FROM --platform=$BUILDPLATFORM quay.io/projectquay/golang:1.24 AS builder

# Аргументи, що автоматично надаються 'docker buildx build'
# BUILDPLATFORM: Платформа, на якій фактично виконується цей етап збірки (наприклад, linux/amd64).
# TARGETPLATFORM: Цільова платформа для кінцевого образу (наприклад, linux/amd64, windows/amd64).
# TARGETOS: Операційна система цільової платформи (наприклад, linux, windows).
# TARGETARCH: Архітектура цільової платформи (наприклад, amd64, arm64).
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

# Встановлення робочої директорії всередині контейнера збирача
WORKDIR /app

# Копіювання Makefile, go.mod та go.sum для використання кешу Docker
# Якщо ці файли не змінилися, Docker може пропустити повторне завантаження залежностей.
COPY Makefile ./Makefile
COPY go.mod ./

# Завантаження Go модулів. Цей крок тут допомагає кешуванню Docker.
RUN echo "Завантаження Go модулів в етапі збирача..." && \
    go mod download && \
    go mod verify

# Копіювання решти вихідного коду проекту (включаючи .git, якщо він є в контексті,
# що необхідно для визначення версії у Makefile)
COPY . .

# Виконання цілі Makefile для вказаної TARGETOS/TARGETARCH.
# Makefile визначає цілі у форматі 'linux/amd64', 'windows/arm64' тощо.
RUN echo "Запуск компіляції kbot для ${TARGETOS}/${TARGETARCH} за допомогою Makefile...\n" && \
    echo "Платформа збірки (BUILDPLATFORM): ${BUILDPLATFORM}\n" && \
    echo "Цільова платформа (TARGETPLATFORM): ${TARGETPLATFORM}\n" 

RUN CGO_ENABLE=0 GOOS=$(TARGETOS) GOARCH=$(TARGETARCH) go build -v -o bin/kbot -ldflags "-X="github.dev/DEVOPS101-PROM/kbot/cmd.appVersion=${VERSION}

RUN echo "Компіляцію завершено. Вміст директорії /app/bin/:"
# --- Етап Фінального Образу для Linux ---
# Використовуємо легкий образ Alpine Linux для мінімального розміру фінального образу.
# FROM alpine:3.19 AS final_linux