namespace GameOfLife3D.NET;

class Program
{
    static void Main(string[] args)
    {
        // On Linux (e.g. Raspberry Pi 5), Mesa's V3D driver reports GL 3.1 max,
        // but the hardware supports all GL 3.3 features via extensions.
        // Silk.NET.OpenGL.Extensions.ImGui has hardcoded #version 330 shaders,
        // so we override Mesa's reported version to allow them to compile.
        if (OperatingSystem.IsLinux())
        {
            Environment.SetEnvironmentVariable("MESA_GL_VERSION_OVERRIDE", "3.3");
            Environment.SetEnvironmentVariable("MESA_GLSL_VERSION_OVERRIDE", "330");
        }

        using var app = new App();
        app.Run();
    }
}
