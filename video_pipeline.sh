#!/usr/bin/env bash
#
# Автоматизация рутинных операций с ffmpeg.
# Скрипт создаёт списки для конкатенации, копирует файлы,
# выполняет последовательную сборку и извлекает субтитры.
#
# Требования:
#   - bash
#   - ffmpeg
#   - достаточное дисковое пространство
#
# Использование:
#   ./video_pipeline.sh iterate 3     # выполнить процедуры для i=3
#   ./video_pipeline.sh list 4        # создать list4.txt
#   ./video_pipeline.sh copy 5        # long5.mkv → long5-copy.mkv
#   ./video_pipeline.sh concat 6      # list6.txt → long7.mkv
#   ./video_pipeline.sh subs 7        # long7.mkv → subs7.vtt
#

set -e

#############################################
# (1) Создание списочного файла list{i}.txt #
#############################################
make_list() {
    local i="$1"
    local file="list${i}.txt"

    echo "file 'long${i}.mkv'"       >  "$file"
    echo "file 'long${i}-copy.mkv'" >> "$file"

    echo "Создан $file"
}

make_audio_list() {
    local i="$1"
    local file="audio_list${i}.txt"

    echo "file 'long${i}.wav'"       >  "$file"
    echo "file 'long${i}-copy.wav'" >> "$file"

    echo "Создан $file"
}

#############################################
# (2) Копирование long{i}.mkv → long{i}-copy.mkv
#############################################
make_copy() {
    local i="$1"
    local src="long${i}.mkv"
    local dst="long${i}-copy.mkv"

    if [[ ! -f "$src" ]]; then
        echo "Файл $src отсутствует."
        exit 1
    fi

    cp -f "$src" "$dst"
    echo "Скопирован $src → $dst"
}

make_audio_copy() {
    local i="$1"
    local src="long${i}.wav"
    local dst="long${i}-copy.wav"

    if [[ ! -f "$src" ]]; then
        echo "Файл $src отсутствует."
        exit 1
    fi

    cp -f "$src" "$dst"
    echo "Скопирован $src → $dst"
}
#############################################
# (3) Конкатенация списка list{i}.txt → long{i+1}.mkv
#############################################
make_concat() {
    local i="$1"
    local list="list${i}.txt"
    local out="long$((i+1)).mkv"

    if [[ ! -f "$list" ]]; then
        echo "Нет файла $list"
        exit 1
    fi
    #ffmpeg -hwaccel vaapi -vaapi_device /dev/dri/renderD128 \
    #    -f concat -safe 0 -i "$list" \
    #    -vf 'format=nv12,hwupload' \
    #    -c:v hevc_vaapi -qp 22 -ac 2 -c:a aac -b:a 192k \
    #    -y "$out"

    ffmpeg -f concat -safe 0 -i "$list" -c copy -y "$out"
    echo "Создан $out"
}

make_audio_concat() {
    local i="$1"
    local list="audio_list${i}.txt"
    local out="long$((i+1)).wav"

    if [[ ! -f "$list" ]]; then
        echo "Нет файла $list"
        exit 1
    fi

    ffmpeg -f concat -safe 0 -i "$list" -c copy -y "$out"
    echo "Создан $out"
}

cpu_video_concat() {
    local i="$1"
    local out="long$((i+1)).mkv"

    ffmpeg -i long${i}.mkv -i long${i}-copy.mkv \
      -filter_complex "
          /* Видеопотоки */
          [0:v]fps=30,format=yuv420p[v0];
          [1:v]fps=30,format=yuv420p[v1];
          
          /* Аудиопотоки */
          [0:a]aresample=48000[a0];
          [1:a]aresample=48000[a1];
          
          /* Выбираем потоки субтитров из каждого файла ([0:s:0] и [1:s:0]) */
          [0:s:0][1:s:0]concat=n=2:v=0:a=0:s=1[s_out];
          
          /* Объединение видео и аудио */
          [v0][a0][v1][a1]concat=n=2:v=1:a=1[v_out][a_out]
      " \
      -map "[v_out]" -map "[a_out]" -map "[s_out]" \
      -c:v libx264 -preset ultrafast -crf 10 \
      -c:a pcm_s16le \
      -y "$out"

    echo "Создан $out"
}

#############################################
# (4) Извлечение субтитров из long{i}.mkv
#############################################
extract_subs() {
    local i="$1"
    local in="long${i}.mkv"
    local out="subs${i}.vtt"

    ffmpeg -i "$in" -map 0:s:0 -y "$out"
    echo "Субтитры извлечены: $out"
}

#############################################
# (5) Полный цикл: copy → list → concat
#############################################
iterate() {
    local i="$1"

    make_copy "$i"
    make_list "$i"
    cpu_concat "$i"

    echo "Итерация завершена: long$((i+1)).mkv готов."
}

iterate_audio() {
    local i="$1"

    make_audio_copy "$i"
    make_audio_list "$i"
    make_audio_concat "$i"

    echo "Итерация Аудио завершена: long$((i+1)).wav готов."
}

cpu_iterate() {
    local i="$1"

    make_copy "$i"
    make_list "$i"
    cpu_video_concat "$i"

    echo "Итерация завершена: long$((i+1)).mkv готов."
}

#############################################
# Точка входа
#############################################
case "$1" in
    list)    make_list "$2" ;;
    copy)    make_copy "$2" ;;
    concat)  make_concat "$2" ;;
    cpu_concat) cpu_concat "$2" ;;
    subs)    extract_subs "$2" ;;
    iterate) iterate "$2" ;;
    cpu_iterate) cpu_iterate "$2" ;;
    iterate_audio) iterate_audio "$2" ;;
    *)
        echo "Команды:"
        echo "  list i      — создать list{i}.txt"
        echo "  copy i      — long{i}.mkv → long{i}-copy.mkv"
        echo "  concat i    — объединить в long{i+1}.mkv"
        echo "  subs i      — извлечь субтитры"
        echo "  iterate i   — выполнить copy+list+concat"
        echo "  cpu_iterate i   — выполнить copy+list+cpu_concat"
        exit 1
        ;;
esac

