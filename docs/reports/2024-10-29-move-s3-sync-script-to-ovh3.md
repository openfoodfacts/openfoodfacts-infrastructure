# 2024-10-29 Move S3 sync script to OVH3

The script used to synchronize images to AWS S3 (through AWS S3 Open Dataset program) was run on off2 server.
This server is overloaded (due to I/O), so we now run this script on the OVH3 server (that has a replicate of images through Sanoid snapshots).

OVH3 server has Python 3.7, and the script requires at least Python 3.9. I wanted to install pyenv using the off user, but I didn't manage to get pyenv working with dash, which is the default shell for off user.

As a result, I install [uv](https://docs.astral.sh/uv/) on ovh3 as a replacement, for `off` user:


```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

`uv` is installed automatically in `/home/off/.cargo/bin/uv`.

Install Python 3.11:

```bash
uv python install 3.11
```

I moved S3 synchronization script to openfood facts infra repository, in the `scripts` directory ([commit](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/42dd4fcdb1f52d55767f33136bc94a6590fa4fd8)).

Note that Python version and dependencies can be directly declared at the top of the Python script, as comment:

```python
# /// script
# dependencies = [
# "openfoodfacts==1.1.5",
# "orjson==3.10.7",
# "boto3==1.35.32",
# "tqdm==4.66.5",
# ]
# requires-python = ">=3.9"
# ///
```

I also copied the aws credentials in `~/.aws/credentials` on ovh3 server (`off` user).

when launching the script with `uv run sync_s3_images.py`, `uv` automatically creates a virtualenv if needed, install the dependencies and run the script in the virtual environment.

I installed the systemd service and timer on ovh3, and disabled the systemd service/timer on off2 server.