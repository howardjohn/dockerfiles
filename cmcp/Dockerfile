FROM python:3.12-slim-bookworm
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
ENV PATH=/root/.local/bin:$PATH
RUN uv tool install cmcp
ENTRYPOINT cmcp
