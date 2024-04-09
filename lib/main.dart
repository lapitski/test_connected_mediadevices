import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:developer' as dev;
import 'package:rxdart/rxdart.dart';
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _player = AudioPlayer();
  late AudioSession session;
  String devicesString = '';

  @override
  void initState() {
    navigator.mediaDevices.getUserMedia({'audio': true});
    super.initState();
    ambiguate(WidgetsBinding.instance)!.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
    ));
    _init();
  }

  Future<void> _init() async {
    // Inform the operating system of our app's audio attributes etc.
    // We pick a reasonable default for an app that plays speech.
    session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // await session.configure(const AudioSessionConfiguration(
    //   avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
    //   avAudioSessionCategoryOptions:
    //       AVAudioSessionCategoryOptions.allowBluetooth,
    //   avAudioSessionMode: AVAudioSessionMode.spokenAudio,
    //   avAudioSessionRouteSharingPolicy:
    //       AVAudioSessionRouteSharingPolicy.defaultPolicy,
    //   avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    //   androidAudioAttributes: AndroidAudioAttributes(
    //     contentType: AndroidAudioContentType.speech,
    //     flags: AndroidAudioFlags.none,
    //     usage: AndroidAudioUsage.voiceCommunication,
    //   ),
    //   androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    //   androidWillPauseWhenDucked: true,
    // ));
    // subToInterruptionEventStream();
   // subDevicesChangedEventStream();
    // subBecomingNoisyEventStream();
    navigator.mediaDevices.ondevicechange = onDeviceChange;

    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print('A stream error occurred: $e');
    });
    // Try to load audio from a source and catch any errors.
    try {
      // AAC example: https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aac
      await _player.setAudioSource(
          AudioSource.uri(Uri.parse('asset:///assets/demo.mp3')));
    } on PlayerException catch (e) {
      print("Error loading audio source: $e");
    }
  }

  deviceFromWebRtc() async {
    devicesString = '';
    dev.log('deviceFromWebRtc:', level: 1);
    final devices = await navigator.mediaDevices.enumerateDevices();

    devices.forEach((element) {
      dev.log(
          '${element.deviceId}, ${element.groupId},  ${element.kind}, ${element.label}');
      devicesString +=
          '${element.deviceId}, ${element.groupId},  ${element.kind}, ${element.label} \n';
      if (element.label.contains('Headphones')) {
        print(element.deviceId);
      }
    });
    setState(() {});
  }

  getUserMedia() async {
    final res = await navigator.mediaDevices. getUserMedia({'audio': true});
    final r = res. getAudioTracks();
    print(r);
    print(res.id);
  }

  onDeviceChange(value) async {
    dev.log('From Webrts on device change, value: $value');
    await deviceFromWebRtc();
  }

  subToInterruptionEventStream() {
    session.interruptionEventStream.listen((event) {
      dev.log('isBegin ${event.begin} ${event.type}');
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            break;
          case AudioInterruptionType.pause:
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });
  }

  subDevicesChangedEventStream() {
   
    session.devicesChangedEventStream.listen((event) {
      if (event.devicesAdded.isNotEmpty) {
        dev.log('From audio_session. Devices added:   ${event.devicesAdded}');
      } else if (event.devicesRemoved.isNotEmpty) {
        dev.log('From audio_session. Devices removed: ${event.devicesRemoved}');
      }
      dev.log('From audio_session - empty device list');
    });
  }

  subBecomingNoisyEventStream() {
    session.becomingNoisyEventStream.listen((_) {
      dev.log('becomingNoisyEventStream');
    });
  }

  setSessionActive() async {
    if (await session.setActive(true)) {
      dev.log('setSessionActive success');
    } else {
      dev.log('setSessionActive failed');
    }
  }

  getDevicesFromAudiosession() async {
    devicesString = '';
    final devices = await session.getDevices();
    dev.log('from Audio session');
    devices.forEach(
      (element) {
        dev.log(
            'id: ${element.id},  ${element.name}, ${element.type}, isInput: ${element.isInput}, isOutput: ${element.isOutput}');
        devicesString +=
            'id: ${element.id},  ${element.name}, ${element.type}, isInput: ${element.isInput}, isOutput: ${element.isOutput} \n';
      },
    );
    setState(() {});
  }

  @override
  void dispose() {
    ambiguate(WidgetsBinding.instance)!.removeObserver(this);
    // Release decoders and buffers back to the operating system making them
    // available for other apps to use.
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Release the player's resources when not in use. We use "stop" so that
      // if the app resumes later, it will still remember what position to
      // resume from.
      _player.stop();
    }
  }

  /// Collects the data useful for displaying in a seek bar, using a handy
  /// feature of rx_dart to combine the 3 streams of interest into one.
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    onPressed: () {
                      Helper.setSpeakerphoneOn(false);
                    },
                    child: Text('setSpeakerphone OFF')),
                ElevatedButton(
                    onPressed: () {
                      Helper.setSpeakerphoneOn(true);
                    },
                    child: Text('setSpeakerphone ON')),
                ElevatedButton(
                    onPressed: () {
                      Helper.selectAudioOutput(
                          '558b47b2be1938a278fb7dd6c415dc55da6d325d24c5cbafdb5bda1d39454aae');
                    },
                    child: Text('select headset')),
                ElevatedButton(
                    onPressed: () {
                      deviceFromWebRtc();
                    },
                    child: Text('deviceFromWebRtc')),

                ElevatedButton(
                    onPressed: () {
                      getDevicesFromAudiosession();
                    },
                    child: Text('getDevicesFromAudioSession')),

                ElevatedButton(
                    onPressed: () {
                      final constr =
                          navigator.mediaDevices.getSupportedConstraints();
                      dev.log(constr.toString());
                    },
                    child: Text('getSupportedConstraints')),

                ElevatedButton(
                    onPressed: () {
                      getUserMedia();
                    },
                    child: Text('getUserMedia')),
                // Display play/pause button and volume/speed sliders.
                ControlButtons(_player),
                // Display seek bar. Using StreamBuilder, this widget rebuilds
                // each time the position, buffered position or duration changes.
                StreamBuilder<PositionData>(
                  stream: _positionDataStream,
                  builder: (context, snapshot) {
                    final positionData = snapshot.data;
                    return SeekBar(
                      duration: positionData?.duration ?? Duration.zero,
                      position: positionData?.position ?? Duration.zero,
                      bufferedPosition:
                          positionData?.bufferedPosition ?? Duration.zero,
                      onChangeEnd: _player.seek,
                    );
                  },
                ),
                const SizedBox(height: 16.0),
                const Text('Current devices'),
                const SizedBox(height: 8.0),
                Text(devicesString),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays the play/pause button and volume/speed sliders.
