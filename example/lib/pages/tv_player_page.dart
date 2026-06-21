import 'package:better_player_example/constants.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Example page demonstrating TV controls for Android TV, Fire TV, Apple TV.
/// Use D-pad or arrow keys to navigate, Enter/Select to activate buttons.
class TvPlayerPage extends StatefulWidget {
  const TvPlayerPage({super.key});

  @override
  State<TvPlayerPage> createState() => _TvPlayerPageState();
}

class _TvPlayerPageState extends State<TvPlayerPage> {
  late BetterPlayerController _betterPlayerController;
  late BetterPlayerDataSource _betterPlayerDataSource;

  @override
  void initState() {
    super.initState();

    // Force landscape orientation for TV
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Hide system UI for immersive TV experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // TV-optimized configuration
    final betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: true,
      expandToFill: true,
      deviceOrientationsOnFullScreen: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      controlsConfiguration: BetterPlayerControlsConfiguration.tv(
        focusColor: Colors.blue,
        iconsColor: Colors.white,
      ),
    );

    _betterPlayerDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.forBiggerBlazesUrl,
    );

    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(_betterPlayerDataSource);
  }

  @override
  void dispose() {
    // Restore default orientations
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _betterPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: BetterPlayer(controller: _betterPlayerController),
    ),
  );
}
