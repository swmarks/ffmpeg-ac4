#!/bin/bash
set -e

echo "Downloading AC-4 DSP files from librempeg..."
curl -sL https://raw.githubusercontent.com/librempeg/librempeg/master/libavcodec/ac4dec.c > libavcodec/ac4dec.c
curl -sL https://raw.githubusercontent.com/librempeg/librempeg/master/libavcodec/ac4dec_data.h > libavcodec/ac4dec_data.h
curl -sL https://raw.githubusercontent.com/librempeg/librempeg/master/libavcodec/ac4_parser.c > libavcodec/ac4_parser.c

echo "Applying custom DSP edits..."
git apply custom-edits.patch

echo "Applying FFmpeg static glue..."

# libavcodec/Makefile
if ! grep -q "ac4dec.o" libavcodec/Makefile; then
    sed -i '/OBJS-$(CONFIG_AC3_DECODER)/a OBJS-$(CONFIG_AC4_DECODER)             += ac4dec.o' libavcodec/Makefile
fi
if ! grep -q "ac4_parser.o" libavcodec/Makefile; then
    sed -i '/OBJS-$(CONFIG_AC3_PARSER)/a OBJS-$(CONFIG_AC4_PARSER)              += ac4_parser.o' libavcodec/Makefile
fi

# libavcodec/allcodecs.c
if ! grep -q "&ff_ac4_decoder" libavcodec/allcodecs.c; then
    sed -i '/&ff_ac3_decoder/a \    extern const FFCodec ff_ac4_decoder;' libavcodec/allcodecs.c
fi

# libavcodec/kbdwin.h
if ! grep -q "av_cold void ff_kbd_window_init" libavcodec/kbdwin.h; then
    sed -i 's/void ff_kbd_window_init/av_cold void ff_kbd_window_init/' libavcodec/kbdwin.h
fi

# libavcodec/parsers.c
if ! grep -q "&ff_ac4_parser" libavcodec/parsers.c; then
    sed -i '/&ff_ac3_parser/a \    extern const AVCodecParser ff_ac4_parser;' libavcodec/parsers.c
fi

# libavformat/mpegts.c
if ! grep -q "AV_CODEC_ID_AC4.*ATSC 3.0" libavformat/mpegts.c; then
    sed -i '/{ 0xac, AVMEDIA_TYPE_AUDIO, AV_CODEC_ID_AC3 }/a \    { 0xae, AVMEDIA_TYPE_AUDIO, AV_CODEC_ID_AC4 }, /* ATSC 3.0 */' libavformat/mpegts.c
fi
if ! grep -q "ac-4.*AVMEDIA_TYPE_AUDIO" libavformat/mpegts.c; then
    sed -i '/MKTAG('\''a'\'', '\''c'\'', '\''-'\'', '\''3'\'')/a \    { MKTAG('\''a'\'', '\''c'\'', '\''-'\'', '\''4'\''), AVMEDIA_TYPE_AUDIO, AV_CODEC_ID_AC4 },' libavformat/mpegts.c
    sed -i '/MKTAG('\''A'\'', '\''C'\'', '\''-'\'', '\''3'\'')/a \    { MKTAG('\''A'\'', '\''C'\'', '\''-'\'', '\''4'\''), AVMEDIA_TYPE_AUDIO, AV_CODEC_ID_AC4 },' libavformat/mpegts.c
fi

echo "Staging files..."
git add libavcodec/ac4dec.c libavcodec/ac4dec_data.h libavcodec/ac4_parser.c
git add libavcodec/Makefile libavcodec/allcodecs.c libavcodec/kbdwin.h libavcodec/parsers.c libavformat/mpegts.c

if ! git diff --cached --quiet; then
    git commit -m "ffmpeg: Inject AC-4 decoder from librempeg"
fi
echo "AC-4 injection complete."