class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Opens volume slider dialog
        IconButton(
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),

        /// This StreamBuilder rebuilds whenever the player state changes, which
        /// includes the playing/paused state and also the
        /// loading/buffering/ready state. Depending on the state we show the
        /// appropriate button or loading indicator.
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: const CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return IconButton(
                icon: const Icon(Icons.play_arrow),
                iconSize: 64.0,
                onPressed: player.play,
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: const Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero),
              );
            }
          },
        ),
        // Opens speed slider dialog
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                value: player.speed,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
      ],
    );
  }
}

class SeekBar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final ValueChanged<Duration>? onChanged;
  final ValueChanged<Duration>? onChangeEnd;

  const SeekBar({
    Key? key,
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    this.onChanged,
    this.onChangeEnd,
  }) : super(key: key);

  @override
  SeekBarState createState() => SeekBarState();
}

class SeekBarState extends State<SeekBar> {
  double? _dragValue;
  late SliderThemeData _sliderThemeData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _sliderThemeData = SliderTheme.of(context).copyWith(
      trackHeight: 2.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SliderTheme(
          data: _sliderThemeData.copyWith(
            thumbShape: HiddenThumbComponentShape(),
            activeTrackColor: Colors.blue.shade100,
            inactiveTrackColor: Colors.grey.shade300,
          ),
          child: ExcludeSemantics(
            child: Slider(
              min: 0.0,
              max: widget.duration.inMilliseconds.toDouble(),
              value: min(widget.bufferedPosition.inMilliseconds.toDouble(),
                  widget.duration.inMilliseconds.toDouble()),
              onChanged: (value) {
                setState(() {
                  _dragValue = value;
                });
                if (widget.onChanged != null) {
                  widget.onChanged!(Duration(milliseconds: value.round()));
                }
              },
              onChangeEnd: (value) {
                if (widget.onChangeEnd != null) {
                  widget.onChangeEnd!(Duration(milliseconds: value.round()));
                }
                _dragValue = null;
              },
            ),
          ),
        ),
        SliderTheme(
          data: _sliderThemeData.copyWith(
            inactiveTrackColor: Colors.transparent,
          ),
          child: Slider(
            min: 0.0,
            max: widget.duration.inMilliseconds.toDouble(),
            value: min(_dragValue ?? widget.position.inMilliseconds.toDouble(),
                widget.duration.inMilliseconds.toDouble()),
            onChanged: (value) {
              setState(() {
                _dragValue = value;
              });
              if (widget.onChanged != null) {
                widget.onChanged!(Duration(milliseconds: value.round()));
              }
            },
            onChangeEnd: (value) {
              if (widget.onChangeEnd != null) {
                widget.onChangeEnd!(Duration(milliseconds: value.round()));
              }
              _dragValue = null;
            },
          ),
        ),
        Positioned(
          right: 16.0,
          bottom: 0.0,
          child: Text(
              RegExp(r'((^0*[1-9]\d*:)?\d{2}:\d{2})\.\d+$')
                      .firstMatch("$_remaining")
                      ?.group(1) ??
                  '$_remaining',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Duration get _remaining => widget.duration - widget.position;
}

class HiddenThumbComponentShape extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.zero;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {}
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

void showSliderDialog({
  required BuildContext context,
  required String title,
  required int divisions,
  required double min,
  required double max,
  String valueSuffix = '',
  // TODO: Replace these two by ValueStream.
  required double value,
  required Stream<double> stream,
  required ValueChanged<double> onChanged,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: StreamBuilder<double>(
        stream: stream,
        builder: (context, snapshot) => SizedBox(
          height: 100.0,
          child: Column(
            children: [
              Text('${snapshot.data?.toStringAsFixed(1)}$valueSuffix',
                  style: const TextStyle(
                      fontFamily: 'Fixed',
                      fontWeight: FontWeight.bold,
                      fontSize: 24.0)),
              Slider(
                divisions: divisions,
                min: min,
                max: max,
                value: snapshot.data ?? value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

T? ambiguate<T>(T? value) => value;


// import 'dart:developer';

// import 'package:audio_session/audio_session.dart';
// import 'package:flutter/material.dart';
// import 'package:just_audio/just_audio.dart';

// void main() {
//   runApp(const MainApp());
// }

// class MainApp extends StatelessWidget {
//   const MainApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(home: MediaDevicesScreen());
//   }
// }

// class MediaDevicesScreen extends StatefulWidget {
//   const MediaDevicesScreen({super.key});

//   @override
//   State<MediaDevicesScreen> createState() => _MediaDevicesScreenState();
// }

// class _MediaDevicesScreenState extends State<MediaDevicesScreen> {
//   late AudioSession session;
//   final player = AudioPlayer();
//   @override
//   void initState() {
//     super.initState();
//     initAudioSession();
//   }

//   initAudioSession() async {
//     session = await AudioSession.instance;
//     await session.configure(
//       const AudioSessionConfiguration.music(),
//     );
//     // subToInterruptionEventStream();
//     // subDevicesChangedEventStream();
//     // subBecomingNoisyEventStream();

//     try {
//       // AAC example: https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aac
//       // await player.setAudioSource(AudioSource.uri(Uri.parse('asset:///assets/demo.mp3')));
//     } on PlayerException catch (e) {
//       print("Error loading audio source: $e");
//     }
//   }

//   subToInterruptionEventStream() {
//     session.interruptionEventStream.listen((event) {
//       log('isBegin ${event.begin} ${event.type}');
//       if (event.begin) {
//         switch (event.type) {
//           case AudioInterruptionType.duck:
//             break;
//           case AudioInterruptionType.pause:
//             break;
//           case AudioInterruptionType.unknown:
//             break;
//         }
//       } else {
//         switch (event.type) {
//           case AudioInterruptionType.duck:
//             break;
//           case AudioInterruptionType.pause:
//           case AudioInterruptionType.unknown:
//             break;
//         }
//       }
//     });
//   }

//   subDevicesChangedEventStream() {
//     session.devicesChangedEventStream.listen((event) {
//       log('Devices added:   ${event.devicesAdded}');
//       log('Devices removed: ${event.devicesRemoved}');
//     });
//   }

//   subBecomingNoisyEventStream() {
//     session.becomingNoisyEventStream.listen((_) {
//       log('becomingNoisyEventStream');
//     });
//   }

//   setSessionActive() async {
//     if (await session.setActive(true)) {
//       log('setSessionActive success');
//     } else {
//       log('setSessionActive failed');
//     }
//   }

//   getDevices() async {
//     final devices = await session.getDevices();
//     devices.forEach(
//       (element) {
//         log('getDevices : device : ${element.name}, ${element.type}, isInput: ${element.isInput}, isOutput: ${element.isOutput}');
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
   
//     return SafeArea(
//       child: Scaffold(
//         body: Center(
//           child: Column(
//             children: [
//               ElevatedButton(
//                 onPressed: () {
//                   setSessionActive();
//                 },
//                 child: const Text('setSessionActive'),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   getDevices();
//                 },
//                 child: const Text('getDevices'),
//               ),
//               const SizedBox(height: 16.0),
//               const Text('Test player below:'),
//               const SizedBox(
//                 height: 8.0,
//               ),
//               Row(
//                 mainAxisSize: MainAxisSize.max,
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   IconButton(
//                       onPressed: () async {
//                          await player.setAudioSource(AudioSource.uri(Uri.parse('asset:///assets/demo.mp3')));
//                          player.play();
//                         // if (player.playing) {
//                         //   await player.play();
//                         // } else {
//                         //   await player.pause();
//                         // }
//                       },
//                       icon: player.playing
//                           ? Icon(Icons.pause)
//                           : Icon(Icons.play_arrow)),
//                   IconButton(
//                       onPressed: () {
//                         player.stop();
//                       },
//                       icon: Icon(Icons.stop))
//                 ],
//               )
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
