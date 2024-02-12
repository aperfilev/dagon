/*
Copyright (c) 2017-2023 Timur Gafarov

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
module dagon.graphics.texture;

import std.stdio;
import std.math;
import std.algorithm;
import std.traits;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.container.array;
import dlib.image.image;
import dlib.image.color;
import dlib.image.hdri;
import dlib.image.unmanaged;
import dlib.math.utils;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;

import dagon.core.bindings;

// S3TC formats
enum GL_COMPRESSED_RGB_S3TC_DXT1_EXT = 0x83F0;  // DXT1/BC1_UNORM
enum GL_COMPRESSED_RGBA_S3TC_DXT3_EXT = 0x83F2; // DXT3/BC2_UNORM
enum GL_COMPRESSED_RGBA_S3TC_DXT5_EXT = 0x83F3; // DXT5/BC3_UNORM

// RGTC formats
/*
enum GL_COMPRESSED_RED_RGTC1 = 0x8DBB;        // BC4_UNORM
enum GL_COMPRESSED_SIGNED_RED_RGTC1 = 0x8DBC; // BC4_SNORM
enum GL_COMPRESSED_RG_RGTC2 = 0x8DBD;         // BC5_UNORM
enum GL_COMPRESSED_SIGNED_RG_RGTC2 = 0x8DBE;  // BC5_SNORM
*/

// BPTC formats
enum GL_COMPRESSED_RGBA_BPTC_UNORM_ARB = 0x8E8C;         // BC7_UNORM
enum GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_ARB = 0x8E8D;   // BC7_UNORM_SRGB
enum GL_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_ARB = 0x8E8E;   // BC6H_SF16
enum GL_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_ARB = 0x8E8F; // BC6H_UF16

// ASTC formats
enum GL_COMPRESSED_RGBA_ASTC_4x4_KHR = 0x93B0;
enum GL_COMPRESSED_RGBA_ASTC_5x4_KHR = 0x93B1;
enum GL_COMPRESSED_RGBA_ASTC_5x5_KHR = 0x93B2;
enum GL_COMPRESSED_RGBA_ASTC_6x5_KHR = 0x93B3;
enum GL_COMPRESSED_RGBA_ASTC_6x6_KHR = 0x93B4;
enum GL_COMPRESSED_RGBA_ASTC_8x5_KHR = 0x93B5;
enum GL_COMPRESSED_RGBA_ASTC_8x6_KHR = 0x93B6;
enum GL_COMPRESSED_RGBA_ASTC_8x8_KHR = 0x93B7;
enum GL_COMPRESSED_RGBA_ASTC_10x5_KHR = 0x93B8;
enum GL_COMPRESSED_RGBA_ASTC_10x6_KHR = 0x93B9;
enum GL_COMPRESSED_RGBA_ASTC_10x8_KHR = 0x93BA;
enum GL_COMPRESSED_RGBA_ASTC_10x10_KHR = 0x93BB;
enum GL_COMPRESSED_RGBA_ASTC_12x10_KHR = 0x93BC;
enum GL_COMPRESSED_RGBA_ASTC_12x12_KHR = 0x93BD;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR = 0x93D0;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR = 0x93D1;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR = 0x93D2;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR = 0x93D3;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR = 0x93D4;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR = 0x93D5;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR = 0x93D6;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR = 0x93D7;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR = 0x93D8;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR = 0x93D9;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR = 0x93DA;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR = 0x93DB;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR = 0x93DC;
enum GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR = 0x93DD;

enum TextureDimension
{
    Undefined,
    D1,
    D2,
    D3
}

struct TextureSize
{
    uint width;
    uint height;
    uint depth;
}

enum CubeFace: GLenum
{
    PositiveX = GL_TEXTURE_CUBE_MAP_POSITIVE_X,
    NegativeX = GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
    PositiveY = GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
    NegativeY = GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
    PositiveZ = GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
    NegativeZ = GL_TEXTURE_CUBE_MAP_NEGATIVE_Z
}

enum CubeFaceBit
{
    None = 0,
    PositiveX = 1,
    NegativeX = 2,
    PositiveY = 4,
    NegativeY = 8,
    PositiveZ = 16,
    NegativeZ = 32,
    All = 0xffffffff
}

