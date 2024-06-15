import 'package:flutter/material.dart';
import 'package:music_test_app/LoadLyrics.dart';
import 'package:music_test_app/test.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'Âm nhạc'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    isPlayingNotifier.addListener(() {
      if (isPlayingNotifier.value) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    isPlayingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white38,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Container(
              height: 50,
              color: Colors.deepPurple,
            ),
            Container(
              color: Colors.deepPurple,
              child: RotationTransition(
                turns: _controller,
                child: Image.asset(
                  'lib/images/cd.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: LoadLyrics(isPlayingNotifier: isPlayingNotifier),
            ),
          ],
        ),
      ),
    );
  }
}
