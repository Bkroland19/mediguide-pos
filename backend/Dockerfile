FROM golang:1.25-alpine AS build
ARG BUILD_VERSION=development
ARG BUILD_REVISION=unknown
WORKDIR /src
RUN apk add --no-cache git ca-certificates
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags "-X mediguide/internal/buildinfo.Version=${BUILD_VERSION} -X mediguide/internal/buildinfo.Revision=${BUILD_REVISION}" \
    -o /out/api ./cmd/api
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/migrate ./cmd/migrate
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/seed ./cmd/seed

FROM alpine:3.20
ARG BUILD_VERSION=development
ARG BUILD_REVISION=unknown
LABEL org.opencontainers.image.title="MediGuide Backend API" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.revision="${BUILD_REVISION}"
WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata curl
COPY --from=build /out/api /app/api
COPY --from=build /out/migrate /app/migrate
COPY --from=build /out/seed /app/seed
COPY migrations /app/migrations
COPY docs /app/docs
EXPOSE 8080
CMD ["sh", "-c", "/app/migrate up && /app/api"]
