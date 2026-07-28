#import "NeoOpusDecoder.h"
#include <ogg/ogg.h>
#include <opus/opus.h>

#define SAMPLE_RATE 48000
#define MAX_FRAME_SIZE (960 * 6)
#define CHANNELS 1

// WAV file header structs
typedef struct {
    char  chunkID[4];    // "RIFF"
    UInt32 chunkSize;
    char  format[4];     // "WAVE"
} WAVHeader;

typedef struct {
    char  subchunk1ID[4]; // "fmt "
    UInt32 subchunk1Size;
    UInt16 audioFormat;
    UInt16 numChannels;
    UInt32 sampleRate;
    UInt32 byteRate;
    UInt16 blockAlign;
    UInt16 bitsPerSample;
} WAVFmtHeader;

typedef struct {
    char  subchunk2ID[4]; // "data"
    UInt32 subchunk2Size;
} WAVDataHeader;

@implementation NeoOpusDecoder

+ (NSData *)decodeOggOpusToWAV:(NSData *)oggData {
    if ([oggData length] == 0) return nil;

    const unsigned char *data = (const unsigned char *)[oggData bytes];
    size_t dataLen = [oggData length];

    // Ogg sync/stream state
    ogg_sync_state syncState;
    ogg_stream_state streamState;
    ogg_page page;
    ogg_packet packet;

    ogg_sync_init(&syncState);
    memset(&streamState, 0, sizeof(streamState));
    BOOL streamInited = NO;
    BOOL gotHeader = NO;
    BOOL gotComments = NO;

    // Opus decoder
    OpusDecoder *opusDec = NULL;
    int opusErr = 0;
    opusDec = opus_decoder_create(SAMPLE_RATE, CHANNELS, &opusErr);
    if (opusErr != OPUS_OK) {
        ogg_sync_clear(&syncState);
        return nil;
    }

    // PCM output buffer
    NSMutableData *pcmData = [NSMutableData data];
    opus_int16 pcmOut[MAX_FRAME_SIZE * CHANNELS];

    size_t offset = 0;
    while (offset < dataLen) {
        // Feed data to Ogg sync
        size_t bytesToFeed = MIN(dataLen - offset, 4096);
        char *buffer = ogg_sync_buffer(&syncState, (long)bytesToFeed);
        memcpy(buffer, data + offset, bytesToFeed);
        ogg_sync_wrote(&syncState, (long)bytesToFeed);
        offset += bytesToFeed;

        // Get pages
        while (ogg_sync_pageout(&syncState, &page) == 1) {
            if (!streamInited) {
                ogg_stream_init(&streamState, ogg_page_serialno(&page));
                streamInited = YES;
            }

            ogg_stream_pagein(&streamState, &page);

            // Get packets from page
            while (ogg_stream_packetout(&streamState, &packet) == 1) {
                if (!gotHeader) {
                    // First packet is the OpusHead header
                    if (packet.bytes >= 8 &&
                        memcmp(packet.packet, "OpusHead", 8) == 0) {
                        gotHeader = YES;
                    }
                    continue;
                }

                if (!gotComments) {
                    // Second packet is OpusTags (comments)
                    gotComments = YES;
                    continue;
                }

                // Decode audio packet
                int samples = opus_decode(opusDec,
                                          packet.packet,
                                          packet.bytes,
                                          pcmOut,
                                          MAX_FRAME_SIZE,
                                          0);
                if (samples > 0) {
                    [pcmData appendBytes:pcmOut
                                  length:samples * CHANNELS * sizeof(opus_int16)];
                }
            }
        }
    }

    // Flush remaining packets
    if (streamInited) {
        while (ogg_stream_packetout(&streamState, &packet) == 1) {
            if (!gotHeader) continue;
            if (!gotComments) { gotComments = YES; continue; }
            int samples = opus_decode(opusDec,
                                      packet.packet,
                                      packet.bytes,
                                      pcmOut,
                                      MAX_FRAME_SIZE,
                                      0);
            if (samples > 0) {
                [pcmData appendBytes:pcmOut
                              length:samples * CHANNELS * sizeof(opus_int16)];
            }
        }
    }

    // Cleanup
    opus_decoder_destroy(opusDec);
    if (streamInited) ogg_stream_clear(&streamState);
    ogg_sync_clear(&syncState);

    if ([pcmData length] == 0) return nil;

    // Build WAV file
    UInt32 pcmLen = (UInt32)[pcmData length];
    UInt32 dataSize = pcmLen;
    UInt32 fmtSize = 16;
    UInt16 audioFmt = 1; // PCM
    UInt16 channels = CHANNELS;
    UInt32 sampleRate = SAMPLE_RATE;
    UInt16 bitsPerSample = 16;
    UInt32 byteRate = sampleRate * channels * bitsPerSample / 8;
    UInt16 blockAlign = channels * bitsPerSample / 8;
    UInt32 totalSize = 36 + dataSize;

    WAVHeader header;
    memcpy(header.chunkID, "RIFF", 4);
    header.chunkSize = CFSwapInt32HostToLittle(totalSize);
    memcpy(header.format, "WAVE", 4);

    WAVFmtHeader fmt;
    memcpy(fmt.subchunk1ID, "fmt ", 4);
    fmt.subchunk1Size = CFSwapInt32HostToLittle(fmtSize);
    fmt.audioFormat = CFSwapInt16HostToLittle(audioFmt);
    fmt.numChannels = CFSwapInt16HostToLittle(channels);
    fmt.sampleRate = CFSwapInt32HostToLittle(sampleRate);
    fmt.byteRate = CFSwapInt32HostToLittle(byteRate);
    fmt.blockAlign = CFSwapInt16HostToLittle(blockAlign);
    fmt.bitsPerSample = CFSwapInt16HostToLittle(bitsPerSample);

    WAVDataHeader dataHdr;
    memcpy(dataHdr.subchunk2ID, "data", 4);
    dataHdr.subchunk2Size = CFSwapInt32HostToLittle(dataSize);

    NSMutableData *wavData = [NSMutableData data];
    [wavData appendBytes:&header length:sizeof(WAVHeader)];
    [wavData appendBytes:&fmt length:sizeof(WAVFmtHeader)];
    [wavData appendBytes:&dataHdr length:sizeof(WAVDataHeader)];
    [wavData appendBytes:[pcmData bytes] length:pcmLen];

    return wavData;
}

@end
