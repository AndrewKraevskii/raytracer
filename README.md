# Simple raytracer implemented in zig

I'm trying to implement raytracer by following [this](https://matklad.github.io/2022/12/31/raytracer-construction-kit.html) article.

It uses QOI image format to store images. So if you want to try it you need to find qoi viewer (I use aseprite for that)

## Running locally 

If you want to try and run it yourself you'll need to install zig compiler (master branch).
Later you can clone repo and run it using zig compiler.
```nushell
git clone --recurse-submodules  git@github.com:AndrewKraevskii/raytracer.git
cd raytracer
zig build run
```

## Current progress (frozen)
I want to reimplement it using [mach-core](https://github.com/hexops/mach-core), but state of zig package manager and zls makes it pretty painfull. Once it is better development will continue. For now i will try it in rust + wgpu instead.

![image](https://github.com/AndrewKraevskii/raytracer/assets/75577902/032f142f-b6a4-4344-b229-8a67deea6478)
