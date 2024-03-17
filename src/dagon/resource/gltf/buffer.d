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
module dagon.resource.gltf.buffer;

import std.stdio;
import std.base64;

import dlib.core.ownership;
import dlib.core.memory;
import dlib.core.stream;
import dlib.filesystem.filesystem;

class GLTFBuffer: Owner
{
    ubyte[] array;
    
    this(Owner o)
    {
        super(o);
    }
    
    void fromArray(ubyte[] arr)
    {
        array = New!(ubyte[])(arr.length);
        array[] = arr[];
    }
    
    void fromStream(InputStream istrm)
    {
        if (istrm is null)
            return;
        
        array = New!(ubyte[])(istrm.size);
        if (!istrm.fillArray(array))
        {
            writeln("Warning: failed to read buffer");
            Delete(array);
        }
    }
    
    void fromFile(ReadOnlyFileSystem fs, string filename)
    {
        FileStat fstat;
        if (fs.stat(filename, fstat))
        {
            auto bufStream = fs.openForInput(filename);
            fromStream(bufStream);
            Delete(bufStream);
        }
        else
            writeln("Warning: buffer file \"", filename, "\" not found");
    }
    
    void fromBase64(string encoded)
    {
        auto decodedLength = Base64.decodeLength(encoded.length);
        array = New!(ubyte[])(decodedLength);
        auto decoded = Base64.decode(encoded, array);
    }
    
    ~this()
    {
        if (array.length)
            Delete(array);
    }
}