CubeFaceBit cubeFaceBit(CubeFace face)
{
    CubeFaceBit cfb = CubeFaceBit.None;
    switch(face)
    {
        case CubeFace.PositiveX: cfb = CubeFaceBit.PositiveX; break;
        case CubeFace.NegativeX: cfb = CubeFaceBit.NegativeX; break;
        case CubeFace.PositiveY: cfb = CubeFaceBit.PositiveY; break;
        case CubeFace.NegativeY: cfb = CubeFaceBit.NegativeY; break;
        case CubeFace.PositiveZ: cfb = CubeFaceBit.PositiveZ; break;
        case CubeFace.NegativeZ: cfb = CubeFaceBit.NegativeZ; break;
        default: break;
    }
    return cfb;
}

struct TextureFormat
{
    GLenum target;
    GLenum format;
    GLint internalFormat;
    GLenum pixelType;
    uint blockSize;
    uint cubeFaces; // bitwise combination of CubeFaceBit members
}

enum uint[GLenum] numChannelsFormat = [
    // Uncompressed formats
    GL_RED: 1,
    GL_RG: 2,
    GL_RGB: 3,
    GL_BGR: 3,
    GL_RGBA: 4,
    GL_BGRA: 4,
    GL_RED_INTEGER: 1,
    GL_RG_INTEGER: 2,
    GL_RGB_INTEGER: 3,
    GL_BGR_INTEGER: 3,
    GL_RGBA_INTEGER: 4,
    GL_BGRA_INTEGER: 4,
    GL_STENCIL_INDEX: 1,
    GL_DEPTH_COMPONENT: 1,
    GL_DEPTH_STENCIL: 1,
    
    // Compressed formats
    GL_COMPRESSED_RED: 1,
    GL_COMPRESSED_RG: 2,
    GL_COMPRESSED_RGB: 3,
    GL_COMPRESSED_RGBA: 4,
    GL_COMPRESSED_SRGB: 3,
    GL_COMPRESSED_SRGB_ALPHA: 4,
    GL_COMPRESSED_RED_RGTC1: 1,
    GL_COMPRESSED_SIGNED_RED_RGTC1: 1,
    GL_COMPRESSED_RG_RGTC2: 2,
    GL_COMPRESSED_SIGNED_RG_RGTC2: 2,
    GL_COMPRESSED_RGB_S3TC_DXT1_EXT: 3,
    GL_COMPRESSED_RGBA_S3TC_DXT3_EXT: 4,
    GL_COMPRESSED_RGBA_S3TC_DXT5_EXT: 4,
    GL_COMPRESSED_RGBA_BPTC_UNORM_ARB: 4,
    GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_ARB: 3,
    GL_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_ARB: 3,
    GL_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_ARB: 3,
    GL_COMPRESSED_RGBA_ASTC_4x4_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_5x4_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_5x5_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_6x5_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_6x6_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_8x5_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_8x6_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_8x8_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_10x5_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_10x6_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_10x8_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_10x10_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_12x10_KHR: 4,
    GL_COMPRESSED_RGBA_ASTC_12x12_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR: 4,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR: 4
];

