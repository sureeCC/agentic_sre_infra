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
        # The cloud builder may read files as a different Unix user.
        info.create_system = 3
        info.external_attr = 0o100644 << 16
        info.compress_type = ZIP_DEFLATED
        archive.writestr(info, content)

# Fail locally if an upload would omit the remote-build dependency manifest.
with ZipFile("dist/agent.zip") as archive:
    assert set(archive.namelist()) == {"main.py", "requirements.txt"}
    assert archive.read("requirements.txt").strip(), "Empty dependency manifest"
    assert archive.testzip() is None, "Corrupt source archive"
    for info in archive.infolist():
        assert (info.external_attr >> 16) & 0o444 == 0o444
    print("Verified source ZIP: main.py and requirements.txt at root, Unix mode 0644")
