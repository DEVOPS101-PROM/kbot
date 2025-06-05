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

COPY go.mod go.sum ./

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

RUN CGO_ENABLED=0 GOOS=$(TARGETOS) GOARCH=$(TARGETARCH) go build -a -v -o bin/kbot -ldflags "-X 'github.dev/DEVOPS101-PROM/kbot/cmd.appVersion=${VERSION}' -extldflags '-static'" 

RUN echo "Компіляцію завершено. Вміст директорії /app/bin/:"
# --- Етап Фінального Образу для Linux ---
# Використовуємо легкий образ Alpine Linux для мінімального розміру фінального образу.
# FROM alpine:3.19 AS final_linux

FROM scratch AS  final_linux
# Аргумент TARGETOS потрібен для умовного виконання (хоча buildx обробляє вибір шляху)
ARG TARGETOS

# Встановлення робочої директорії
WORKDIR /app

# Копіювання скомпільованого бінарного файлу 'kbot' з етапу збирача.
# Makefile створює 'bin/kbot' для Linux.
COPY --from=builder /app/bin/kbot .
COPY --from=builder /etc/ssl/certs/* /etc/ssl/certs/
# Надання прав на виконання бінарному файлу
# RUN chmod +x kbot

# Встановлення точки входу для запуску бота
ENTRYPOINT ["/app/kbot"]

FROM scratch AS  final_darwin
# Аргумент TARGETOS потрібен для умовного виконання (хоча buildx обробляє вибір шляху)
ARG TARGETOS

# Встановлення робочої директорії
WORKDIR /

# Копіювання скомпільованого бінарного файлу 'kbot' з етапу збирача.
# Makefile створює 'bin/kbot' для Linux.
COPY --from=builder /app/bin/kbot .
COPY --from=builder /etc/ssl/certs/* /etc/ssl/certs/
# Надання прав на виконання бінарному файлу
# RUN chmod +x kbot

# Встановлення точки входу для запуску бота
ENTRYPOINT ["./kbot"]
# --- Етап Фінального Образу для Windows ---
# Використовуємо образ Windows Nano Server.
# Цей етап буде ефективно використаний, якщо ви збираєте для платформи Windows
# (наприклад, --platform windows/amd64).
# Для цього може знадобитися Docker Desktop у режимі Windows containers або Windows build-агент.
FROM mcr.microsoft.com/windows/nanoserver:ltsc2022 AS final_windows

# Аргумент TARGETOS потрібен для умовного виконання
ARG TARGETOS

# Встановлення робочої директорії
WORKDIR /app/

# Копіювання скомпільованого бінарного файлу 'kbot.exe' з етапу збирача.
# Ваш Makefile створює 'bin/kbot.exe' для Windows.
COPY --from=builder /app/bin/kbot.exe .

# Встановлення точки входу для запуску бота
ENTRYPOINT ["./kbot.exe"]

# --- Етап Вибору (Selector Stage) ---
# Цей етап використовує значення TARGETOS (встановлене 'docker buildx build --platform ...')
# для вибору правильного фінального образу (final_linux або final_windows).
# Наприклад, якщо TARGETO="linux", цей етап стає еквівалентним 'FROM final_linux'.
FROM final_${TARGETOS} AS final

# У цьому фінальному етапі 'final' більше нічого не потрібно,
# оскільки він просто пере-тегує вибраний OS-специфічний етап.
# Користувач буде використовувати образ, зібраний з цього етапу 'final'.
