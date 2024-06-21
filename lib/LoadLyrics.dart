import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:flutter/animation.dart';

class Word {
  final double time;
  final String text;

  Word({required this.time, required this.text});
}

class Line {
  final double startTime;
  final double endTime;
  final List<Word> words;

  Line({required this.startTime, required this.endTime, required this.words});
}

Future<List<Line>> getLyrics(String url) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    // chuyển từ định dạng byte sang utf-8
    final document = xml.XmlDocument.parse(utf8.decode(response.bodyBytes));
    final data = <Line>[];

    for (final param in document.findAllElements('param')) {
      final words = <Word>[];
      // thời gian bắt đầu và kết thúc của câu
      double? startTime;
      double? endTime;

      for (final item in param.findAllElements('i')) {
        final text = item.text;
        // thời gian của từ
        final timeStamp = double.parse(item.getAttribute('va')!) * 1000;

        // nếu như startTime = null thì startTime = timeStamp
        // nếu startTime đã có giá trị thì giữ nguyên
        startTime ??= timeStamp;

        // endTime luôn cập nhật
        endTime = timeStamp;

        words.add(Word(time: timeStamp, text: text));
      }

      if (startTime != null && endTime != null) {
        data.add(Line(startTime: startTime, endTime: endTime, words: words));
      }
    }

    // cập nhật endTime của mỗi câu
    for (int i = 0; i < data.length - 1; i++) {
      if (data[i + 1].startTime - data[i].endTime > 1000) {
        data[i] = Line(
            startTime: data[i].startTime,
            endTime: data[i].endTime + 500,
            words: data[i].words);
      }
    }

    return data;
  } else {
    throw Exception('không thể tải lời bài hát.');
  }
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

class _LoadLyricsState extends State<LoadLyrics> with TickerProviderStateMixin {
  final AudioPlayer audioPlayer = AudioPlayer();
  double _currentPosition = 0;
  double _maxDuration = 1;
  bool _isPlaying = false;
  int _currentLineIndex = 0;
  double wordDuration = 1;
  double nextStartTime = 0;

  late StreamSubscription _audioPositionSubscription;
  late StreamSubscription _audioDurationSubscription;

  List<Line> data = [];
  late Future<List<Line>> lyricsFuture;

