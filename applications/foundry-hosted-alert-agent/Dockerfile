FROM python:3.13-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8088

WORKDIR /app
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt \
    && python -m pip check \
    && groupadd --gid 10001 agent \
    && useradd --uid 10001 --gid agent --create-home agent

COPY --chown=agent:agent main.py ./
USER agent
EXPOSE 8088
CMD ["python", "main.py"]
