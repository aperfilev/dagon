/*
Copyright (c) 2021-2024 Timur Gafarov

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
module dagon.resource.gltf.meshprimitive;

import std.stdio;

import dlib.core.ownership;

import dagon.core.bindings;
import dagon.graphics.drawable;
import dagon.graphics.material;
import dagon.graphics.mesh;
import dagon.graphics.state;
import dagon.resource.gltf.accessor;

class GLTFMeshPrimitive: Owner, Drawable
{
    GLTFAccessor positionAccessor;
    GLTFAccessor normalAccessor;
    GLTFAccessor texCoord0Accessor;
    GLTFAccessor joints0Accessor;
    GLTFAccessor weights0Accessor;
    GLTFAccessor indexAccessor;
    Material material;
    
    GLuint vao = 0;
    GLuint vbo = 0;
    GLuint nbo = 0;
    GLuint tbo = 0;
    GLuint jbo = 0;
    GLuint wbo = 0;
    GLuint eao = 0;
    
    bool canRender = false;
    
    bool hasJoints = false;
    bool hasWeights = false;
    
    this(Owner o)
    {
        super(o);
    }
    
    void prepareVAO()
    {
        if (positionAccessor is null || 
            normalAccessor is null || 
            texCoord0Accessor is null || 
            indexAccessor is null)
            return;
        
        if (positionAccessor.bufferView.slice.length == 0)
            return;
        if (normalAccessor.bufferView.slice.length == 0)
            return;
        if (texCoord0Accessor.bufferView.slice.length == 0)
            return;
        if (indexAccessor.bufferView.slice.length == 0)
            return;
        
        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, positionAccessor.bufferView.slice.length, positionAccessor.bufferView.slice.ptr, GL_STATIC_DRAW); 
        
        glGenBuffers(1, &nbo);
        glBindBuffer(GL_ARRAY_BUFFER, nbo);
        glBufferData(GL_ARRAY_BUFFER, normalAccessor.bufferView.slice.length, normalAccessor.bufferView.slice.ptr, GL_STATIC_DRAW);
        
        glGenBuffers(1, &tbo);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glBufferData(GL_ARRAY_BUFFER, texCoord0Accessor.bufferView.slice.length, texCoord0Accessor.bufferView.slice.ptr, GL_STATIC_DRAW);
        
        if (joints0Accessor && joints0Accessor.bufferView.slice.length > 0)
        {
            glGenBuffers(1, &jbo);
            glBindBuffer(GL_ARRAY_BUFFER, jbo);
            glBufferData(GL_ARRAY_BUFFER, joints0Accessor.bufferView.slice.length, joints0Accessor.bufferView.slice.ptr, GL_STATIC_DRAW);
            hasJoints = true;
        }
        
        if (weights0Accessor && weights0Accessor.bufferView.slice.length > 0)
        {
            glGenBuffers(1, &wbo);
            glBindBuffer(GL_ARRAY_BUFFER, wbo);
            glBufferData(GL_ARRAY_BUFFER, weights0Accessor.bufferView.slice.length, weights0Accessor.bufferView.slice.ptr, GL_STATIC_DRAW);
            hasWeights = true;
        }
        
        glGenBuffers(1, &eao);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eao);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexAccessor.bufferView.slice.length, indexAccessor.bufferView.slice.ptr, GL_STATIC_DRAW);
        
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        
        glEnableVertexAttribArray(VertexAttrib.Vertices);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(VertexAttrib.Vertices, positionAccessor.numComponents, positionAccessor.componentType, GL_FALSE, positionAccessor.bufferView.stride, cast(void*)positionAccessor.byteOffset);
        
        glEnableVertexAttribArray(VertexAttrib.Normals);
        glBindBuffer(GL_ARRAY_BUFFER, nbo);
        glVertexAttribPointer(VertexAttrib.Normals, normalAccessor.numComponents, normalAccessor.componentType, GL_FALSE, normalAccessor.bufferView.stride, cast(void*)normalAccessor.byteOffset);
        
        glEnableVertexAttribArray(VertexAttrib.Texcoords);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glVertexAttribPointer(VertexAttrib.Texcoords, texCoord0Accessor.numComponents, texCoord0Accessor.componentType, GL_FALSE, texCoord0Accessor.bufferView.stride, cast(void*)texCoord0Accessor.byteOffset);
        
        if (hasJoints)
        {
            glEnableVertexAttribArray(VertexAttrib.Joints);
            glBindBuffer(GL_ARRAY_BUFFER, jbo);
            glVertexAttribPointer(VertexAttrib.Joints, joints0Accessor.numComponents, joints0Accessor.componentType, GL_FALSE, joints0Accessor.bufferView.stride, cast(void*)joints0Accessor.byteOffset);
        }
        
        if (hasWeights)
        {
            glEnableVertexAttribArray(VertexAttrib.Weights);
            glBindBuffer(GL_ARRAY_BUFFER, wbo);
            glVertexAttribPointer(VertexAttrib.Weights, weights0Accessor.numComponents, weights0Accessor.componentType, GL_FALSE, weights0Accessor.bufferView.stride, cast(void*)weights0Accessor.byteOffset);
        }
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eao);
        
        glBindVertexArray(0);
        
        canRender = true;
    }
    
    void render(GraphicsState* state)
    {
        if (canRender)
        {
            glBindVertexArray(vao);
            glDrawElements(GL_TRIANGLES, indexAccessor.count, indexAccessor.componentType, cast(void*)indexAccessor.byteOffset);
            glBindVertexArray(0);
        }
    }
    
    ~this()
    {
        if (canRender)
        {
            glDeleteVertexArrays(1, &vao);
            glDeleteBuffers(1, &vbo);
            glDeleteBuffers(1, &nbo);
            glDeleteBuffers(1, &tbo);
            if (hasJoints)
                glDeleteBuffers(1, &jbo);
            if (hasWeights)
                glDeleteBuffers(1, &wbo);
            glDeleteBuffers(1, &eao);
        }
    }
}