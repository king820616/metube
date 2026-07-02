#!/bin/sh

PUID="${UID:-$PUID}"
PGID="${GID:-$PGID}"
AUDIO_DOWNLOAD_DIR="${AUDIO_DOWNLOAD_DIR:-$DOWNLOAD_DIR}"
COOKIES_DIR="${COOKIES_DIR:-/cookies}"

echo "Setting umask to ${UMASK}"
umask ${UMASK}
echo "Creating download directory (${DOWNLOAD_DIR}), audio download directory (${AUDIO_DOWNLOAD_DIR}), state directory (${STATE_DIR}), temp dir (${TEMP_DIR}), and cookies directory (${COOKIES_DIR})"
mkdir -p "${DOWNLOAD_DIR}" "${AUDIO_DOWNLOAD_DIR}" "${STATE_DIR}" "${TEMP_DIR}" "${COOKIES_DIR}"

do_upgrade() {
    echo "Upgrading yt-dlp to nightly channel..."
    if ! python3 -m pip --version >/dev/null 2>&1; then
        echo "pip not found; attempting ensurepip"
        python3 -m ensurepip --upgrade >/dev/null 2>&1 || true
    fi
    if ! python3 -m pip install -U --pre "yt-dlp[default,curl-cffi,deno]"; then
        echo "Warning: yt-dlp nightly upgrade failed; continuing with existing installation"
        return 1
    fi
    echo "yt-dlp nightly upgrade complete"
    return 0
}

run_supervised() {
    while true; do
        "$@" &
        child_pid=$!
        trap 'kill -TERM "$child_pid" 2>/dev/null; wait "$child_pid" 2>/dev/null' TERM INT
        wait "$child_pid"
        exit_code=$?
        trap - TERM INT
        if [ "$exit_code" -eq 42 ]; then
            echo "MeTube requested yt-dlp update restart (exit 42)"
            do_upgrade || true
            continue
        fi
        return "$exit_code"
    done
}

nightly_enabled() {
    [ -n "${YTDL_NIGHTLY_UPDATE_TIME}" ]
}

disable_nightly_for_non_root() {
    if nightly_enabled; then
        echo "YTDL_NIGHTLY_UPDATE_TIME is set but this container runs as a non-root user; nightly yt-dlp updates are not supported. Ignoring YTDL_NIGHTLY_UPDATE_TIME."
        unset YTDL_NIGHTLY_UPDATE_TIME
    fi
}

start_bgutil_pot_provider() {
    echo "Starting BgUtils POT Provider"
    "$@" >/tmp/bgutil-pot.log 2>&1 &
    bgutil_pid=$!
    for _ in 1 2 3 4 5; do
        if curl -fsS http://127.0.0.1:4416/ping >/dev/null 2>&1; then
            echo "BgUtils POT Provider is ready"
            return 0
        fi
        if ! kill -0 "$bgutil_pid" 2>/dev/null; then
            echo "Warning: BgUtils POT Provider exited early; see /tmp/bgutil-pot.log"
            return 1
        fi
        sleep 1
    done
    echo "Warning: BgUtils POT Provider did not become ready within 5 seconds; continuing"
    return 1
}

if [ `id -u` -eq 0 ] && [ `id -g` -eq 0 ]; then
    if [ "${PUID}" -eq 0 ]; then
        echo "Warning: it is not recommended to run as root user, please check your setting of the PUID/PGID (or legacy UID/GID) environment variables"
    fi
    if [ "${CHOWN_DIRS:-true}" != "false" ]; then
        echo "Changing ownership of download and state directories to ${PUID}:${PGID}"
        chown -R "${PUID}":"${PGID}" /app "${DOWNLOAD_DIR}" "${AUDIO_DOWNLOAD_DIR}" "${STATE_DIR}" "${TEMP_DIR}" "${COOKIES_DIR}"
    fi
    if nightly_enabled; then
        echo "YTDL_NIGHTLY_UPDATE_TIME is set to ${YTDL_NIGHTLY_UPDATE_TIME}; upgrading yt-dlp on startup"
        do_upgrade || true
    fi
    start_bgutil_pot_provider gosu "${PUID}":"${PGID}" bgutil-pot server --host 127.0.0.1 --port 4416 || true
    echo "Running MeTube as user ${PUID}:${PGID}"
    run_supervised gosu "${PUID}":"${PGID}" python3 app/main.py
    exit $?
else
    echo "User set by docker; running MeTube as `id -u`:`id -g`"
    disable_nightly_for_non_root
    start_bgutil_pot_provider bgutil-pot server --host 127.0.0.1 --port 4416 || true
    run_supervised python3 app/main.py
    exit $?
fi
