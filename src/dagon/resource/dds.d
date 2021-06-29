/*
Copyright (c) 2019-2020 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dagon.resource.dds;

import std.stdio;
import std.file;

import dlib.core.memory;
import dlib.core.stream;
import dlib.core.compound;
import dlib.image.color;
import dlib.image.image;
import dlib.image.io.utils;

import dagon.graphics.compressedimage;

//version = DDSDebug;

struct DDSPixelFormat
{
    uint size;
    uint flags;
    uint fourCC;
    uint bpp;
    uint redMask;
    uint greenMask;
    uint blueMask;
    uint alphaMask;
}

struct DDSCaps
{
    uint caps;
    uint caps2;
    uint caps3;
    uint caps4;
}

struct DDSColorKey
{
    uint lowVal;
    uint highVal;
}

struct DDSHeader
{
    uint size;
    uint flags;
    uint height;
    uint width;
    uint pitch;
    uint depth;
    uint mipMapLevels;
    uint alphaBitDepth;
    uint reserved;
    uint surface;

    DDSColorKey ckDestOverlay;
    DDSColorKey ckDestBlt;
    DDSColorKey ckSrcOverlay;
    DDSColorKey ckSrcBlt;

    DDSPixelFormat format;
    DDSCaps caps;

    uint textureStage;
}

enum DXGIFormat
{
    UNKNOWN = 0,
    R32G32B32A32_TYPELESS = 1,
    R32G32B32A32_FLOAT = 2,
    R32G32B32A32_UINT = 3,
    R32G32B32A32_SINT = 4,
    R32G32B32_TYPELESS = 5,
    R32G32B32_FLOAT = 6,
    R32G32B32_UINT = 7,
    R32G32B32_SINT = 8,
    R16G16B16A16_TYPELESS = 9,
    R16G16B16A16_FLOAT = 10,
    R16G16B16A16_UNORM = 11,
    R16G16B16A16_UINT = 12,
    R16G16B16A16_SNORM = 13,
    R16G16B16A16_SINT = 14,
    R32G32_TYPELESS = 15,
    R32G32_FLOAT = 16,
    R32G32_UINT = 17,
    R32G32_SINT = 18,
    R32G8X24_TYPELESS = 19,
    D32_FLOAT_S8X24_UINT = 20,
    R32_FLOAT_X8X24_TYPELESS = 21,
    X32_TYPELESS_G8X24_UINT = 22,
    R10G10B10A2_TYPELESS = 23,
    R10G10B10A2_UNORM = 24,
    R10G10B10A2_UINT = 25,
    R11G11B10_FLOAT = 26,
    R8G8B8A8_TYPELESS = 27,
    R8G8B8A8_UNORM = 28,
    R8G8B8A8_UNORM_SRGB = 29,
    R8G8B8A8_UINT = 30,
    R8G8B8A8_SNORM = 31,
    R8G8B8A8_SINT = 32,
    R16G16_TYPELESS = 33,
    R16G16_FLOAT = 34,
    R16G16_UNORM = 35,
    R16G16_UINT = 36,
    R16G16_SNORM = 37,
    R16G16_SINT = 38,
    R32_TYPELESS = 39,
    D32_FLOAT = 40,
    R32_FLOAT = 41,
    R32_UINT = 42,
    R32_SINT = 43,
    R24G8_TYPELESS = 44,
    D24_UNORM_S8_UINT = 45,
    R24_UNORM_X8_TYPELESS = 46,
    X24_TYPELESS_G8_UINT = 47,
    R8G8_TYPELESS = 48,
    R8G8_UNORM = 49,
    R8G8_UINT = 50,
    R8G8_SNORM = 51,
    R8G8_SINT = 52,
    R16_TYPELESS = 53,
    R16_FLOAT = 54,
    D16_UNORM = 55,
    R16_UNORM = 56,
    R16_UINT = 57,
    R16_SNORM = 58,
    R16_SINT = 59,
    R8_TYPELESS = 60,
    R8_UNORM = 61,
    R8_UINT = 62,
    R8_SNORM = 63,
    R8_SINT = 64,
    A8_UNORM = 65,
    R1_UNORM = 66,
    R9G9B9E5_SHAREDEXP = 67,
    R8G8_B8G8_UNORM = 68,
    G8R8_G8B8_UNORM = 69,
    BC1_TYPELESS = 70,
    BC1_UNORM = 71,
    BC1_UNORM_SRGB = 72,
    BC2_TYPELESS = 73,
    BC2_UNORM = 74,
    BC2_UNORM_SRGB = 75,
    BC3_TYPELESS = 76,
    BC3_UNORM = 77,
    BC3_UNORM_SRGB = 78,
    BC4_TYPELESS = 79,
    BC4_UNORM = 80,
    BC4_SNORM = 81,
    BC5_TYPELESS = 82,
    BC5_UNORM = 83,
    BC5_SNORM = 84,
    B5G6R5_UNORM = 85,
    B5G5R5A1_UNORM = 86,
    B8G8R8A8_UNORM = 87,
    B8G8R8X8_UNORM = 88,
    R10G10B10_XR_BIAS_A2_UNORM = 89,
    B8G8R8A8_TYPELESS = 90,
    B8G8R8A8_UNORM_SRGB = 91,
    B8G8R8X8_TYPELESS = 92,
    B8G8R8X8_UNORM_SRGB = 93,
    BC6H_TYPELESS = 94,
    BC6H_UF16 = 95,
    BC6H_SF16 = 96,
    BC7_TYPELESS = 97,
    BC7_UNORM = 98,
    BC7_UNORM_SRGB = 99,
    AYUV = 100,
    Y410 = 101,
    Y416 = 102,
    NV12 = 103,
    P010 = 104,
    P016 = 105,
    OPAQUE_420 = 106,
    YUY2 = 107,
    Y210 = 108,
    Y216 = 109,
    NV11 = 110,
    AI44 = 111,
    IA44 = 112,
    P8 = 113,
    A8P8 = 114,
    B4G4R4A4_UNORM = 115,
    P208 = 130,
    V208 = 131,
    V408 = 132
}

enum D3D10ResourceDimension
{
    Unknown,
    Buffer,
    Texture1D,
    Texture2D,
    Texture3D
}

struct DDSHeaderDXT10
{
    uint dxgiFormat;
    uint resourceDimension;
    uint miscFlag;
    uint arraySize;
    uint miscFlags2;
}

uint makeFourCC(char ch0, char ch1, char ch2, char ch3)
{
    return
        ((cast(uint)ch3 << 24) & 0xFF000000) |
        ((cast(uint)ch2 << 16) & 0x00FF0000) |
        ((cast(uint)ch1 << 8)  & 0x0000FF00) |
        ((cast(uint)ch0)       & 0x000000FF);
}

enum FOURCC_DXT1 = makeFourCC('D', 'X', 'T', '1');
enum FOURCC_DXT3 = makeFourCC('D', 'X', 'T', '3');
enum FOURCC_DXT5 = makeFourCC('D', 'X', 'T', '5');
enum FOURCC_DX10 = makeFourCC('D', 'X', '1', '0');

enum FOURCC_BC4U = makeFourCC('B', 'C', '4', 'U');
enum FOURCC_BC4S = makeFourCC('B', 'C', '4', 'S');
enum FOURCC_ATI2 = makeFourCC('A', 'T', 'I', '2');
enum FOURCC_BC5S = makeFourCC('B', 'C', '5', 'S');
enum FOURCC_RGBG = makeFourCC('R', 'G', 'B', 'G');
enum FOURCC_GRGB = makeFourCC('G', 'R', 'G', 'B');

enum FOURCC_DXT2 = makeFourCC('D', 'X', 'T', '2');

DXGIFormat resourceFormatFromFourCC(uint fourCC)
{
    DXGIFormat format;
    
    switch(fourCC)
    {
        case FOURCC_DXT1: format = DXGIFormat.BC1_UNORM; break;
        case FOURCC_DXT3: format = DXGIFormat.BC2_UNORM; break;
        case FOURCC_DXT5: format = DXGIFormat.BC3_UNORM; break;
        case FOURCC_BC4U: format = DXGIFormat.BC4_UNORM; break;
        case FOURCC_BC4S: format = DXGIFormat.BC4_SNORM; break;
        case FOURCC_ATI2: format = DXGIFormat.BC5_UNORM; break;
        case FOURCC_BC5S: format = DXGIFormat.BC5_SNORM; break;
        case FOURCC_RGBG: format = DXGIFormat.R8G8_B8G8_UNORM; break;
        case FOURCC_GRGB: format = DXGIFormat.G8R8_G8B8_UNORM; break;
        case 36:          format = DXGIFormat.R16G16B16A16_UNORM; break;
        case 110:         format = DXGIFormat.R16G16B16A16_SNORM; break;
        case 111:         format = DXGIFormat.R16_FLOAT; break;
        case 112:         format = DXGIFormat.R16G16_FLOAT; break;
        case 113:         format = DXGIFormat.R16G16B16A16_FLOAT; break;
        case 114:         format = DXGIFormat.R32_FLOAT; break;
        case 115:         format = DXGIFormat.R32G32_FLOAT; break;
        case 116:         format = DXGIFormat.R32G32B32A32_FLOAT; break;
        default:          format = DXGIFormat.UNKNOWN; break;
        // TODO: FOURCC_DXT2 and other obsolete formats?
    }
    
    return format;
}

Compound!(CompressedImage, string) loadDDS(InputStream istrm)
{
    CompressedImage img = null;

    void finalize()
    {
    }

    Compound!(CompressedImage, string) error(string errorMsg)
    {
        finalize();
        if (img)
        {
            Delete(img);
            img = null;
        }
        return compound(img, errorMsg);
    }

    char[4] magic;

    if (!istrm.fillArray(magic))
    {
        return error("loadDDS error: not a DDS file or corrupt data");
    }

    version(DDSDebug)
    {
        writeln("Signature: ", magic);
    }

    if (magic != "DDS ")
    {
        return error("loadDDS error: not a DDS file");
    }

    DDSHeader hdr = readStruct!DDSHeader(istrm);

    version(DDSDebug)
    {
        writeln("hdr.size: ", hdr.size);
        writeln("hdr.flags: ", hdr.flags);
        writeln("hdr.height: ", hdr.height);
        writeln("hdr.width: ", hdr.width);
        writeln("hdr.pitch: ", hdr.pitch);
        writeln("hdr.depth: ", hdr.depth);
        writeln("hdr.mipMapLevels: ", hdr.mipMapLevels);
        writeln("hdr.alphaBitDepth: ", hdr.alphaBitDepth);
        writeln("hdr.reserved: ", hdr.reserved);
        writeln("hdr.surface: ", hdr.surface);

        writeln("hdr.ckDestOverlay.lowVal: ", hdr.ckDestOverlay.lowVal);
        writeln("hdr.ckDestOverlay.highVal: ", hdr.ckDestOverlay.highVal);
        writeln("hdr.ckDestBlt.lowVal: ", hdr.ckDestBlt.lowVal);
        writeln("hdr.ckDestBlt.highVal: ", hdr.ckDestBlt.highVal);
        writeln("hdr.ckSrcOverlay.lowVal: ", hdr.ckSrcOverlay.lowVal);
        writeln("hdr.ckSrcOverlay.highVal: ", hdr.ckSrcOverlay.highVal);
        writeln("hdr.ckSrcBlt.lowVal: ", hdr.ckSrcBlt.lowVal);
        writeln("hdr.ckSrcBlt.highVal: ", hdr.ckSrcBlt.highVal);

        writeln("hdr.format.size: ", hdr.format.size);
        writeln("hdr.format.flags: ", hdr.format.flags);
        writeln("hdr.format.fourCC: ", hdr.format.fourCC);
        writeln("hdr.format.bpp: ", hdr.format.bpp);
        writeln("hdr.format.redMask: ", hdr.format.redMask);
        writeln("hdr.format.greenMask: ", hdr.format.greenMask);
        writeln("hdr.format.blueMask: ", hdr.format.blueMask);
        writeln("hdr.format.alphaMask: ", hdr.format.alphaMask);

        writeln("hdr.caps.caps: ", hdr.caps.caps);
        writeln("hdr.caps.caps2: ", hdr.caps.caps2);
        writeln("hdr.caps.caps3: ", hdr.caps.caps3);
        writeln("hdr.caps.caps4: ", hdr.caps.caps4);

        writeln("hdr.textureStage: ", hdr.textureStage);
    }

    CompressedImageFormat format;

    DXGIFormat fmt;
    if (hdr.format.fourCC == FOURCC_DX10)
    {
        DDSHeaderDXT10 dx10 = readStruct!DDSHeaderDXT10(istrm);
        fmt = cast(DXGIFormat)dx10.dxgiFormat;
    }
    else
    {
        fmt = resourceFormatFromFourCC(hdr.format.fourCC);
    }
    
    version(DDSDebug) writeln("format: ", fmt);

    switch(fmt)
    {
        case DXGIFormat.BC1_UNORM:
            format = CompressedImageFormat.S3TC_RGB_DXT1;
            break;
        case DXGIFormat.BC2_UNORM:
            format = CompressedImageFormat.S3TC_RGBA_DXT3;
            break;
        case DXGIFormat.BC3_UNORM:
            format = CompressedImageFormat.S3TC_RGBA_DXT5;
            break;
        case DXGIFormat.BC4_UNORM:
            format = CompressedImageFormat.RGTC1_R;
            break;
        case DXGIFormat.BC4_SNORM:
            format = CompressedImageFormat.RGTC1_R_S;
            break;
        case DXGIFormat.BC5_UNORM:
            format = CompressedImageFormat.RGTC2_RG;
            break;
        case DXGIFormat.BC5_SNORM:
            format = CompressedImageFormat.RGTC2_RG_S;
            break;
        case DXGIFormat.BC7_UNORM:
            format = CompressedImageFormat.BPTC_RGBA_UNORM;
            break;
        case DXGIFormat.BC7_UNORM_SRGB:
            format = CompressedImageFormat.BPTC_SRGBA_UNORM;
            break;
        case DXGIFormat.BC6H_SF16:
            format = CompressedImageFormat.BPTC_RGB_SF;
            break;
        case DXGIFormat.BC6H_UF16:
            format = CompressedImageFormat.BPTC_RGB_UF;
            break;
        case DXGIFormat.R32G32B32A32_FLOAT:
            format = CompressedImageFormat.RGBAF32;
            break;
        // TODO: support DXGIFormat.R16G16B16A16_FLOAT
        default:
            return error("loadDDS error: unsupported resource format");
    }

    size_t bufferSize = cast(size_t)(istrm.size - istrm.getPosition);
    version(DDSDebug) writeln("bufferSize: ", bufferSize);

    img = New!CompressedImage(hdr.width, hdr.height, format, hdr.mipMapLevels, bufferSize);
    istrm.readBytes(img.data.ptr, bufferSize);

    return compound(img, "");
}
