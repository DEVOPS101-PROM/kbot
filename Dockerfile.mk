FROM scratch AS  final_linux
# Аргумент TARGETOS потрібен для умовного виконання (хоча buildx обробляє вибір шляху)
ARG TARGETOS
ARG TARGETARCH

# Встановлення робочої директорії
WORKDIR /

# Копіювання скомпільованого бінарного файлу 'kbot' з етапу збирача.
# Makefile створює 'bin/kbot' для Linux.

COPY bin/kbot-${TARGETOS}-${TARGETARCH} ./kbot
COPY --from=alpine:latest /etc/ssl/certs/* /etc/ssl/certs/
# Надання прав на виконання бінарному файлу
# RUN chmod +x kbot

# Встановлення точки входу для запуску бота
ENTRYPOINT ["./kbot"]