  @override
  void initState() {
    super.initState();
    lyricsFuture = _getAndSet();

    _audioPositionSubscription =
        audioPlayer.onPositionChanged.listen((Duration duration) {
      setState(() {
        _currentPosition = duration.inMilliseconds.toDouble();
        _updateCurrentLine();
      });
    });
    _audioDurationSubscription =
        audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _maxDuration = duration.inMilliseconds.toDouble();
      });
    });

    // Khởi tạo AudioPlayer và kiểm tra duration ngay khi tải xong
    audioPlayer
        .setSourceUrl(
            'https://storage.googleapis.com/ikara-storage/tmp/beat.mp3')
        .then((_) {
      audioPlayer.getDuration().then((duration) {
        setState(() {
          _maxDuration = duration!.inMilliseconds.toDouble();
        });
      });
    });

    audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        widget.isPlayingNotifier.value = _isPlaying;
      });
    });
  }

  // cập nhật vị trí dòng hiện tại
  void _updateCurrentLine() {
    int closestIndex = 0; // Biến lưu trữ chỉ số dòng gần nhất
    double closestDistance =
        double.infinity; // Biến lưu trữ khoảng cách nhỏ nhất

    for (int i = 0; i < data.length; i++) {
      double startTime = data[i].startTime;
      double endTime = data[i].endTime;

      // Tính khoảng cách giữa vị trí hiện tại và thời gian bắt đầu và kết thúc của dòng
      double distance = (_currentPosition < startTime)
          ? (startTime - _currentPosition)
          : (_currentPosition > endTime)
              ? (_currentPosition - endTime)
              : 0;

      // Kiểm tra nếu khoảng cách này nhỏ hơn khoảng cách gần nhất được lưu trữ
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }

      // Nếu vị trí hiện tại nằm trong khoảng thời gian của dòng lời bài hát
      if (_currentPosition >= startTime && _currentPosition <= endTime) {
        setState(() {
          _currentLineIndex = i;
        });
        return; // Trả về vì đã tìm thấy dòng phù hợp
      }
    }

    // Nếu không tìm thấy dòng phù hợp, cập nhật dòng gần nhất
    setState(() {
      _currentLineIndex = closestIndex;
    });
  }

  Future<List<Line>> _getAndSet() async {
    final list = await getLyrics(
        'https://storage.googleapis.com/ikara-storage/ikara/lyrics.xml');
    setState(() {
      data = list;
    });
    return list;
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
      backgroundColor: const Color(0xFF34224F),
      body: FutureBuilder<List<Line>>(
        future: lyricsFuture,
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

  Widget buildContainer(List<Line> lyrics) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [buildReaderWidget(), buildPlayControl()],
    );
  }

  Widget buildReaderWidget() {
    int currentLineIndex = _currentLineIndex; // Chỉ số của câu đang phát
    int nextLineIndex = (currentLineIndex + 1); // Chỉ số của câu sắp tới

    // danh sách các widget hiển thị các dòng văn bản
    List<Widget> linesWidgets = [];

    // Hàm để tạo TextSpan cho từng ký tự
    TextSpan buildTextSpan(Line line) {

      // ds chứa các textSpan đại diện cho từng ký tự của dòng văn bản
      List<TextSpan> spans = [];

      for (int i = 0; i < line.words.length; i++) {
        final word = line.words[i];
        final wordStartTime = word.time;
        final wordEndTime =
            i < line.words.length - 1 ? line.words[i + 1].time : line.endTime;
        wordDuration = wordEndTime - wordStartTime;

        for (int j = 0; j < word.text.length; j++) {
          final charTimeStart =
              wordStartTime + j * (wordDuration / word.text.length);

          // Tính toán tiến độ dựa trên thời gian hiện tại và thời gian bắt đầu của ký tự chia cho thời gian kéo dài của từ
          double progress = (_currentPosition - charTimeStart) / wordDuration;

          // Giới hạn tiến độ từ 0 đến 1 để tránh giá trị ngoài khoảng
          progress = progress.clamp(0.0, 1.0);

          // Sử dụng Color.lerp để chuyển màu từ trắng sang xanh lam dựa trên tiến độ
          Color charColor =
              Color.lerp(Colors.white, Colors.yellowAccent, progress)!;

          spans.add(TextSpan(
            text: word.text[j],
            style: TextStyle(
              color: charColor, // Áp dụng màu từ Tween
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ));
        }
      }
      return TextSpan(children: spans);
    }

    // Câu đang phát
    if (currentLineIndex < data.length) {
      linesWidgets.add(
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: 1.0,
          child: RichText(
            text: buildTextSpan(data[currentLineIndex]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Thêm khoảng cách giữa các câu
    linesWidgets.add(const SizedBox(height: 20));

    // Câu sắp tới
    if (nextLineIndex < data.length) {
      linesWidgets.add(
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: 0.5,
          child: RichText(
            text: buildTextSpan(data[nextLineIndex]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      height: 300,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: linesWidgets,
      ),
    );
  }

  Widget buildPlayControl() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
              '${_formatMinDuration(Duration(milliseconds: _currentPosition.toInt()))} / ${_formatMinDuration(Duration(milliseconds: _maxDuration.toInt()))}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: Slider(
                min: 0,
                max: _maxDuration,
                label: _currentPosition.toString(),
                value: _currentPosition,
                activeColor: Colors.white,
                inactiveColor: Colors.grey,
                onChanged: (double value) {
                  setState(() {
                    _currentPosition = value;
                  });
                  audioPlayer.seek(Duration(milliseconds: value.toInt()));
                }),
          )
        ],
      ),
    );
  }
}
