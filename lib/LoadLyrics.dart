import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_model_builder.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class Lyric {
  final String text;
  final double timestamp;

  Lyric({required this.text, required this.timestamp});
}

Future<List<List<Lyric>>> fetchLyrics(String url) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final document = xml.XmlDocument.parse(utf8.decode(response.bodyBytes));
    final lyricsData = <List<Lyric>>[];

    for (final param in document.findAllElements('param')) {
      final paramLyrics = <Lyric>[];
      for (final item in param.findAllElements('i')) {
        final text = item.text;
        final timestamp = double.parse(item.getAttribute('va')!);
        paramLyrics.add(Lyric(text: text, timestamp: timestamp));
      }
      lyricsData.add(paramLyrics);
    }

    return lyricsData;
  } else {
    throw Exception('Failed to load lyrics');
  }
}

String createLyricModel(List<List<Lyric>> lyrics) {
  final List<String> lyricLines = [];

  for (final line in lyrics) {
    if (line.isEmpty) continue;

    final mainText = StringBuffer();
    double startTime = line.first.timestamp * 1000;

    for (final lyric in line) {
      mainText.write(lyric.text);
    }

    lyricLines.add(
        '${_formatDuration(Duration(milliseconds: startTime.toInt()))}$mainText');

    // lyricLines.add(
    //   '[${Duration(milliseconds: startTime.toInt())}]$mainText'
    // );
  }
  print(lyricLines.join('\n'));
  return lyricLines.join('\n');
}

// format thời gian đến mili giây
String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds =
      (duration.inSeconds.remainder(60) % 60).toString().padLeft(2, '0');
  final milliseconds =
      (duration.inMilliseconds % 1000).toString().padLeft(3, '0');

  return '[$minutes:$seconds.$milliseconds]';
}

// format thời gian đến phút - giây
String _formatMinDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  return '$twoDigitMinutes:$twoDigitSeconds';
}

class LoadLyrics extends StatefulWidget {
  final ValueNotifier<bool> isPlayingNotifier;

  const LoadLyrics({Key? key, required this.isPlayingNotifier})
      : super(key: key);

  @override
  _LoadLyricsState createState() => _LoadLyricsState();
}

class _LoadLyricsState extends State<LoadLyrics>
    with SingleTickerProviderStateMixin {
  final AudioPlayer audioPlayer = AudioPlayer();

  double _position = 0;
  double _maxDuration = 1;
  bool _isPlaying = false;

  var lyricModel = LyricsModelBuilder.create().bindLyricToMain("").getModel();

  late Future<String> normalLyric;
  late StreamSubscription _audioPositionSubscription;
  late StreamSubscription _audioDurationSubscription;

  UINetease lyricUI = UINetease(
      // defaultSize: 22,
      // inlineGap: 20,
      // lineGap: 20,
      // lyricAlign: LyricAlign.CENTER,
      // otherMainSize: 16,
      );

  // List<Lyric> lyrics = [];

  @override
  void initState() {
    super.initState();
    normalLyric = _fetchAndSetLyrics();

    _audioPositionSubscription =
        audioPlayer.onPositionChanged.listen((Duration duration) {
      setState(() {
        _position = duration.inMilliseconds.toDouble();
      });
    });
    _audioDurationSubscription =
        audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _maxDuration = duration.inMilliseconds.toDouble();
      });
    });

    audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _position = 0;
        widget.isPlayingNotifier.value = _isPlaying;
      });
    });
  }

  Future<String> _fetchAndSetLyrics() async {
    final lyricsList = await fetchLyrics(
        'https://storage.googleapis.com/ikara-storage/ikara/lyrics.xml');
    final lyricModelString = createLyricModel(lyricsList);
    setState(() {
      lyricModel = LyricsModelBuilder.create()
          .bindLyricToMain(lyricModelString)
          .getModel();
      // lyrics = lyricsList.expand((element) => element).toList();
    });
    return lyricModelString;
  }

  void _playPauseAudio() {
    if (_isPlaying) {
      audioPlayer.pause();
    } else {
      audioPlayer.play(UrlSource(
          'https://storage.googleapis.com/ikara-storage/tmp/beat.mp3'));
    }
    setState(() {
      _isPlaying = !_isPlaying;
      widget.isPlayingNotifier.value = _isPlaying;
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    _audioPositionSubscription.cancel();
    _audioDurationSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: FutureBuilder<String>(
        future: normalLyric,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
              color: Colors.white,
            ));
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading lyrics'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No lyrics available'));
          } else {
            return buildContainer(snapshot.data!);
          }
        },
      ),
    );
  }

  Widget buildContainer(String normalLyric) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [buildReaderWidget(normalLyric), buildPlayControl()],
    );
  }

  Widget buildReaderWidget(String normalLyric) {
    // int? timeStart = (lyrics.first.timestamp * 1000).toInt();
    // int? timeLine = 0;
    // if (_position.toInt() >= timeStart) {
    //   timeLine = _position.toInt();
    // } else {
    //   timeLine =_maxDuration.toInt() - _position.toInt();
    // }


    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 300,
      child: LyricsReader(
        model: lyricModel,
        position: _position.toInt(),
        playing: _isPlaying,
        size: Size(double.infinity, MediaQuery.of(context).size.height / 2),
        lyricUi: lyricUI,
        emptyBuilder: () => const Center(
          child: Text(
            "Không có lời bài hát",
          ),
        ),
      ),
    );
  }

  Widget buildPlayControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: _playPauseAudio,
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 10),
            child: Text(
              '${_formatMinDuration(Duration(milliseconds: _position.toInt()))} / ${_formatMinDuration(Duration(milliseconds: _maxDuration.toInt()))}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: Slider(
                min: 0,
                max: _maxDuration,
                label: _position.toString(),
                value: _position,
                activeColor: Colors.blueGrey,
                inactiveColor: Colors.blue,
                onChanged: (double value) {
                  setState(() {
                    _position = value;
                  });
                  audioPlayer.seek(Duration(milliseconds: value.toInt()));
                }),
          )
        ],
      ),
    );
  }
}