enum GLint[] compressedFormats = [
    GL_COMPRESSED_RED,
    GL_COMPRESSED_RG,
    GL_COMPRESSED_RGB,
    GL_COMPRESSED_RGBA,
    GL_COMPRESSED_SRGB,
    GL_COMPRESSED_SRGB_ALPHA,
    GL_COMPRESSED_RED_RGTC1,
    GL_COMPRESSED_SIGNED_RED_RGTC1,
    GL_COMPRESSED_RG_RGTC2,
    GL_COMPRESSED_SIGNED_RG_RGTC2,
    GL_COMPRESSED_RGB_S3TC_DXT1_EXT,
    GL_COMPRESSED_RGBA_S3TC_DXT3_EXT,
    GL_COMPRESSED_RGBA_S3TC_DXT5_EXT,
    GL_COMPRESSED_RGBA_BPTC_UNORM_ARB,
    GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_ARB,
    GL_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_ARB,
    GL_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_ARB,
    GL_COMPRESSED_RGBA_ASTC_4x4_KHR,
    GL_COMPRESSED_RGBA_ASTC_5x4_KHR,
    GL_COMPRESSED_RGBA_ASTC_5x5_KHR,
    GL_COMPRESSED_RGBA_ASTC_6x5_KHR,
    GL_COMPRESSED_RGBA_ASTC_6x6_KHR,
    GL_COMPRESSED_RGBA_ASTC_8x5_KHR,
    GL_COMPRESSED_RGBA_ASTC_8x6_KHR,
    GL_COMPRESSED_RGBA_ASTC_8x8_KHR,
    GL_COMPRESSED_RGBA_ASTC_10x5_KHR,
    GL_COMPRESSED_RGBA_ASTC_10x6_KHR,
    GL_COMPRESSED_RGBA_ASTC_10x8_KHR,
    GL_COMPRESSED_RGBA_ASTC_10x10_KHR,
    GL_COMPRESSED_RGBA_ASTC_12x10_KHR,
    GL_COMPRESSED_RGBA_ASTC_12x12_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR,
    GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR
];

struct TextureBuffer
{
    TextureFormat format;
    TextureSize size;
    uint mipLevels;
    ubyte[] data;
}

class Texture: Owner
{
    GLuint texture;
    TextureFormat format;
    TextureSize size;
    bool generateMipmaps;
    uint mipLevels;
    GLint minFilter = GL_LINEAR;
    GLint magFilter = GL_LINEAR;
    GLint wrapS = GL_REPEAT;
    GLint wrapT = GL_REPEAT;
    GLint wrapR = GL_REPEAT;
    
    this(Owner owner)
    {
        super(owner);
    }
    
    ~this()
    {
        release();
    }
    
