#!/usr/bin/env bash
set -euo pipefail

ARQUIVO_FONTES="${1:-$HOME/enderecos_canais.txt}"
ARQUIVO_PLAYLIST="${2:-$HOME/playlist.m3u}"
INTERVALO="${INTERVALO:-21600}"
FORMATO_AUDIO="${FORMATO_AUDIO:-ba[language=pt-BR]/ba}"
MODO="${3:-}"

resolver_video() {
  local src="$1"
  local out=""

  if [[ "$src" == *"youtube.com/watch"* || "$src" == *"youtu.be/"* ]]; then
    printf '%s\n' "$src"
    return 0
  fi

  if [[ "$src" == *"playlist?list="* || "$src" == */videos || "$src" == */streams || "$src" == */shorts ]]; then
    yt-dlp --flat-playlist --playlist-items 1 --print "%(webpage_url)s" "$src" 2>/dev/null | head -n1
    return 0
  fi

  out=$(yt-dlp --flat-playlist --playlist-items 1 --print "%(webpage_url)s" "${src%/}/videos" 2>/dev/null | head -n1 || true)
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out"
    return 0
  fi

  out=$(yt-dlp --flat-playlist --playlist-items 1 --print "%(webpage_url)s" "${src%/}/streams" 2>/dev/null | head -n1 || true)
  printf '%s\n' "$out"
}

gerar_playlist() {
  local tmp="${ARQUIVO_PLAYLIST}.tmp"
  local src video_url meta dur titulo stream_url

  printf '#EXTM3U\n' > "$tmp"
  printf '# gerada em %s\n\n' "$(date '+%F %T %z')" >> "$tmp"

  while IFS= read -r src || [[ -n "$src" ]]; do
    src="${src%$'\r'}"
    [[ -z "$src" ]] && continue
    [[ "$src" =~ ^[[:space:]]*# ]] && continue

    echo "Processando: $src" >&2

    video_url="$(resolver_video "$src")"
    if [[ -z "$video_url" ]]; then
      echo "  aviso: nao consegui resolver o ultimo video" >&2
      continue
    fi

    meta="$(yt-dlp --print "%(duration)s\t%(title)s" "$video_url" 2>/dev/null | head -n1 || true)"
    dur="${meta%%$'\t'*}"
    titulo="${meta#*$'\t'}"

    [[ -z "$dur" || "$dur" == "$meta" ]] && dur="-1"
    [[ -z "$titulo" ]] && titulo="$video_url"

    stream_url="$(yt-dlp -g -f "$FORMATO_AUDIO" "$video_url" 2>/dev/null | head -n1 || true)"
    if [[ -z "$stream_url" ]]; then
      echo "  aviso: nao consegui extrair stream de audio" >&2
      continue
    fi

    printf '#EXTINF:%s,%s\n%s\n\n' "$dur" "$titulo" "$stream_url" >> "$tmp"
    echo "  ok: $titulo" >&2
  done < "$ARQUIVO_FONTES"

  mv "$tmp" "$ARQUIVO_PLAYLIST"
  echo "Playlist atualizada: $ARQUIVO_PLAYLIST" >&2
}

if [[ "$MODO" == "--once" ]]; then
  gerar_playlist
  exit 0
fi

while true; do
  gerar_playlist
  echo "Dormindo por $INTERVALO segundos..." >&2
  sleep "$INTERVALO"
done
