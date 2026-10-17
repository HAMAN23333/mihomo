"""Exercise deferred DNS errors through a final Lite executable (Python 3)."""
import pathlib
import socket
import struct
import subprocess
import sys
import tempfile
import time

binary = str(pathlib.Path(sys.argv[1]).resolve())
for protocol, label in (("tailscale", "Tailscale"), ("easytier", "EasyTier")):
    with tempfile.TemporaryDirectory() as directory:
        home = pathlib.Path(directory)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        config = home / "config.yaml"
        config.write_text(
            "mode: direct\nlog-level: debug\ndns:\n  enable: true\n"
            f"  listen: 127.0.0.1:{port}\n"
            "  use-hosts: false\n  use-system-hosts: false\n"
            f"  nameserver:\n    - {protocol}://disabled\n"
            "rules: []\n", encoding="utf-8"
        )
        log_path = home / "output.log"
        with log_path.open("w", encoding="utf-8") as output:
            process = subprocess.Popen(
                [binary, "-d", directory, "-f", str(config)],
                stdout=output, stderr=subprocess.STDOUT,
            )
            try:
                # One A query for an uncached test-only name, with recursion requested.
                query = struct.pack("!6H", 0x1234, 0x0100, 1, 0, 0, 0)
                query += b"\x0alite-check\x07invalid\x00\x00\x01\x00\x01"
                deadline = time.monotonic() + 15
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
                    client.settimeout(0.5)
                    while time.monotonic() < deadline:
                        if process.poll() is not None:
                            raise RuntimeError(log_path.read_text(encoding="utf-8"))
                        client.sendto(query, ("127.0.0.1", port))
                        try:
                            response, _ = client.recvfrom(4096)
                        except (socket.timeout, ConnectionResetError):
                            time.sleep(0.1)
                            continue
                        assert response[:2] == b"\x12\x34"
                        assert response[3] & 15 == 2, "expected DNS SERVFAIL"
                        break
                    else:
                        raise RuntimeError("DNS listener did not return an error response")
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        log = log_path.read_text(encoding="utf-8")
        assert f"does not provide {label} DNS" in log, log
        print(f"Deferred {label} DNS reference returned SERVFAIL and a diagnostic")
