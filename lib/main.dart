import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:provider/provider.dart';

import 'data_model.dart';

// This needs to be a top-level method because it's run on a background isolate
DatabaseConnection _backgroundConnection() {
  final database = NativeDatabase.memory();
  return DatabaseConnection.fromExecutor(database);
}

void main() async {
  DriftIsolate isolate = await DriftIsolate.spawn(_backgroundConnection);

  runApp(MultiProvider(providers: [
    Provider<AppDb>(create: (context) {
        return AppDb.connect(DatabaseConnection.delayed(isolate.connect()));
      },
    dispose: (context, db) => db.close(),),
    Provider<SendPort>(create: (context) => isolate.connectPort,),
  ], child: const MyApp(),));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Isolate test'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final String title;

  const MyHomePage({Key? key, this.title = 'Test App'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Container(
        width: double.maxFinite,
        child: const Center(child: Text('Tap the FAB to launch an isolate and cause the error'),),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () async {
        // get the sendPort to pass to the isolate
        List<SendPort> sendPorts = [
          Provider.of<SendPort>(context, listen: false),
        ];

        final isolate = await FlutterIsolate.spawn(isolateFunction, sendPorts);
        Timer(const Duration(seconds: 10), () {isolate.kill(); print('killed isolate'); });
      },
      child: const Icon(Icons.bug_report),),
    );
  }
}

void isolateFunction(List<SendPort> arg) async {
  print('Argument to isolate function is $arg');
  DriftIsolate isolate = DriftIsolate.fromConnectPort(arg[0]);
  DatabaseConnection connection = await isolate.connect(isolateDebugLog: true);
  AppDb db = AppDb.connect(connection);

  final result = await db.todosInCategory(0).get();
  print(result);

  return;
}
