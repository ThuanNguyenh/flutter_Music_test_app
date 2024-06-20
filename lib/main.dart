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

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
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
      backgroundColor: const Color(0xFF34224F),
      body: Center(
        child: Column(
          children: <Widget>[
            Container(
              color: const Color(0xFF34224F),
              padding: const EdgeInsets.only(top: 100),
              child: RotationTransition(
                turns: _controller,
                child: Image.asset(
                  'lib/images/cd.png',
                  fit: BoxFit.cover,
                  color: Colors.white38,
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