    void createBlank(uint w, uint h, uint channels, uint bitDepth, bool genMipmaps, Color4f fillColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f))
    {
        release();
        
        SuperImage img = unmanagedImage(w, h, channels, bitDepth);
        
        foreach(y; 0..img.height)
        foreach(x; 0..img.width)
        {
            img[x, y] = fillColor;
        }
        
        createFromImage(img, genMipmaps);
        
        Delete(img);
    }
    
    void createFromImage(SuperImage img, bool genMipmaps)
    {
        release();
        
        this.generateMipmaps = genMipmaps;
        
        if (detectTextureFormat(img, this.format))
        {
            this.size = TextureSize(img.width, img.height, 1);
            this.mipLevels = 1;
            createTexture2D(img.data);
        }
        else
        {
            writeln("Unsupported image format ", img.pixelFormat);
            createFallbackTexture();
        }
    }
    
    void createFromImage3D(SuperImage img, uint size = 0)
    {
        if (size == 0)
        {
            size = cast(uint)cbrt(img.width * img.height);
        }
        else
        {
            if (img.width != img.height || img.width * img.height != size * size * size)
            {
                uint s = cast(uint)sqrt(cast(real)size * size * size);
                writeln("Wrong image resolution for 3D texture size ", size, ": should be ", s, "x", s);
                return;
            }
        }
        
        TextureFormat format;
        detectTextureFormat(img, format);
        TextureBuffer buff;
        buff.format = format;
        buff.format.target = GL_TEXTURE_3D;
        buff.size = TextureSize(size, size, size);
        buff.mipLevels = 1;
        buff.data = img.data;
        createFromBuffer(buff, false);
        minFilter = GL_LINEAR;
        magFilter = GL_LINEAR;
        wrapS = GL_CLAMP_TO_EDGE;
        wrapT = GL_CLAMP_TO_EDGE;
        wrapR = GL_CLAMP_TO_EDGE;
    }
    
    void createFromBuffer(TextureBuffer buff, bool genMipmaps)
    {
        release();
        
        this.generateMipmaps = genMipmaps;
        
        this.format = buff.format;
        this.size = buff.size;
        this.mipLevels = buff.mipLevels;
        
        if (isCubemap)
            createCubemap(buff.data);
        else if (format.target == GL_TEXTURE_1D)
            createTexture1D(buff.data);
        else if (format.target == GL_TEXTURE_2D)
            createTexture2D(buff.data);
        else if (format.target == GL_TEXTURE_3D)
            createTexture3D(buff.data);
        else
            writeln("Texture creation failed: unsupported target ", format.target);
    }
    
    protected void createCubemap(ubyte[] buffer)
    {
        glGenTextures(1, &texture);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_CUBE_MAP, texture);
        
        minFilter = GL_LINEAR;
        magFilter = GL_LINEAR;
        wrapS = GL_CLAMP_TO_EDGE;
        wrapT = GL_CLAMP_TO_EDGE;
        wrapR = GL_CLAMP_TO_EDGE;
        
        if (isCompressed)
        {
            if (mipLevels > 1)
            {
                glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_BASE_LEVEL, 0);
                glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAX_LEVEL, mipLevels - 1);
            }
            
            uint offset = 0;
            
            foreach(cubeFace; EnumMembers!CubeFace)
            {
                uint w = size.width;
                uint h = size.height;
                
                if (mipLevels == 1)
                {
                    uint size = ((w + 3) / 4) * ((h + 3) / 4) * format.blockSize;
                    glCompressedTexImage2D(cubeFace, 0, format.internalFormat, w, h, 0, cast(uint)buffer.length, cast(void*)buffer.ptr);
                    offset += size;
                }
                else
                {
                    for (uint mipLevel = 0; mipLevel < mipLevels; mipLevel++)
                    {
                        uint imageSize = ((w + 3) / 4) * ((h + 3) / 4) * format.blockSize;
                        glCompressedTexImage2D(cubeFace, mipLevel, format.internalFormat, w, h, 0, imageSize, cast(void*)(buffer.ptr + offset));
                        offset += imageSize;
                        w /= 2;
                        h /= 2;
                    }
                }
            }
        }
        else
        {
            uint pSize = pixelSize;
            uint offset = 0;
            
            foreach(cubeFace; EnumMembers!CubeFace)
            {
                uint w = size.width;
                uint h = size.height;
                
                for (uint mipLevel = 0; mipLevel < mipLevels; mipLevel++)
                {
                    uint size = w * h * pSize;
                    glTexImage2D(cubeFace, mipLevel, format.internalFormat, w, h, 0, format.format, format.pixelType, cast(void*)(buffer.ptr + offset));
                    offset += size;
                    w /= 2;
                    h /= 2;
                    if (offset >= buffer.length)
                    {
                        writeln("Error: incomplete texture buffer");
                        break;
                    }
                }
            }
        }
        
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
        
        if (mipLevels > 1)
        {
            minFilter = GL_LINEAR_MIPMAP_LINEAR;
            magFilter = GL_LINEAR;
        }
        else
        {
            minFilter = GL_LINEAR;
            magFilter = GL_LINEAR;
        }
    }
    
    protected void createTexture1D(ubyte[] buffer)
    {
        glGenTextures(1, &texture);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_1D, texture);
        
        minFilter = GL_LINEAR;
        magFilter = GL_LINEAR;
        wrapS = GL_REPEAT;
        wrapT = GL_REPEAT;
        wrapR = GL_REPEAT;
        
        uint w = size.width;
        
        if (isCompressed)
        {
            if (mipLevels == 1)
            {
                glCompressedTexImage1D(GL_TEXTURE_1D, 0, format.internalFormat, w, 0, cast(uint)buffer.length, cast(void*)buffer.ptr);
            }
            else
            {
                glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_BASE_LEVEL, 0);
                glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MAX_LEVEL, mipLevels - 1);
                
                uint offset = 0;
                
                for (uint mipLevel = 0; mipLevel < mipLevels; mipLevel++)
                {
                    uint imageSize = ((w + 3) / 4) * format.blockSize;
                    
                    glCompressedTexImage1D(GL_TEXTURE_1D, mipLevel, format.internalFormat, w, 0, imageSize, cast(void*)(buffer.ptr + offset));
                    
                    offset += imageSize;
                    w /= 2;
                }
            }
        }
        else
        {
            if (mipLevels == 1)
            {
                glTexImage1D(GL_TEXTURE_1D, 0, format.internalFormat, w, 0, format.format, format.pixelType, cast(void*)buffer.ptr);
                
                if (generateMipmaps)
                {
                    glGenerateMipmap(GL_TEXTURE_1D);
                    mipLevels = 1 + cast(uint)floor(log2(cast(float)w));
                }
                else
                    mipLevels = 1;
            }
        }
    }
    
    protected void createTexture2D(ubyte[] buffer)
    {
        glGenTextures(1, &texture);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, texture);
        
        minFilter = GL_LINEAR;
        magFilter = GL_LINEAR;
        wrapS = GL_REPEAT;
        wrapT = GL_REPEAT;
        wrapR = GL_REPEAT;
        
        uint w = size.width;
        uint h = size.height;
        
        if (isCompressed)
        {
            if (mipLevels == 1)
            {
                glCompressedTexImage2D(GL_TEXTURE_2D, 0, format.internalFormat, w, h, 0, cast(uint)buffer.length, cast(void*)buffer.ptr);
            }
            else
            {
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, mipLevels - 1);
                
                uint offset = 0;
                
                for (uint mipLevel = 0; mipLevel < mipLevels; mipLevel++)
                {
                    uint imageSize = ((w + 3) / 4) * ((h + 3) / 4) * format.blockSize;
                    glCompressedTexImage2D(GL_TEXTURE_2D, mipLevel, format.internalFormat, w, h, 0, imageSize, cast(void*)(buffer.ptr + offset));
                    offset += imageSize;
                    w /= 2;
                    h /= 2;
                }
            }
        }
        else
        {
            if (mipLevels == 1)
            {
                glTexImage2D(GL_TEXTURE_2D, 0, format.internalFormat, w, h, 0, format.format, format.pixelType, cast(void*)buffer.ptr);
                
                if (generateMipmaps)
                {
                    glGenerateMipmap(GL_TEXTURE_2D);
                    mipLevels = 1 + cast(uint)floor(log2(cast(float)max(w, h)));
                }
                else
                    mipLevels = 1;
            }
            else if (channelSize > 0)
            {
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, mipLevels - 1);
                
                uint pSize = pixelSize;
                uint offset = 0;
                
                for (uint mipLevel = 0; mipLevel < mipLevels; mipLevel++)
                {
                    uint imageSize = w * h * pSize;
                    glTexImage2D(GL_TEXTURE_2D, mipLevel, format.internalFormat, w, h, 0, format.format, format.pixelType, cast(void*)(buffer.ptr + offset));
                    offset += imageSize;
                    w /= 2;
                    h /= 2;
                    if (offset >= buffer.length)
                    {
                        writeln("Error: incomplete texture buffer");
                        break;
                    }
                }
            }
        }
        
        if (mipLevels > 1)
        {
            minFilter = GL_LINEAR_MIPMAP_LINEAR;
            magFilter = GL_LINEAR;
        }
        else
        {
            minFilter = GL_LINEAR;
            magFilter = GL_LINEAR;
        }
    }
    
    protected void createTexture3D(ubyte[] buffer)
    {
        glGenTextures(1, &texture);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_3D, texture);
        
        minFilter = GL_LINEAR;
        magFilter = GL_LINEAR;
        wrapS = GL_REPEAT;
        wrapT = GL_REPEAT;
        wrapR = GL_REPEAT;
        
        uint w = size.width;
        uint h = size.height;
        uint d = size.depth;
        
        if (isCompressed)
        {
            writeln("Compressed 3D textures are not supported");
        }
        else
        {
            if (mipLevels == 1)
            {
                glTexImage3D(GL_TEXTURE_3D, 0, format.internalFormat, w, h, d, 0, format.format, format.pixelType, cast(void*)buffer.ptr);
                
                if (generateMipmaps)
                {
                    glGenerateMipmap(GL_TEXTURE_3D);
                    mipLevels = 1 + cast(uint)floor(log2(cast(float)max3(w, h, d)));
                }
                else
                    mipLevels = 1;
            }
            else if (channelSize > 0)
            {
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, mipLevels - 1);
                
                uint pSize = pixelSize;
                uint offset = 0;
                
                for (uint mipLevel = 0; mipLevel < mipLevels; mipLevel++)
                {
                    uint imageSize = w * h * d * pSize;
                    glTexImage3D(GL_TEXTURE_3D, mipLevel, format.internalFormat, w, h, d, 0, format.format, format.pixelType, cast(void*)(buffer.ptr + offset));
                    offset += imageSize;
                    w /= 2;
                    h /= 2;
                    d /= 2;
                    if (offset >= buffer.length)
                    {
                        writeln("Error: incomplete texture buffer");
                        break;
                    }
                }
            }
        }
    }
    
    void createFromEquirectangularMap(SuperImage envmap, uint resolution, bool generateMipmaps = true)
    {
        glGenTextures(1, &texture);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_CUBE_MAP, texture);
        
        minFilter = GL_LINEAR;
        magFilter = GL_LINEAR;
        wrapS = GL_CLAMP_TO_EDGE;
        wrapT = GL_CLAMP_TO_EDGE;
        wrapR = GL_CLAMP_TO_EDGE;
        
        TextureFormat tf;
        if (detectTextureFormat(envmap, tf))
        {
            format.cubeFaces = CubeFaceBit.All;
            SuperImage faceImage = envmap.createSameFormat(resolution, resolution);
            
            foreach(i, face; EnumMembers!CubeFace)
            {
                Matrix4x4f dirTransform = cubeFaceMatrix(face);
                
                foreach(x; 0..resolution)
                foreach(y; 0..resolution)
                {
                    float cubex = (cast(float)x / cast(float)resolution) * 2.0f - 1.0f;
                    float cubey = (1.0f - cast(float)y / cast(float)resolution) * 2.0f - 1.0f;
                    Vector3f dir = Vector3f(cubex, cubey, 1.0f).normalized * dirTransform;
                    Vector2f uv = equirectProj(dir);
                    Color4f c = bilinearPixel(envmap, uv.x * envmap.width, uv.y * envmap.height);
                    faceImage[x, y] = c;
                }
                
                glTexImage2D(face, 0, tf.internalFormat, resolution, resolution, 0, tf.format, tf.pixelType, cast(void*)faceImage.data.ptr);
            }
            
            Delete(faceImage);
            
            if (generateMipmaps)
            {
                glGenerateMipmap(GL_TEXTURE_CUBE_MAP);
                mipLevels = 1 + cast(uint)floor(log2(cast(float)resolution));
            }
            else
                mipLevels = 1;
        }
        else
        {
            writefln("Unsupported pixel format %s", envmap.pixelFormat);
        }
        
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    }
    
    void generateMipmap()
    {
        if (valid)
        {
            bind();
            glGenerateMipmap(format.target);
            mipLevels = 1 + cast(uint)floor(log2(cast(float)max(size.width, size.height)));
            unbind();
            useMipmapFiltering(true);
        }
    }
    
    void createFallbackTexture()
    {
        // TODO
    }
    
    void release()
    {
        if (valid)
            glDeleteTextures(1, &texture);
    }
    
    deprecated("use Texture.release instead") alias releaseGLTexture = release;
    
    bool valid()
    {
        return cast(bool)glIsTexture(texture);
    }
    
    void bind()
    {
        if (valid)
        {
            if (isCubemap)
            {
                glBindTexture(GL_TEXTURE_CUBE_MAP, texture);
                glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, minFilter);
                glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, magFilter);
                glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, wrapS);
                glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, wrapT);
                glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, wrapR);
            }
            else if (dimension == TextureDimension.D1)
            {
                glBindTexture(GL_TEXTURE_1D, texture);
                glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, minFilter);
                glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, magFilter);
                glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, wrapS);
                glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_WRAP_T, wrapT);
                glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_WRAP_R, wrapR);
            }
            else if (dimension == TextureDimension.D2)
            {
                glBindTexture(GL_TEXTURE_2D, texture);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilter);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilter);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapS);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapT);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, wrapR);
            }
            else if (dimension == TextureDimension.D3)
            {
                glBindTexture(GL_TEXTURE_3D, texture);
                glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, minFilter);
                glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, magFilter);
                glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, wrapS);
                glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, wrapT);
                glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, wrapR);
            }
        }
    }

    void unbind()
    {
        if (isCubemap)
            glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
        else if (dimension == TextureDimension.D1)
            glBindTexture(GL_TEXTURE_1D, 0);
        else if (dimension == TextureDimension.D2)
            glBindTexture(GL_TEXTURE_2D, 0);
        else if (dimension == TextureDimension.D3)
            glBindTexture(GL_TEXTURE_3D, 0);
    }
    
    uint width() @property
    {
        return size.width;
    }
    
    uint height() @property
    {
        return size.height;
    }
    
    uint numChannels() @property
    {
        if (format.format in numChannelsFormat)
            return numChannelsFormat[format.format];
        else
            return 0;
    }
    
    bool hasAlpha() @property
    {
        return (numChannels == 4);
    }
    
    bool isCompressed() @property
    {
        return compressedFormats.canFind(format.internalFormat);
    }
    
    bool isCubemap() @property
    {
        return format.cubeFaces != CubeFaceBit.None;
    }
    
    TextureDimension dimension() @property
    {
        if (format.target == GL_TEXTURE_1D)
            return TextureDimension.D1;
        else if (format.target == GL_TEXTURE_2D)
            return TextureDimension.D2;
        else if (format.target == GL_TEXTURE_3D)
            return TextureDimension.D3;
        else
            return TextureDimension.Undefined;
    }
    
    uint channelSize() @property
    {
        uint s = 0;
        switch(format.pixelType)
        {
            case GL_UNSIGNED_BYTE:  s = 1; break;
            case GL_BYTE:           s = 1; break;
            case GL_UNSIGNED_SHORT: s = 2; break;
            case GL_SHORT:          s = 2; break;
            case GL_UNSIGNED_INT:   s = 4; break;
            case GL_INT:            s = 4; break;
            case GL_HALF_FLOAT:     s = 2; break;
            case GL_FLOAT:          s = 4; break;
            default:                s = 0; break;
        }
        return s;
    }
    
    uint pixelSize() @property
    {
        return numChannels * channelSize;
    }
    
    bool useMipmapFiltering() @property
    {
        return minFilter == GL_LINEAR_MIPMAP_LINEAR;
    }
    
    void useMipmapFiltering(bool mode) @property
    {
        if (mode)
            minFilter = GL_LINEAR_MIPMAP_LINEAR;
        else
            minFilter = GL_LINEAR;
    }
    
    void enableRepeat(bool mode) @property
    {
        if (mode)
        {
            wrapS = GL_REPEAT;
            wrapT = GL_REPEAT;
            wrapR = GL_REPEAT;
        }
        else
        {
            wrapS = GL_CLAMP_TO_EDGE;
            wrapT = GL_CLAMP_TO_EDGE;
            wrapR = GL_CLAMP_TO_EDGE;
        }
    }
    
    void setFaceBit(CubeFace face)
    {
        format.cubeFaces = format.cubeFaces | cubeFaceBit(face);
    }
    
    void setFaceImage(CubeFace face, SuperImage img)
    {
        if (img.width != img.height)
        {
            writeln("Cubemap face image must be square");
            return;
        }
        
        TextureFormat tf;
        if (!detectTextureFormat(img, tf))
        {
            writeln("Unsupported image format ", img.pixelFormat);
            return;
        }
        
        if (!valid)
        {
            format.target = GL_TEXTURE_CUBE_MAP;
            
            // TODO: store individual size and format for each face
            
            size.width = img.width;
            size.height = img.height;
            
            format.format = tf.format;
            format.internalFormat = tf.internalFormat;
            format.pixelType = tf.pixelType;
            format.blockSize = tf.blockSize;
            
            glGenTextures(1, &texture);
            
            minFilter = GL_LINEAR;
            magFilter = GL_LINEAR;
            wrapS = GL_CLAMP_TO_EDGE;
            wrapT = GL_CLAMP_TO_EDGE;
            wrapR = GL_CLAMP_TO_EDGE;
        }
        
        setFaceBit(face);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_CUBE_MAP, texture);
        if (isCompressed)
        {
            uint size = ((img.width + 3) / 4) * ((img.height + 3) / 4) * tf.blockSize;
            glCompressedTexImage2D(face, 0, tf.internalFormat, img.width, img.height, 0, size, cast(void*)img.data.ptr);
        }
        else
        {
            glTexImage2D(face, 0, tf.internalFormat, img.width, img.height, 0, tf.format, tf.pixelType, cast(void*)img.data.ptr);
        }
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    }
}

