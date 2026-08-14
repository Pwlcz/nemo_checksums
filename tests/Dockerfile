# Run it from the root of the project with:
# docker build -t nemo-checks-tests -f tests/Dockerfile .
# docker run --rm -v "$(pwd):/app" nemo-checks-tests
FROM debian:stable-slim

 RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bats \
    gawk \
    coreutils \
    gettext \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["bats", "./tests"]