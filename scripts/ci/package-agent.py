"""Create a flat, deterministic source ZIP; exclude settings and test payloads."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

source = Path("applications/foundry-hosted-alert-agent")
Path("dist").mkdir(exist_ok=True)
with ZipFile("dist/agent.zip", "w", compression=ZIP_DEFLATED) as archive:
    for name in ("main.py", "requirements.txt"):
        content = (source / name).read_bytes()
        if name.endswith(".py"):
            compile(content, name, "exec")
        info = ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
        info.compress_type = ZIP_DEFLATED
        archive.writestr(info, content)
