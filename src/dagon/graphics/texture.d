/*
Copyright (c) 2017-2020 Timur Gafarov

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

import dlib.core.memory;
import dlib.core.ownership;
import dlib.image.color;
import dlib.image.image;
import dlib.image.hdri;
import dlib.math.vector;

import dagon.core.bindings;
import dagon.core.application;
import dagon.graphics.compressedimage;

// S3TC formats
enum GL_COMPRESSED_RGB_S3TC_DXT1_EXT = 0x83F0;  // DXT1/BC1_UNORM
enum GL_COMPRESSED_RGBA_S3TC_DXT3_EXT = 0x83F2; // DXT3/BC2_UNORM
enum GL_COMPRESSED_RGBA_S3TC_DXT5_EXT = 0x83F3; // DXT5/BC3_UNORM

// RGTC formats
enum GL_COMPRESSED_RED_RGTC1 = 0x8DBB;        // BC4_UNORM
enum GL_COMPRESSED_SIGNED_RED_RGTC1 = 0x8DBC; // BC4_SNORM
enum GL_COMPRESSED_RG_RGTC2 = 0x8DBD;         // BC5_UNORM
enum GL_COMPRESSED_SIGNED_RG_RGTC2 = 0x8DBE;  // BC5_SNORM

// BPTC formats
enum GL_COMPRESSED_RGBA_BPTC_UNORM_ARB = 0x8E8C;         // BC7_UNORM
enum GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_ARB = 0x8E8D;   // BC7_UNORM_SRGB
enum GL_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_ARB = 0x8E8E;   // BC6H_SF16
enum GL_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_ARB = 0x8E8F; // BC6H_UF16

class Texture: Owner
{
    SuperImage image;

    GLuint tex;
    GLenum format;
    GLint intFormat;
    GLenum type;

    int width;
    int height;
    int numMipmapLevels;

    Vector2f translation;
    Vector2f scale;
    float rotation;

    bool useMipmapFiltering = true;
    bool useLinearFiltering = true;

    protected bool mipmapGenerated = false;

    this(Owner owner)
    {
        super(owner);
        translation = Vector2f(0.0f, 0.0f);
        scale = Vector2f(1.0f, 1.0f);
        rotation = 0.0f;
    }

    this(SuperImage img, Owner owner, bool genMipmaps = false)
    {
        super(owner);
        translation = Vector2f(0.0f, 0.0f);
        scale = Vector2f(1.0f, 1.0f);
        rotation = 0.0f;
        createFromImage(img, genMipmaps);
    }

    void createFromImage(SuperImage img, bool genMipmaps = true)
    {
        releaseGLTexture();

        image = img;
        width = img.width;
        height = img.height;
        useMipmapFiltering = genMipmaps;

        glGenTextures(1, &tex);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, tex);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);

        CompressedImage compressedImg = cast(CompressedImage)img;
        if (compressedImg)
        {
            uint blockSize;
            uint numMipMaps = compressedImg.mipMapLevels;

            if (compressedFormatToTextureFormat(compressedImg.compressedFormat, intFormat, blockSize))
            {
                createCompressedTexture(img.data.ptr, blockSize, numMipMaps);
            }
            else
            {
                if (compressedImg.compressedFormat == CompressedImageFormat.RGBAF32)
                {
                    intFormat = GL_RGBA32F;
                    format = GL_RGBA;
                    type = GL_FLOAT;
                    createUncompressedTexture(img.data.ptr, genMipmaps);
                }
                else if (compressedImg.compressedFormat == CompressedImageFormat.RGBAF16)
                {
                    intFormat = GL_RGBA16F;
                    format = GL_RGBA;
                    type = GL_FLOAT;
                    createUncompressedTexture(img.data.ptr, genMipmaps);
                }
                else
                {
                    writeln("Unsupported compressed texture format ", compressedImg.compressedFormat);
                    createFallbackTexture();
                }
            }
        }
        else
        {
            if (!pixelFormatToTextureFormat(img.pixelFormat, format, intFormat, type))
            {
                writeln("Unsupported pixel format ", img.pixelFormat);
                createFallbackTexture();
            }
            else
            {
                createUncompressedTexture(img.data.ptr, genMipmaps);
            }
        }

        glBindTexture(GL_TEXTURE_2D, 0);
    }
    
    protected void createUncompressedTexture(ubyte* data, bool genMipmaps)
    {
        glTexImage2D(GL_TEXTURE_2D, 0, intFormat, width, height, 0, format, type, cast(void*)data);
        if (genMipmaps)
        {
            glGenerateMipmap(GL_TEXTURE_2D);
            mipmapGenerated = true;
        }
    }
    
    protected void createCompressedTexture(ubyte* data, uint blockSize, uint numMipMaps)
    {
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, numMipMaps - 1);

        uint w = width;
        uint h = height;
        uint offset = 0;
        for (uint i = 0; i < numMipMaps; i++)
        {
            uint size = ((w + 3) / 4) * ((h + 3) / 4) * blockSize;
            glCompressedTexImage2D(GL_TEXTURE_2D, i, intFormat, w, h, 0, size, cast(void*)(data + offset));
            offset += size;
            w /= 2;
            h /= 2;
        }
        
        mipmapGenerated = true;
    }

    protected void createFallbackTexture()
    {
        // TODO: make fallback texture
    }

    void bind()
    {
        if (glIsTexture(tex))
        {
            glBindTexture(GL_TEXTURE_2D, tex);

            if (!mipmapGenerated && useMipmapFiltering)
            {
                glGenerateMipmap(GL_TEXTURE_2D);
                mipmapGenerated = true;
            }

            if (useMipmapFiltering)
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
            else if (useLinearFiltering)
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            else
            {
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            }
        }
    }

    void unbind()
    {
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glBindTexture(GL_TEXTURE_2D, 0);
    }

    bool valid()
    {
        return cast(bool)glIsTexture(tex);
    }

    Color4f sample(float u, float v)
    {
        if (image)
        {
            int x = cast(int)floor(u * width);
            int y = cast(int)floor(v * height);
            return image[x, y];
        }
        else
            return Color4f(0, 0, 0, 0);
    }

    void release()
    {
        releaseGLTexture();
        if (image)
        {
            Delete(image);
            image = null;
        }
    }

    void releaseGLTexture()
    {
        if (glIsTexture(tex))
            glDeleteTextures(1, &tex);
    }

    ~this()
    {
        release();
    }
}

bool pixelFormatToTextureFormat(uint pixelFormat, out GLenum textureFormat, out GLint textureInternalFormat, out GLenum pixelType)
{
    switch (pixelFormat)
    {
        case IntegerPixelFormat.L8:    textureInternalFormat = GL_R8;      textureFormat = GL_RED;  pixelType = GL_UNSIGNED_BYTE; break;
        case IntegerPixelFormat.LA8:   textureInternalFormat = GL_RG8;     textureFormat = GL_RG;   pixelType = GL_UNSIGNED_BYTE; break;
        case IntegerPixelFormat.RGB8:  textureInternalFormat = GL_RGB8;    textureFormat = GL_RGB;  pixelType = GL_UNSIGNED_BYTE; break;
        case IntegerPixelFormat.RGBA8: textureInternalFormat = GL_RGBA8;   textureFormat = GL_RGBA; pixelType = GL_UNSIGNED_BYTE; break;
        case FloatPixelFormat.RGBAF32: textureInternalFormat = GL_RGBA32F; textureFormat = GL_RGBA; pixelType = GL_FLOAT; break;
        default:
            return false;
    }

    return true;
}

bool compressedFormatToTextureFormat(CompressedImageFormat compFormat, out GLint textureInternalFormat, out uint blockSize)
{
    switch (compFormat)
    {
        case CompressedImageFormat.S3TC_RGB_DXT1:    textureInternalFormat = GL_COMPRESSED_RGB_S3TC_DXT1_EXT;         blockSize = 8;  break;
        case CompressedImageFormat.S3TC_RGBA_DXT3:   textureInternalFormat = GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;        blockSize = 16; break;
        case CompressedImageFormat.S3TC_RGBA_DXT5:   textureInternalFormat = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;        blockSize = 16; break;
        case CompressedImageFormat.BPTC_RGBA_UNORM:  textureInternalFormat = GL_COMPRESSED_RGBA_BPTC_UNORM_ARB;       blockSize = 16; break;
        case CompressedImageFormat.BPTC_SRGBA_UNORM: textureInternalFormat = GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_ARB; blockSize = 16; break;
        default:
            return false;
    }

    return true;
}
