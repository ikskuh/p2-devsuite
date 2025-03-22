const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spin2cpp_dep = b.dependency("spin2cpp", .{
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(spin2cpp_dep.artifact("flexcc"));
    b.installArtifact(spin2cpp_dep.artifact("flexspin"));
    b.installArtifact(spin2cpp_dep.artifact("spin2cpp"));

    const install_include_step = b.addInstallDirectory(.{
        .source_dir = spin2cpp_dep.namedLazyPath("include"),
        .install_dir = .bin,
        .install_subdir = "include",
    });
    b.getInstallStep().dependOn(&install_include_step.step);

    const loadp2_dep = b.dependency("loadp2", .{
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(loadp2_dep.artifact("loadp2"));
}
