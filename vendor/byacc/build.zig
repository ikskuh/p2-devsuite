const std = @import("std");

const StringArray = []const []const u8;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const backtracking = b.option(bool, "backtracking", "Enables or disables backtracking (default: disabled") orelse false;

    const upstream_dep = b.dependency("upstream", .{});

    const byacc_config = b.addConfigHeader(
        .{
            .style = .{ .autoconf = upstream_dep.path("config_h.in") },
            .include_path = "config.h",
        },
        .{
            .GCC_NORETURN = .@"__attribute__((noreturn))",
            .GCC_PRINTF = 1,
            .GCC_PRINTFLIKE = .@"__attribute__((format(printf,fmt,var)))",
            .GCC_SCANF = 1,
            .GCC_SCANFLIKE = .@"__attribute__((format(scanf,fmt,var)))",
            .GCC_UNUSED = .@"__attribute__((unused))",
            .HAVE_FCNTL_H = true,
            .HAVE_GETOPT = true,
            .HAVE_GETOPT_H = true,
            .HAVE_GETOPT_HEADER = true,
            .HAVE_INTTYPES_H = true,
            .HAVE_LIBDBMALLOC = null,
            .HAVE_LIBDMALLOC = null,
            .HAVE_MEMORY_H = true,
            .HAVE_MKSTEMP = true,
            .HAVE_STDINT_H = true,
            .HAVE_STDLIB_H = true,
            .HAVE_STDNORETURN_H = true,
            .HAVE_STRINGS_H = true,
            .HAVE_STRING_H = true,
            .HAVE_SYS_STAT_H = true,
            .HAVE_SYS_TYPES_H = true,
            .HAVE_UNISTD_H = true,
            .HAVE_VSNPRINTF = true,
            .MAXTABLE = null,
            .MIXEDCASE_FILENAMES = true,
            .NEED_GETOPT_H = null,
            .NO_LEAKS = null,
            .STDC_HEADERS = 1,
            .STDC_NORETURN = 1,
            .SYSTEM_NAME = "linux-gnu",
            .USE_DBMALLOC = null,
            .USE_DMALLOC = null,
            .USE_VALGRIND = null,
            .YYBTYACC = 1,
            .YY_NO_LEAKS = null,
            .mode_t = null,
        },
    );

    const byacc_exe = b.addExecutable(.{
        .name = "byacc",
        .optimize = optimize,
        .target = target,
        .link_libc = true,
    });

    byacc_exe.addConfigHeader(byacc_config);
    byacc_exe.addCSourceFiles(.{
        .root = upstream_dep.path("."),
        .files = byacc_sources,
        .flags = cflags,
    });
    byacc_exe.addCSourceFile(.{
        // "$(SKELETON).c",
        .file = if (backtracking)
            upstream_dep.path("btyaccpar.c")
        else
            upstream_dep.path("yaccpar.c"),
        .flags = cflags,
    });

    b.installArtifact(byacc_exe);
}

const cflags: []const []const u8 = &.{
    "--std=gnu11",
};

const byacc_sources: []const []const u8 = &.{
    "closure.c",
    "error.c",
    "graph.c",
    "lalr.c",
    "lr0.c",
    "main.c",
    "mkpar.c",
    "mstring.c",
    "output.c",
    "reader.c",
    "symtab.c",
    "verbose.c",
    "warshall.c",
};
