const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
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
}
