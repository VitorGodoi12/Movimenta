FROM python:3.13-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN groupadd --system stokio && useradd --system --gid stokio stokio && mkdir /dados && chown stokio:stokio /dados
COPY stokio.py catalogo_inicial.json ./
USER stokio
CMD ["python", "stokio.py"]
