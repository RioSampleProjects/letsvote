import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart' as shelf_static;
import 'package:shelf_route/shelf_route.dart' as shelf_route;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors/shelf_cors.dart' as shelf_cors;
import 'package:letsvote_web/server.dart' as letsvote;

void main(List<String> args) {
  // Get the path to this app's static HTML and other generated files. Assumes
  // the server lives in bin/ and that `pub build` ran
  var pathToBuild =
      path.join(path.dirname(Platform.script.toFilePath()), '..', 'build/web');

  Handler staticHandler;
  try {
    staticHandler = shelf_static.createStaticHandler(pathToBuild,
        defaultDocument: 'index.html');
  } catch(e) {
    // support running without a build/ directory
  }

  var portEnv = Platform.environment['PORT'];
  var port = portEnv == null ? 9999 : int.parse(portEnv);

  var parser = new ArgParser()..addOption('port', abbr: 'p', defaultsTo: null);

  var result = parser.parse(args);

  // Override port env var with -p flag
  if (result['port'] != null) {
    port = int.parse(result['port'], onError: (val) {
      stdout.writeln('Could not parse port value "$val" into a number.');
      exit(1);
    });
  }

  var appRouter = shelf_route.router();

  var server = new letsvote.Server();
  server.configureRoutes(appRouter);

  var pipeline = new shelf.Pipeline();
  var cascade = new shelf.Cascade();
  if (staticHandler != null) {
    cascade = cascade.add(staticHandler);
  }
  cascade = cascade.add(appRouter.handler);

  var corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET,HEAD,POST,PUT,PATCH,DELETE,OPTIONS,'
  };
  var corsMiddleware =
      shelf_cors.createCorsHeadersMiddleware(corsHeaders: corsHeaders);
  pipeline = pipeline.addMiddleware(corsMiddleware);
  var handler = pipeline.addHandler(cascade.handler);

  io.serve(handler, '0.0.0.0', port).then((server) {
    print('Serving at http://${server.address.host}:${server.port}');
  });
}

shelf.Middleware createHttpsOnlyMiddleware() {
  return shelf.createMiddleware(requestHandler: (shelf.Request request) {
    if (request.requestedUri.scheme != "https") {
      return new shelf.Response.movedPermanently(
          request.requestedUri.replace(scheme: "https"));
    }
    return null;
  });
}
