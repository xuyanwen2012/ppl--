add_requires("cli11")

target("app")
    set_kind("binary")
    add_includedirs("$(projectdir)/include")
    add_headerfiles("../include/**/*", "*.cuh", "*.h", "*.hpp")
    add_files(
        "*.cu",
        "*.cpp")
    add_packages("cli11", "spdlog", "openmp", "glm")
    add_cugencodes("native")
    add_deps("ppl")
    -- for host compiler, set openmp
    add_cxxflags("-fopenmp")
    add_cuflags("-Xcompiler -fopenmp")
