ffmpeg -hwaccel vaapi -vaapi_device /dev/dri/renderD128 \
    -i "$1" \
    -vf 'format=nv12,hwupload' \
    -c:v hevc_vaapi -qp 22 -ac 2 \
    -c:a aac -b:a 192k \
    -y "encode-$1"

