import modal

# Phase B2: Modal Image Definition
# ล็อค dependencies เพื่อป้องกัน drift และลดเวลา build
bl1nk_image = (
    modal.Image.debian_slim()
    .apt_install("sqlite3", "libsqlite3-dev")
    .pip_install(
        "pyyaml",
        "requests",
        "pydantic",
        "python-dotenv",
        "fastapi",
    )
    .run_commands("mkdir -p /data")
)

if __name__ == "__main__":
    print("bl1nk base image definition loaded.")