bool detectTextureFormat(SuperImage img, out TextureFormat tf)
{
    uint pixelFormat = img.pixelFormat;
    switch(pixelFormat)
    {
        case IntegerPixelFormat.L8:    tf.internalFormat = GL_R8;      tf.format = GL_RED;  tf.pixelType = GL_UNSIGNED_BYTE; break;
        case IntegerPixelFormat.LA8:   tf.internalFormat = GL_RG8;     tf.format = GL_RG;   tf.pixelType = GL_UNSIGNED_BYTE; break;
        case IntegerPixelFormat.RGB8:  tf.internalFormat = GL_RGB8;    tf.format = GL_RGB;  tf.pixelType = GL_UNSIGNED_BYTE; break;
        case IntegerPixelFormat.RGBA8: tf.internalFormat = GL_RGBA8;   tf.format = GL_RGBA; tf.pixelType = GL_UNSIGNED_BYTE; break;
        case FloatPixelFormat.RGBAF32: tf.internalFormat = GL_RGBA32F; tf.format = GL_RGBA; tf.pixelType = GL_FLOAT; break;
        default:
            return false;
    }
    
    tf.target = GL_TEXTURE_2D;
    tf.blockSize = 0;
    tf.cubeFaces = CubeFaceBit.None;
    
    return true;
}

