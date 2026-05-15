from functools import lru_cache
from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = Field(default="mediguide-ai-worker", validation_alias=AliasChoices("APP_NAME"))
    env: str = Field(default="development", validation_alias=AliasChoices("APP_ENV", "ENV"))
    log_level: str = "INFO"
    api_host: str = "0.0.0.0"
    api_port: int = Field(default=8090, validation_alias=AliasChoices("API_PORT", "HTTP_PORT"))

    database_url: str = Field(
        default="postgresql://mediguide:mediguide@localhost:5432/mediguide",
        validation_alias=AliasChoices("DATABASE_URL"),
    )
    redis_url: str = Field(default="redis://localhost:6379", validation_alias=AliasChoices("REDIS_URL"))

    minio_endpoint: str = Field(
        default="localhost:9000",
        validation_alias=AliasChoices("MINIO_ENDPOINT", "S3_ENDPOINT"),
    )
    minio_access_key: str = Field(
        default="mediguide",
        validation_alias=AliasChoices("MINIO_ACCESS_KEY", "S3_ACCESS_KEY"),
    )
    minio_secret_key: str = Field(
        default="mediguide123",
        validation_alias=AliasChoices("MINIO_SECRET_KEY", "S3_SECRET_KEY"),
    )
    minio_bucket: str = Field(
        default="mediguide",
        validation_alias=AliasChoices("MINIO_BUCKET", "S3_BUCKET"),
    )
    minio_secure: bool = Field(
        default=False,
        validation_alias=AliasChoices("MINIO_SECURE", "S3_USE_SSL"),
    )

    worker_enabled: bool = True
    worker_poll_interval_seconds: int = 5
    worker_batch_size: int = 2

    chunk_size: int = 900
    chunk_overlap: int = 160
    min_chunk_chars: int = 120

    embedding_provider: str = "ollama"  # hash, sentence_transformers, openai, ollama
    embedding_model: str = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
    embedding_dim: int = 1024
    openai_api_key: str | None = None
    openai_embedding_model: str = Field(
        default="text-embedding-3-small",
        validation_alias=AliasChoices("OPENAI_EMBEDDING_MODEL"),
    )

    llm_provider: str = "extractive"  # extractive, ollama, openai
    openai_chat_model: str = "gpt-4o-mini"
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "qwen2.5:7b-instruct"
    ollama_embedding_model: str = Field(
        default="mxbai-embed-large:latest",
        validation_alias=AliasChoices("OLLAMA_EMBEDDING_MODEL"),
    )

    rag_top_k: int = 6
    rag_min_similarity: float = 0.15
    rag_national_first: bool = True


@lru_cache
def get_settings() -> Settings:
    return Settings()
