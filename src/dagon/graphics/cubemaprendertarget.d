/*
Copyright (c) 2019 Timur Gafarov

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

module dagon.graphics.cubemaprendertarget;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.image.color;

import dagon.core.libs;
import dagon.core.ownership;
import dagon.graphics.framebuffer;
import dagon.graphics.gbuffer;
import dagon.graphics.cubemap;
import dagon.graphics.rc;

class CubemapRenderTarget: RenderTarget
{
    GBuffer gbuffer;
    GLuint fbo;
    GLuint depthTexture = 0;

    this(uint res, Owner o)
    {
        super(res, res, o);

        gbuffer = New!GBuffer(res, res, this);

        glActiveTexture(GL_TEXTURE0);

        glGenTextures(1, &depthTexture);
        glBindTexture(GL_TEXTURE_2D, depthTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH24_STENCIL8, res, res, 0, GL_DEPTH_STENCIL, GL_UNSIGNED_INT_24_8, null);
        glBindTexture(GL_TEXTURE_2D, 0);

        glGenFramebuffers(1, &fbo);
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, depthTexture, 0);
        GLenum[1] bufs = [GL_COLOR_ATTACHMENT0];
        glDrawBuffers(1, bufs.ptr);

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

    ~this()
    {
        if (glIsTexture(depthTexture))
            glDeleteTextures(1, &depthTexture);

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glDeleteFramebuffers(1, &fbo);
    }

    override void bind()
    {
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    }

    override void unbind()
    {
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

    override void clear(Color4f clearColor)
    {
        glClearColor(clearColor.r, clearColor.g, clearColor.b, 0.0f);
        glClear(GL_DEPTH_BUFFER_BIT);
        Color4f zero = Color4f(0, 0, 0, 0);
        glClearBufferfv(GL_COLOR, 0, zero.arrayof.ptr);
    }

    void setCubemapFace(Cubemap cubemap, CubeFace face)
    {
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, face, cubemap.tex, 0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

    void prepareRC(CubeFace face, Vector3f position, RenderingContext* rc)
    {
        rc.prevViewMatrix = rc.viewMatrix;
        
        rc.invViewMatrix = cubeFaceCameraMatrix(face, position);
        rc.viewMatrix = rc.invViewMatrix.inverse;

        rc.modelViewMatrix = rc.viewMatrix;
        rc.normalMatrix = rc.invViewMatrix.transposed;
        rc.cameraPosition = position;
        Matrix4x4f mvp = rc.projectionMatrix * rc.viewMatrix;
        rc.frustum.fromMVP(mvp);

        rc.prevCameraPosition = position;

        rc.viewRotationMatrix = matrix3x3to4x4(matrix4x4to3x3(rc.viewMatrix));
        rc.invViewRotationMatrix = matrix3x3to4x4(matrix4x4to3x3(rc.invViewMatrix));
    }
}
