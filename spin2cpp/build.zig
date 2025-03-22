const std = @import("std");

const StringArray = []const []const u8;

pub const YaccVersion = enum {
    bison3,
    bison2,
    byacc,
};

pub const YaccInfo = struct {
    run: []const []const u8,
    spinprefix: []const []const u8,
    basicprefix: []const []const u8,
    cprefix: []const []const u8,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const install_testlex = b.option(bool, "testlex", "Builds testlex also in release modes") orelse false;

    const yacc_check = b.option(bool, "yacc-check", "Prints detected YACC version and params") orelse false;
    const yacc_ver = b.option(YaccVersion, "yacc-version", "Selects the version of YACC to use") orelse .bison3;

    const yacc_exe = switch (yacc_ver) {
        .bison2, .bison3 => "bison",
        .byacc => "byacc",
    };

    // ifndef YACCVER
    // YACC_CHECK := $(shell $(YACC) --version | fgrep 3.)
    // ifeq ($(YACC_CHECK),)
    //     ifeq ($(YACC),byacc)
    //       YACCVER=byacc
    //     else
    //       YACCVER=bison2
    //     endif
    // else
    //     YACCVER=bison3
    // endif
    // endif

    // TODO: Implement YACC auto-detection!

    const yacc: YaccInfo = switch (yacc_ver) {
        .bison3 => .{
            .run = &.{ yacc_exe, "-Wno-deprecated", "-D", "parse.error=verbose" },
            .spinprefix = &.{ "-D", "api.prefix={spinyy}" },
            .basicprefix = &.{ "-D", "api.prefix={basicyy}" },
            .cprefix = &.{ "-D", "api.prefix={cgramyy}" },
        },
        .bison2 => .{
            .run = &.{yacc_exe},
            .spinprefix = &.{ "-p", "spinyy" },
            .basicprefix = &.{ "-p", "basicyy" },
            .cprefix = &.{ "-p", "cgramyy" },
        },
        .byacc => .{
            .run = &.{ yacc_exe, "-s" },
            .spinprefix = &.{ "-p", "spinyy" },
            .basicprefix = &.{ "-p", "basicyy" },
            .cprefix = &.{ "-p", "cgramyy" },
        },
    };

    if (yacc_check) {
        std.debug.print("YACC prefix  = '{s}'\n", .{yacc.run});
        std.debug.print("YACC version = '{s}'\n", .{@tagName(yacc_ver)});
        return;
    }

    const upstream_dep = b.dependency("upstream", .{});

    const upstream = upstream_dep.path(".");

    const spin_tab_c: std.Build.LazyPath = blk: {
        // $(BUILD)/spin.tab.c $BUILD)/spin.tab.h: frontends/spin/spin.y
        //       $(RUNYACC) $(YY_SPINPREFIX) -t -b $(BUILD)/spin -d frontends/spin/spin.y

        const gen_spin_tab = b.addSystemCommand(yacc.run);
        gen_spin_tab.addArgs(yacc.spinprefix);
        gen_spin_tab.addArg("-t");
        gen_spin_tab.addArg("-b");
        const output = gen_spin_tab.addOutputFileArg("spin");
        gen_spin_tab.addArg("-d");
        gen_spin_tab.addFileArg(upstream.path(b, "frontends/spin/spin.y"));

        break :blk output.dirname().path(b, "spin.tab.c");
    };
    const basic_tab_c: std.Build.LazyPath = blk: {
        // $(BUILD)/basic.tab.c $(BUILD)/basic.tab.h: frontends/basic/basic.y
        //       $(RUNYACC) $(YY_BASICPREFIX) -t -b $(BUILD)/basic -d frontends/basic/basic.y

        const gen_basic_tab = b.addSystemCommand(yacc.run);
        gen_basic_tab.addArgs(yacc.basicprefix);
        gen_basic_tab.addArg("-t");
        gen_basic_tab.addArg("-b");
        const output = gen_basic_tab.addOutputFileArg("basic");
        gen_basic_tab.addArg("-d");
        gen_basic_tab.addFileArg(upstream.path(b, "frontends/basic/basic.y"));

        break :blk output.dirname().path(b, "basic.tab.c");
    };
    const cgram_tab_c: std.Build.LazyPath = blk: {
        // $(BUILD)/cgram.tab.c $(BUILD)/cgram.tab.h: frontends/c/cgram.y
        //       $(RUNYACC) $(YY_CPREFIX) -t -b $(BUILD)/cgram -d frontends/c/cgram.y

        const gen_cgram_tab = b.addSystemCommand(yacc.run);
        gen_cgram_tab.addArgs(yacc.cprefix);
        gen_cgram_tab.addArg("-t");
        gen_cgram_tab.addArg("-b");
        const output = gen_cgram_tab.addOutputFileArg("cgram");
        gen_cgram_tab.addArg("-d");
        gen_cgram_tab.addFileArg(upstream.path(b, "frontends/c/cgram.y"));

        break :blk output.dirname().path(b, "cgram.tab.c");
    };

    const include_paths: []const std.Build.LazyPath = &.{
        // include paths from upstream:
        upstream_dep.path("."), // -I .
        upstream_dep.path("backends"), // -I./backends
        upstream_dep.path("frontends"), // -I./frontends

        // include paths for generated files:
        spin_tab_c.dirname(), // -I$(BUILD)
        basic_tab_c.dirname(), // -I$(BUILD)
        cgram_tab_c.dirname(), // -I$(BUILD)
    };

    const compile_defines: StringArray = &.{
        "FLEXSPIN_BUILD",
    };
    const cflags: StringArray = &.{
        "-Wall", "-fwrapv", "-Wc++-compat",
    };

    {
        const testlex_exe = b.addExecutable(.{
            .name = "testlex",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        for (include_paths) |path|
            testlex_exe.addIncludePath(path);
        for (compile_defines) |define|
            testlex_exe.root_module.addCMacro(define, "");

        testlex_exe.addCSourceFiles(.{
            .root = upstream,
            .files = lex_sources ++ &[_][]const u8{"testlex.c"},
            .flags = cflags,
        });

        if (optimize == .Debug or install_testlex)
            b.installArtifact(testlex_exe);
    }

    {
        const spin2cpp_exe = b.addExecutable(.{
            .name = "spin2cpp",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        for (include_paths) |path|
            spin2cpp_exe.addIncludePath(path);
        for (compile_defines) |define|
            spin2cpp_exe.root_module.addCMacro(define, "");

        spin2cpp_exe.addCSourceFiles(.{
            .root = upstream,
            .files = spin_sources ++ &[_][]const u8{ "spin2cpp.c", "cmdline.c" },
            .flags = cflags,
        });

        spin2cpp_exe.addCSourceFile(.{ .file = spin_tab_c, .flags = cflags });
        spin2cpp_exe.addCSourceFile(.{ .file = basic_tab_c, .flags = cflags });
        spin2cpp_exe.addCSourceFile(.{ .file = cgram_tab_c, .flags = cflags });

        b.installArtifact(spin2cpp_exe);
    }

    {
        const flexspin_exe = b.addExecutable(.{
            .name = "flexspin",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        for (include_paths) |path|
            flexspin_exe.addIncludePath(path);
        for (compile_defines) |define|
            flexspin_exe.root_module.addCMacro(define, "");

        flexspin_exe.addCSourceFiles(.{
            .root = upstream,
            .files = spin_sources ++ &[_][]const u8{ "flexspin.c", "cmdline.c" },
            .flags = cflags,
        });

        flexspin_exe.addCSourceFile(.{ .file = spin_tab_c, .flags = cflags });
        flexspin_exe.addCSourceFile(.{ .file = basic_tab_c, .flags = cflags });
        flexspin_exe.addCSourceFile(.{ .file = cgram_tab_c, .flags = cflags });

        b.installArtifact(flexspin_exe);
    }

    {
        const flexcc_exe = b.addExecutable(.{
            .name = "flexcc",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        for (include_paths) |path|
            flexcc_exe.addIncludePath(path);
        for (compile_defines) |define|
            flexcc_exe.root_module.addCMacro(define, "");

        flexcc_exe.addCSourceFiles(.{
            .root = upstream,
            .files = spin_sources ++ &[_][]const u8{ "flexcc.c", "cmdline.c" },
            .flags = cflags,
        });

        flexcc_exe.addCSourceFile(.{ .file = spin_tab_c, .flags = cflags });
        flexcc_exe.addCSourceFile(.{ .file = basic_tab_c, .flags = cflags });
        flexcc_exe.addCSourceFile(.{ .file = cgram_tab_c, .flags = cflags });

        b.installArtifact(flexcc_exe);
    }
}

// OBJS = $(SPINOBJS) $(BUILD)/spin.tab.o $(BUILD)/basic.tab.o $(BUILD)/cgram.tab.o

const util_sources: StringArray = &.{
    "util/dofmt.c",
    "util/flexbuf.c",
    "util/lltoa_prec.c",
    "util/strupr.c",
    "util/strrev.c",
    "util/strdupcat.c",
    "util/to_utf8.c",
    "util/from_utf8.c",
    "util/sha256.c",
};
const mcpp_sources: StringArray = &.{
    "mcpp/directive.c",
    "mcpp/expand.c",
    "mcpp/mbchar.c",
    "mcpp/mcpp_eval.c",
    "mcpp/mcpp_main.c",
    "mcpp/mcpp_system.c",
    "mcpp/mcpp_support.c",
};

const lex_sources: StringArray = util_sources ++ &[_][]const u8{
    "frontends/lexer.c",
    "frontends/uni2sjis.c",
    "symbol.c",
    "ast.c",
    "expr.c",
    "preprocess.c",
};

const pasmback_sources: StringArray = &.{
    "backends/asm/outasm.c",
    "backends/asm/assemble_ir.c",
    "backends/asm/optimize_ir.c",
    "backends/asm/asm_peep.c",
    "backends/asm/inlineasm.c",
    "backends/asm/compress_ir.c",
};

const bcback_sources: StringArray = &.{
    "backends/bytecode/outbc.c",
    "backends/bcbuffers.c",
    "backends/bytecode/bcir.c",
    "backends/bytecode/bc_spin1.c",
};

const nuback_sources: StringArray = &.{
    "backends/nucode/outnu.c",
    "backends/nucode/nuir.c",
    "backends/nucode/nupeep.c",
};

const cppback_sources: StringArray = &.{
    "backends/cpp/outcpp.c",
    "backends/cpp/cppfunc.c",
    "backends/cpp/outgas.c",
    "backends/cpp/cppexpr.c",
    "backends/cpp/cppbuiltin.c",
};

const compback_sources: StringArray = &.{
    "backends/compress/compress.c",
    "backends/compress/lz4/lz4.c",
    "backends/compress/lz4/lz4hc.c",
};

const zipback_sources: StringArray = &.{
    "backends/zip/outzip.c",
    "backends/zip/zip.c",
};

const spin_sources: StringArray = &[_][]const u8{
    "frontends/common.c",
    "frontends/case.c",
    "spinc.c",
    "functions.c",
    "cse.c",
    "loops.c",
    "frontends/hloptimize.c",
    "frontends/hltransform.c",
    "frontends/types.c",
    "pasm.c",
    "backends/dat/outdat.c",
    "backends/dat/outlst.c",
    "backends/objfile/outobj.c",
    "frontends/spin/spinlang.c",
    "frontends/basic/basiclang.c",
    "frontends/c/clang.c",
    "frontends/bf/bflang.c",
    "version.c",
    "backends/becommon.c",
    "backends/brkdebug.c",
    "frontends/printdebug.c",
} ++
    lex_sources ++
    pasmback_sources ++
    bcback_sources ++
    nuback_sources ++
    cppback_sources ++
    compback_sources ++
    zipback_sources ++
    mcpp_sources;

// # the script used to turn foo.exe into foo.signed.exe
// SIGN ?= ./sign.dummy.sh

// preproc: preprocess.c $(UTIL)
//       $(CC) $(CFLAGS) -DTESTPP -o $@ $^ $(LIBS)

// test_offline: lextest asmtest bctest cpptest errtest p2test
// test: test_offline runtest
// #test: lextest asmtest cpptest errtest runtest
// lextest: $(PROGS)
//       $(BUILD)/testlex

// asmtest: $(PROGS)
//       (cd Test; ./asmtests.sh)

// bctest: $(PROGS)
//       (cd Test; ./bctests.sh)

// cpptest: $(PROGS)
//       (cd Test; ./cpptests.sh)

// errtest: $(PROGS)
//       (cd Test; ./errtests.sh)

// p2test: $(PROGS)
//       (cd Test; ./p2bin.sh)

// runtest: $(PROGS)
//       (cd Test; ./runtests_p2.sh)

// test_spinsim:  $(PROGS)
//       (cd Test/spinsim; make)
//       (cd Test; ./runtests_p1.sh "" "./spinsim/build/spinsim -b -q")
//       (cd Test; ./runtests_bc.sh "" "./spinsim/build/spinsim -b -q")

// $(BUILD)/version.o: version.c version.h FORCE
//       $(eval gitbranch=$(shell git rev-parse --abbrev-ref HEAD))
//       $(CC) $(CFLAGS) -DGITREV=$(shell git describe --tags --always) $(if $(filter release/%,$(patsubst master,release/master,$(gitbranch))),,-DGITBRANCH=$(gitbranch)) -o $@ -c $<

// #
// # convert a .spin file to a header file
// # note that xxd does not 0 terminate its generated string,
// # which is what the sed script will do
// #
// sys/%.spin.h: sys/%.spin
//       xxd -i $< $@
// sys/%.bas.h: sys/%.bas
//       xxd -i $< $@

// COMMONDOCS=COPYING Changelog.txt doc
// ALLDOCS=README.md Flexspin.md $(COMMONDOCS)

// zip: all

// ifeq ($(CROSS),win32)
//       $(SIGN) $(BUILD)/flexspin
//       mv $(BUILD)/flexspin.signed.exe $(BUILD)/flexspin.exe
//       $(SIGN) $(BUILD)/flexcc
//       mv $(BUILD)/flexcc.signed.exe $(BUILD)/flexcc.exe
// endif
//       zip -r flexptools.zip $(BUILD)/spin2cpp$(EXT) $(BUILD)/flexcc$(EXT) $(BUILD)/flexspin$(EXT) $(ALLDOCS) include
// # I could not make this work in one command idk
//       printf "@ $(BUILD)/spin2cpp$(EXT)\n@=bin/spin2cpp$(EXT)\n" | zipnote -w flexptools.zip
//       printf "@ $(BUILD)/flexcc$(EXT)\n@=bin/flexcc$(EXT)\n" | zipnote -w flexptools.zip
//       printf "@ $(BUILD)/flexspin$(EXT)\n@=bin/flexspin$(EXT)\n" | zipnote -w flexptools.zip

// # target to build preprocessor
// preprocess: preprocess.c util/flexbuf.c util/dofmt.c util/strupr.c util/strrev.c util/lltoa_prec.c
//       $(CC) -o $@ -g -DTESTPP $^ -lm
