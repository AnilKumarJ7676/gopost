#ifndef GOPOST_TYPES_H
#define GOPOST_TYPES_H

#include <stddef.h>
#include <stdint.h>

typedef enum {
    GOPOST_PIXEL_FORMAT_RGBA8 = 0,
    GOPOST_PIXEL_FORMAT_BGRA8 = 1,
    GOPOST_PIXEL_FORMAT_NV12  = 2,
    GOPOST_PIXEL_FORMAT_YUV420P = 3,
} GopostPixelFormat;

typedef struct {
    uint32_t width;
    uint32_t height;
    GopostPixelFormat format;
    uint8_t* data;
    size_t data_size;
    size_t stride;
} GopostFrame;

typedef struct {
    float x;
    float y;
    float width;
    float height;
} GopostRect;

typedef struct {
    float r;
    float g;
    float b;
    float a;
} GopostColor;

#endif
