import 'package:build_config/build_config.dart';
import 'package:build_modules/build_modules.dart';
import 'package:build_runner/build_runner.dart';
import 'package:build_web_compilers/build_web_compilers.dart';

Iterable<BuilderApplication> getDDCApplications() {
  return [
    apply(
        'build_web_compilers|ddc',
        [
          (_) => new MetaModuleBuilder(),
          (_) => new MetaModuleCleanBuilder(),
          (_) => new ModuleBuilder(isCoarse: true),
          (_) => new UnlinkedSummaryBuilder(),
          (_) => new LinkedSummaryBuilder(),
          (_) => new DevCompilerBuilder(useKernel: false)
        ],
        toAllPackages(),
        // Recommended, but not required. This makes it so only modules that are
        // imported by entrypoints get compiled.
        isOptional: true,
        hideOutput: true),
    apply('build_web_compilers|entrypoint',
        // You can also use `WebCompiler.Dart2Js`. If you don't care about
        // dartdevc at all you may also omit the previous builder application
        // entirely.
        [(_) => new WebEntrypointBuilder(WebCompiler.DartDevc, enableSyncAsync: false)], toRoot(),
        hideOutput: true,
        // These globs should match your entrypoints only.
        defaultGenerateFor: const InputSet(
            include: const ['web/**', 'test/**.browser_test.dart'])),
  ];
}