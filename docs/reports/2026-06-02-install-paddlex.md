# 2026-06-02 Install PaddleX on osm45 (docker-prod-2)

To anonymize receipt on Open Prices, we chose to detect personal information using a LVLM (large visual language model), as these model provide very performant and context-aware PII detection. However, LVLMs are still not very good at localizing exactly where the PII is located on the image.
We chose the following approach:

1. Use a LVLM to detect PII (as text) on the image
2. Use a PaddleX model to perform OCR and get each word's bounding box coordinates.
3. Localize the PII on the image using the bounding box coordinates.

Not many open source solution exist to perform traditional OCR: Tesseract and PaddleOCR.

We chose PaddleOCR, as it provides better performance out of the box than Tesseract.

We need an inference service to run PaddleOCR. The recommended way is to use PaddleX, Baidu inference service.

## Creating the docker image

Baidu provides a [PaddleX docker image](https://paddlepaddle.github.io/PaddleX/latest/en/installation/installation.html#21-get-paddlex-via-docker) for CPU or GPU, available on their own Docker registry.
We first pull it (CPU version here):

```bash
docker pull ccr-2vdh3abv-pub.cnc.bj.baidubce.com/paddlex/paddlex:paddlex3.3.11-paddlepaddle3.2.0-cpu
```

We then need to modify the image to add the PaddleX serving plugin. First, launch the container:

```bash
docker run --name paddlex-install -it ccr-2vdh3abv-pub.cnc.bj.baidubce.com/paddlex/paddlex:paddlex3.3.11-paddlepaddle3.2.0-cpu /bin/bash
```

Then run:

```
paddlex --install serving
```

Exit the container (`exit`), and commit the changes to the image, under the name `openfoodfacts/paddlex-ocr`:

```bash
docker commit paddlex-install openfoodfacts/paddlex-ocr:paddlex3.3.11-paddlepaddle3.2.0-cpu
```

You can then push the image to the Docker registry:

```bash
docker push openfoodfacts/paddlex-ocr:paddlex3.3.11-paddlepaddle3.2.0-cpu
```

You can then pull and run the image:

```bash
docker run -v paddlex-models:/root/.paddlex/official_models --shm-size=8g -it paddlex:paddlex3.3.11-paddlepaddle3.2.0-cpu /bin/bash
```


## Deploying on docker-prod-2

In `/home/off`, a `paddlex` symlink was created to `/opt/openfoodfacts-infrastructure/docker/paddlex`.
Then, `docker compose up -d` was run to start the service.
