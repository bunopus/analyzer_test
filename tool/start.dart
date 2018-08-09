import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:build_config/build_config.dart';
import 'package:build_resolvers/build_resolvers.dart';
import 'package:build_runner/build_runner.dart';
import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as io;
import 'package:source_gen/source_gen.dart';

import 'package:analyzer/src/task/dart.dart';
import 'package:analyzer/src/task/api/dart.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/context/context.dart';

import 'get_ddc_applications.dart';

final _logger = new logging.Logger('Serve');

class SimpleGenerator extends Generator {
  final AnalyzerResolvers resolvers;

  SimpleGenerator(this.resolvers);

  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    final context = resolvers.RESOLVER_CONTEXT as AnalysisContextImpl;

    final entryPoint = new AssetId('analyzer_test', 'web/main.dart');
    final asset = new AssetId('analyzer_test', 'lib/tmp_class.dart');
    final target = LibrarySpecificUnit(resolvers.RESOLVER_SOURCES[asset], resolvers.RESOLVER_SOURCES[asset]);

    final entry2 = context.getCacheEntry(target);
    entry2.setState(COMPILATION_UNIT_CONSTANTS, CacheState.INVALID);
    entry2.setState(RESOLVED_UNIT1, CacheState.INVALID);
    entry2.setState(CREATED_RESOLVED_UNIT1, CacheState.INVALID);

    // Now we are forcing resolver to call BuildCompilationUnitElementTask and ResolveUnitTypeNamesTask once more
    // In real project them are called to due to cache flush
    await buildStep.resolver.libraryFor(entryPoint);

    return '''
      import 'dart:html';
      import 'main.dart';
    
      void main() {
          document.body.innerHtml = "It's generated code<br/>\\n"
            "";
      }
    ''';
  }
}

Future main(List<String> args) async {
  final analyzerResolvers = new AnalyzerResolvers();
  final buildRunnerHandler = await watch(
      [
        apply(
            'LibraryBuilder',
            [(_) =>
            new LibraryBuilder(
                new SimpleGenerator(analyzerResolvers),
                generatedExtension: '.index.dart'
            )
            ],
            toRoot(),
            defaultGenerateFor: new InputSet(include: ['web/main.dart']),
            hideOutput: true),
      ]
        ..addAll(getDDCApplications()),
      deleteFilesByDefault: true,
      packageGraph: new PackageGraph.forThisPackage(),
      buildDirs: ['web', 'lib'],
      resolvers: analyzerResolvers
  );

  final String relativeWeb = p.relative('web', from: new Directory('').path);

  final handler = buildRunnerHandler.handlerFor(relativeWeb);

  final HttpServer server = await io.serve(handler, '0.0.0.0', 8081);

  final BuildResult buildResult = await buildRunnerHandler.currentBuild;

  if (buildResult.status == BuildStatus.failure) {
    exit(5);
  }

  _logger.info('Application is serving at http://localhost:8080');

  await buildRunnerHandler.buildResults.drain<dynamic>();
  await server.close();
}