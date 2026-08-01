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
    if ! grep -q "OBJS-\$(CONFIG_AASC_DECODER)" libavcodec/Makefile; then echo -e "\e[31mERROR: Anchor OBJS-\$(CONFIG_AASC_DECODER) missing in Makefile\e[0m" >&2; exit 1; fi
    sed -i '/OBJS-$(CONFIG_AASC_DECODER)/a OBJS-$(CONFIG_AC4_DECODER)             += ac4dec.o' libavcodec/Makefile
fi
if ! grep -q "ac4_parser.o" libavcodec/Makefile; then
    if ! grep -q "OBJS-\$(CONFIG_AAC_PARSER)" libavcodec/Makefile; then echo -e "\e[31mERROR: Anchor OBJS-\$(CONFIG_AAC_PARSER) missing in Makefile\e[0m" >&2; exit 1; fi
    sed -i '/OBJS-$(CONFIG_AAC_PARSER)/a OBJS-$(CONFIG_AC4_PARSER)              += ac4_parser.o' libavcodec/Makefile
fi

# libavcodec/allcodecs.c
if ! grep -q "extern const FFCodec ff_ac4_decoder;" libavcodec/allcodecs.c; then
    if ! grep -q "extern const FFCodec ff_ac3_decoder;" libavcodec/allcodecs.c; then echo -e "\e[31mERROR: Anchor ff_ac3_decoder missing in allcodecs.c\e[0m" >&2; exit 1; fi
    sed -i '/extern const FFCodec ff_ac3_decoder;/a extern const FFCodec ff_ac4_decoder;' libavcodec/allcodecs.c
fi

# libavcodec/kbdwin.h
if ! grep -q "#define FF_KBD_WINDOW_MAX 2048" libavcodec/kbdwin.h; then
    if ! grep -q "#define FF_KBD_WINDOW_MAX 1024" libavcodec/kbdwin.h; then echo -e "\e[31mERROR: Anchor FF_KBD_WINDOW_MAX 1024 missing in kbdwin.h\e[0m" >&2; exit 1; fi
    sed -i 's/#define FF_KBD_WINDOW_MAX 1024/#define FF_KBD_WINDOW_MAX 2048/' libavcodec/kbdwin.h
fi

# libavcodec/parsers.c
if ! grep -q "extern const FFCodecParser ff_ac4_parser;" libavcodec/parsers.c; then
    if ! grep -q "extern const FFCodecParser ff_ac3_parser;" libavcodec/parsers.c; then echo -e "\e[31mERROR: Anchor ff_ac3_parser missing in parsers.c\e[0m" >&2; exit 1; fi
    sed -i '/extern const FFCodecParser ff_ac3_parser;/a extern const FFCodecParser ff_ac4_parser;' libavcodec/parsers.c
fi

# DVB Extension Descriptor parsing for ATSC 3.0 AC-4 streams
if ! grep -q "AC4_DESCRIPTOR_TAG_EXTENSION" libavformat/mpegts.h; then
    if ! grep -q "JXS_VIDEO_DESCRIPTOR" libavformat/mpegts.h; then echo -e "\e[31mERROR: Anchor JXS_VIDEO_DESCRIPTOR missing in mpegts.h\e[0m" >&2; exit 1; fi
    sed -i '/JXS_VIDEO_DESCRIPTOR/a #define AC4_DESCRIPTOR_TAG_EXTENSION 0x15' libavformat/mpegts.h
fi

if ! grep -q "AC4_DESCRIPTOR 0x15" libavformat/mpegts.h; then
    if ! grep -q "SUPPLEMENTARY_AUDIO_DESCRIPTOR" libavformat/mpegts.h; then echo -e "\e[31mERROR: Anchor SUPPLEMENTARY_AUDIO_DESCRIPTOR missing in mpegts.h\e[0m" >&2; exit 1; fi
    sed -i '/SUPPLEMENTARY_AUDIO_DESCRIPTOR/a #define AC4_DESCRIPTOR 0x15' libavformat/mpegts.h
fi

if ! grep -q "ext_desc_tag == AC4_DESCRIPTOR_TAG_EXTENSION" libavformat/mpegts.c; then
    if ! grep -q "if (ext_desc_tag < 0)" libavformat/mpegts.c; then echo -e "\e[31mERROR: Anchor if (ext_desc_tag < 0) missing in mpegts.c\e[0m" >&2; exit 1; fi
    sed -i '/if (ext_desc_tag < 0)/{
n
a\
        if (st->codecpar->codec_id == AV_CODEC_ID_BIN_DATA &&\
            ext_desc_tag == AC4_DESCRIPTOR_TAG_EXTENSION) {\
            st->codecpar->codec_type = AVMEDIA_TYPE_AUDIO;\
            st->codecpar->codec_id = AV_CODEC_ID_AC4;\
        }
    }' libavformat/mpegts.c
fi

echo "Staging files..."
git add libavcodec/ac4dec.c libavcodec/ac4dec_data.h libavcodec/ac4_parser.c
git add libavcodec/Makefile libavcodec/allcodecs.c libavcodec/kbdwin.h libavcodec/parsers.c libavformat/mpegts.c libavformat/mpegts.h

if ! git diff --cached --quiet; then
    git commit -m "ffmpeg: Inject AC-4 decoder from librempeg"
fi
echo "AC-4 injection complete."
