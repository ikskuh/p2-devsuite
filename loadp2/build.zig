const std = @import("std");

const StringArray = []const []const u8;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spin2cpp_dep = b.dependency("spin2cpp", .{});
    const flexspin_exe = spin2cpp_dep.artifact("flexspin");

    const upstream_dep = b.dependency("upstream", .{});

    const upstream = upstream_dep.path(".");

    const fake_xxd = b.addExecutable(.{
        .name = "fake-xxd",
        .optimize = .ReleaseSafe,
        .root_source_file = b.path("src/fake-xxd.zig"),
        .target = b.graph.host,
    });

    const p2es_flashloader_bin = blk: {
        const assemble_step = b.addRunArtifact(flexspin_exe);
        assemble_step.addArg("-2");
        assemble_step.addArg("-I");
        assemble_step.addDirectoryArg(spin2cpp_dep.namedLazyPath("include"));
        assemble_step.addArg("-o");
        const output = assemble_step.addOutputFileArg("P2ES_flashloader.bin");
        assemble_step.addFileArg(upstream_dep.path("board/P2ES_flashloader.spin2"));
        break :blk output;
    };

    const p2es_sdcard_bin = blk: {
        const assemble_step = b.addRunArtifact(flexspin_exe);
        assemble_step.addArg("-2");
        assemble_step.addArg("-I");
        assemble_step.addDirectoryArg(spin2cpp_dep.namedLazyPath("include"));
        assemble_step.addArg("-o");
        const output = assemble_step.addOutputFileArg("sdboot.binary");
        assemble_step.addFileArg(upstream_dep.path("board/sdcard/sdboot.c"));
        assemble_step.addFileArg(upstream_dep.path("board/sdcard/ff.c"));
        assemble_step.addFileArg(upstream_dep.path("board/sdcard/sdmm.c"));

        break :blk output;
    };

    const install_p2es_flashloader_bin = b.addInstallFileWithDir(
        p2es_flashloader_bin,
        .{ .custom = "board" },
        "P2ES_flashloader.bin",
    );
    b.getInstallStep().dependOn(&install_p2es_flashloader_bin.step);

    const install_p2es_sdcard_bin = b.addInstallFileWithDir(
        p2es_sdcard_bin,
        .{ .custom = "board" },
        "P2ES_sdcard.bin",
    );
    b.getInstallStep().dependOn(&install_p2es_sdcard_bin.step);

    const base_names: [4][]const u8 = .{
        "MainLoader_chip",
        "flash_loader",
        "himem_flash",
        "flash_stub",
    };

    const spin_files: [4]std.Build.LazyPath = .{
        upstream_dep.path(base_names[0] ++ ".spin2"),
        upstream_dep.path(base_names[1] ++ ".spin2"),
        upstream_dep.path(base_names[2] ++ ".spin2"),
        upstream_dep.path(base_names[3] ++ ".spin2"),
    };

    const blob_files: [spin_files.len]std.Build.LazyPath = blk: {
        var blob_files: [spin_files.len]std.Build.LazyPath = undefined;
        for (&blob_files, spin_files, base_names) |*output, input, name| {
            const assemble_step = b.addRunArtifact(flexspin_exe);
            assemble_step.addArg("-2");
            assemble_step.addArg("-o");
            output.* = assemble_step.addOutputFileArg(
                b.fmt("{s}.bin", .{name}),
            );
            assemble_step.addFileArg(input);
        }
        break :blk blob_files;
    };

    const header_files: [blob_files.len]std.Build.LazyPath = blk: {
        var header_files: [blob_files.len]std.Build.LazyPath = undefined;

        for (&header_files, blob_files, base_names) |*output, input, name| {
            const convert = b.addRunArtifact(fake_xxd);
            convert.addFileArg(input);

            output.* = convert.addOutputFileArg(
                b.fmt("{s}.h", .{name}),
            );
        }

        break :blk header_files;
    };

    const cflags: []const []const u8 = &.{
        "-Wall",
    };

    const os_file = switch (target.result.os.tag) {
        .windows => "osint_mingw.c",
        else => "osint_linux.c",
    };

    const loadp2_exe = b.addExecutable(.{
        .name = "loadp2",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (target.result.os.tag.isDarwin()) {
        loadp2_exe.root_module.addCMacro("MACOSX", "");
    }

    for (header_files) |header| {
        loadp2_exe.addIncludePath(header.dirname());
    }

    loadp2_exe.addCSourceFiles(.{
        .root = upstream,
        .files = loadp2_sources ++ u9fs_sources ++ &[_][]const u8{os_file},
        .flags = cflags,
    });

    b.installArtifact(loadp2_exe);
}

const loadp2_sources: []const []const u8 = &.{
    "loadp2.c",
    "loadelf.c",
};

const u9fs_sources: []const []const u8 = &.{
    "u9fs/u9fs.c",
    "u9fs/authnone.c",
    "u9fs/print.c",
    "u9fs/doprint.c",
    "u9fs/rune.c",
    "u9fs/fcallconv.c",
    "u9fs/dirmodeconv.c",
    "u9fs/convM2D.c",
    "u9fs/convS2M.c",
    "u9fs/convD2M.c",
    "u9fs/convM2S.c",
    "u9fs/readn.c",
};

// # board support programs
// BOARDS=board/P2ES_flashloader.bin board/P2ES_sdcard.bin

// # program for converting MainLoader.spin2 to MainLoader.binary
// P2ASM=flexspin -2

// # docs
// DOCS=README.md LICENSE

// # signing programs
// SIGNPC ?= ./sign.dummy.sh
// SIGNMAC ?= /bin/echo

// %.h: %.bin
//       xxd -i $< $@

// loadp2.linux:
//       make CROSS=linux32
//       cp build-linux32/loadp2 ./loadp2.linux
// loadp2.exe:
//       make CROSS=win32
//       $(SIGNPC) build-win32/loadp2
//       cp build-win32/loadp2.signed.exe ./loadp2.exe
// loadp2.mac:
//       make CROSS=macosx
//       $(SIGNMAC) build-macosx/loadp2
//       cp build-macosx/loadp2 ./loadp2.mac

// zip: loadp2.exe loadp2.linux loadp2.mac
//       zip -r loadp2.zip loadp2.exe loadp2.mac loadp2.linux $(DOCS) board