Matrix4x4f cubeFaceMatrix(CubeFace cf)
{
    switch(cf)
    {
        case CubeFace.PositiveX:
            return rotationMatrix(1, degtorad(-90.0f));
        case CubeFace.NegativeX:
            return rotationMatrix(1, degtorad(90.0f));
        case CubeFace.PositiveY:
            return rotationMatrix(0, degtorad(90.0f));
        case CubeFace.NegativeY:
            return rotationMatrix(0, degtorad(-90.0f));
        case CubeFace.PositiveZ:
            return rotationMatrix(1, degtorad(0.0f));
        case CubeFace.NegativeZ:
            return rotationMatrix(1, degtorad(180.0f));
        default:
            return Matrix4x4f.identity;
    }
}

Matrix4x4f cubeFaceCameraMatrix(CubeFace cf, Vector3f pos)
{
    Matrix4x4f m;
    switch(cf)
    {
        case CubeFace.PositiveX:
            m = rotationMatrix(1, degtorad(90.0f)) * translationMatrix(pos) * rotationMatrix(1, degtorad(90.0f)) * rotationMatrix(2, degtorad(180.0f));
            break;
        case CubeFace.NegativeX:
            m = rotationMatrix(1, degtorad(90.0f)) * translationMatrix(pos) * rotationMatrix(1, degtorad(-90.0f)) * rotationMatrix(2, degtorad(180.0f));
            break;
        case CubeFace.PositiveY:
            m = rotationMatrix(1, degtorad(90.0f)) * translationMatrix(pos) * rotationMatrix(1, degtorad(0.0f)) * rotationMatrix(0, degtorad(-90.0f));
            break;
        case CubeFace.NegativeY:
            m = rotationMatrix(1, degtorad(90.0f)) * translationMatrix(pos) * rotationMatrix(1, degtorad(0.0f)) * rotationMatrix(0, degtorad(90.0f));
            break;
        case CubeFace.PositiveZ:
            m = rotationMatrix(1, degtorad(90.0f)) * translationMatrix(pos) * rotationMatrix(1, degtorad(180.0f)) * rotationMatrix(2, degtorad(180.0f));
            break;
        case CubeFace.NegativeZ:
            m = rotationMatrix(1, degtorad(90.0f)) * translationMatrix(pos) * rotationMatrix(1, degtorad(0.0f)) * rotationMatrix(2, degtorad(180.0f));
            break;
        default:
            m = Matrix4x4f.identity; break;
    }
    return m;
}

Vector2f equirectProj(Vector3f dir)
{
    float phi = acos(dir.y);
    float theta = atan2(dir.x, dir.z) + PI;
    return Vector2f(theta / (PI * 2.0f), phi / PI);
}
