FROM python:3.12-slim-bookworm
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
RUN --mount=type=bind,source=/uv,from=ghcr.io/astral-sh/uv:latest,target=/bin/uv \
    /bin/uv pip install cmcp --system --no-cache
ENTRYPOINT ["cmcp"]
