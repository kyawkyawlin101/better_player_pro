import 'dart:async';
import 'package:better_player_plus/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player_plus/src/controls/better_player_controls_state.dart';
import 'package:better_player_plus/src/core/better_player_controller.dart';
import 'package:better_player_plus/src/core/better_player_utils.dart';
import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV-optimized controls for Android TV, Fire TV, Apple TV, and other TV platforms.
/// Provides D-pad navigation support and focus management for remote control usage.
class BetterPlayerTvControls extends StatefulWidget {
  const BetterPlayerTvControls({
    super.key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
  });

  final void Function(bool visibility) onControlsVisibilityChanged;
  final BetterPlayerControlsConfiguration controlsConfiguration;

  @override
  State<StatefulWidget> createState() => _BetterPlayerTvControlsState();
}

class _BetterPlayerTvControlsState extends BetterPlayerControlsState<BetterPlayerTvControls> {
  VideoPlayerValue? _latestValue;
  Timer? _hideTimer;
  Timer? _initTimer;
  bool _wasLoading = false;
  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription<dynamic>? _controlsVisibilityStreamSubscription;

  // Focus nodes for D-pad navigation
  final FocusNode _mainFocusNode = FocusNode();
  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _skipBackFocusNode = FocusNode();
  final FocusNode _skipForwardFocusNode = FocusNode();
  final FocusNode _settingsFocusNode = FocusNode();
  final FocusNode _fullscreenFocusNode = FocusNode();
  final FocusNode _progressFocusNode = FocusNode();

  int _focusedButtonIndex = 0;
  static const int _totalButtons = 5;

  BetterPlayerControlsConfiguration get _controlsConfiguration => widget.controlsConfiguration;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration => _controlsConfiguration;

  @override
  void initState() {
    super.initState();
    _playPauseFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _dispose();
    _mainFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _skipBackFocusNode.dispose();
    _skipForwardFocusNode.dispose();
    _settingsFocusNode.dispose();
    _fullscreenFocusNode.dispose();
    _progressFocusNode.dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    _latestValue = _controller!.value;

    if (oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) => buildLTRDirectionality(_buildMainWidget());

  Widget _buildMainWidget() {
    _wasLoading = isLoading(_latestValue);
    if (_latestValue?.hasError ?? false) {
      return ColoredBox(color: Colors.black, child: _buildErrorWidget());
    }

    return Focus(
      focusNode: _mainFocusNode,
      autofocus: true,
      canRequestFocus: true,
      skipTraversal: false,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (hasFocus) {
        if (!hasFocus && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_mainFocusNode.hasFocus) {
              _mainFocusNode.requestFocus();
            }
          });
        }
      },
      child: GestureDetector(
        onTap: () {
          controlsNotVisible ? cancelAndRestartTimer() : changePlayerControlsNotVisible(true);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Invisible hit area that always captures focus for TV remote
            const Positioned.fill(
              child: ColoredBox(color: Colors.transparent),
            ),
            if (_wasLoading) Center(child: _buildLoadingWidget()) else _buildHitArea(),
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
            _buildNextVideoWidget(),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Show controls on any D-pad/remote key press if hidden
    if (controlsNotVisible) {
      // These keys should show controls
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.mediaPlayPause) {
        cancelAndRestartTimer();
        return KeyEventResult.handled;
      }
      // Media keys should work even when controls are hidden
      if (key == LogicalKeyboardKey.mediaRewind) {
        skipBack();
        cancelAndRestartTimer();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaFastForward) {
        skipForward();
        cancelAndRestartTimer();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Handle D-pad and remote control navigation when controls are visible
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      _handleSelectAction();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _handleLeftNavigation();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _handleRightNavigation();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _handleUpNavigation();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _handleDownNavigation();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.space) {
      _onPlayPause();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.mediaRewind) {
      skipBack();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.mediaFastForward) {
      skipForward();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (_betterPlayerController!.isFullScreen) {
        _betterPlayerController!.exitFullScreen();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _handleSelectAction() {
    cancelAndRestartTimer();
    switch (_focusedButtonIndex) {
      case 0:
        skipBack();
      case 1:
        _onPlayPause();
      case 2:
        skipForward();
      case 3:
        onShowMoreClicked();
      case 4:
        _onExpandCollapse();
    }
  }

  void _handleLeftNavigation() {
    cancelAndRestartTimer();
    if (_focusedButtonIndex > 0) {
      setState(() => _focusedButtonIndex--);
    } else {
      // Quick seek backwards when at leftmost button
      skipBack();
    }
  }

  void _handleRightNavigation() {
    cancelAndRestartTimer();
    if (_focusedButtonIndex < _totalButtons - 1) {
      setState(() => _focusedButtonIndex++);
    } else {
      // Quick seek forward when at rightmost button
      skipForward();
    }
  }

  void _handleUpNavigation() {
    // Can be used for additional navigation or volume control
    cancelAndRestartTimer();
  }

  void _handleDownNavigation() {
    // Can be used for additional navigation
    cancelAndRestartTimer();
  }

  Widget _buildErrorWidget() {
    final errorBuilder = _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(context, _betterPlayerController!.videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor, fontSize: 18);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, color: _controlsConfiguration.iconsColor, size: 64),
            const SizedBox(height: 16),
            Text(_betterPlayerController!.translations.generalDefaultError, style: textStyle),
            if (_controlsConfiguration.enableRetry)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _buildTvFocusableButton(
                  onPressed: () => _betterPlayerController!.retryDataSource(),
                  icon: Icons.refresh,
                  label: _betterPlayerController!.translations.generalRetry,
                  isFocused: true,
                ),
              ),
          ],
        ),
      );
    }
  }

  Widget _buildTopBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title or empty space
            const Expanded(child: SizedBox()),
            // Settings and fullscreen buttons
            Row(
              children: [
                if (_controlsConfiguration.enablePip) _buildPipButton(),
                if (_controlsConfiguration.enableOverflowMenu)
                  _buildTvFocusableButton(
                    onPressed: onShowMoreClicked,
                    icon: _controlsConfiguration.overflowMenuIcon,
                    isFocused: _focusedButtonIndex == 3,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipButton() => FutureBuilder<bool>(
    future: betterPlayerController!.isPictureInPictureSupported(),
    builder: (context, snapshot) {
      final bool isPipSupported = snapshot.data ?? false;
      if (isPipSupported && _betterPlayerController!.betterPlayerGlobalKey != null) {
        return _buildTvFocusableButton(
          onPressed: () {
            betterPlayerController!.enablePictureInPicture(betterPlayerController!.betterPlayerGlobalKey!);
          },
          icon: betterPlayerControlsConfiguration.pipMenuIcon,
          isFocused: false,
        );
      }
      return const SizedBox();
    },
  );

  Widget _buildBottomBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            if (!_betterPlayerController!.isLiveStream() && _controlsConfiguration.enableProgressBar)
              _buildProgressBar(),
            const SizedBox(height: 16),
            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_controlsConfiguration.enableSkips)
                  _buildTvFocusableButton(
                    onPressed: skipBack,
                    icon: _controlsConfiguration.skipBackIcon,
                    isFocused: _focusedButtonIndex == 0,
                    size: 48,
                  ),
                const SizedBox(width: 24),
                if (_controlsConfiguration.enablePlayPause)
                  _buildTvFocusableButton(
                    onPressed: _onPlayPause,
                    icon: _controller!.value.isPlaying
                        ? _controlsConfiguration.pauseIcon
                        : _controlsConfiguration.playIcon,
                    isFocused: _focusedButtonIndex == 1,
                    size: 64,
                    isPrimary: true,
                  ),
                const SizedBox(width: 24),
                if (_controlsConfiguration.enableSkips)
                  _buildTvFocusableButton(
                    onPressed: skipForward,
                    icon: _controlsConfiguration.skipForwardIcon,
                    isFocused: _focusedButtonIndex == 2,
                    size: 48,
                  ),
                const SizedBox(width: 48),
                if (_controlsConfiguration.enableOverflowMenu)
                  _buildTvFocusableButton(
                    onPressed: onShowMoreClicked,
                    icon: _controlsConfiguration.overflowMenuIcon,
                    isFocused: _focusedButtonIndex == 3,
                  ),
                const SizedBox(width: 16),
                if (_controlsConfiguration.enableFullscreen)
                  _buildTvFocusableButton(
                    onPressed: _onExpandCollapse,
                    icon: _betterPlayerController!.isFullScreen
                        ? _controlsConfiguration.fullscreenDisableIcon
                        : _controlsConfiguration.fullscreenEnableIcon,
                    isFocused: _focusedButtonIndex == 4,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Time display
            if (!_betterPlayerController!.isLiveStream() && _controlsConfiguration.enableProgressText)
              _buildTimeDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTvFocusableButton({
    required VoidCallback onPressed,
    required IconData icon,
    required bool isFocused,
    double size = 40,
    bool isPrimary = false,
    String? label,
  }) {
    final focusColor = _controlsConfiguration.tvFocusColor;
    final normalColor = _controlsConfiguration.iconsColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFocused
            ? focusColor.withValues(alpha: 0.3)
            : (isPrimary ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
        border: Border.all(
          color: isFocused ? focusColor : Colors.transparent,
          width: isFocused ? 3 : 0,
        ),
        boxShadow: isFocused
            ? [BoxShadow(color: focusColor.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(isPrimary ? 16 : 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isFocused ? focusColor : normalColor,
                  size: size,
                ),
                if (label != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isFocused ? focusColor : normalColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return const SizedBox.expand();
  }

  Widget _buildNextVideoWidget() => StreamBuilder<int?>(
    stream: _betterPlayerController!.nextVideoTimeStream,
    builder: (context, snapshot) {
      final time = snapshot.data;
      if (time != null && time > 0) {
        return Align(
          alignment: Alignment.bottomRight,
          child: AnimatedOpacity(
            opacity: controlsNotVisible ? 0.0 : 1.0,
            duration: _controlsConfiguration.controlsHideTime,
            child: Container(
              margin: const EdgeInsets.only(bottom: 150, right: 24),
              decoration: BoxDecoration(
                color: _controlsConfiguration.controlBarColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _betterPlayerController!.playNextVideo(),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${_betterPlayerController!.translations.controlsNextVideoIn} $time...',
                      style: TextStyle(
                        color: _controlsConfiguration.textColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return const SizedBox();
    },
  );

  Widget _buildProgressBar() => SizedBox(
    height: 24,
    child: SliderTheme(
      data: SliderThemeData(
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: _controlsConfiguration.progressBarPlayedColor,
        inactiveTrackColor: _controlsConfiguration.progressBarBackgroundColor,
        thumbColor: _controlsConfiguration.progressBarHandleColor,
        overlayColor: _controlsConfiguration.progressBarHandleColor.withValues(alpha: 0.3),
      ),
      child: Slider(
        value: _getProgressValue(),
        onChanged: _controlsConfiguration.enableProgressBarDrag ? _onProgressChanged : null,
        onChangeStart: (_) => _hideTimer?.cancel(),
        onChangeEnd: (_) => _startHideTimer(),
      ),
    ),
  );

  double _getProgressValue() {
    if (_latestValue == null || _latestValue!.duration == null) {
      return 0;
    }
    final duration = _latestValue!.duration!.inMilliseconds;
    if (duration == 0) {
      return 0;
    }
    final position = _latestValue!.position.inMilliseconds;
    return (position / duration).clamp(0, 1);
  }

  void _onProgressChanged(double value) {
    if (_latestValue?.duration == null) {
      return;
    }
    final duration = _latestValue!.duration!;
    final position = Duration(milliseconds: (value * duration.inMilliseconds).round());
    _betterPlayerController!.seekTo(position);
    cancelAndRestartTimer();
  }

  Widget _buildTimeDisplay() {
    final position = _latestValue?.position ?? Duration.zero;
    final duration = _latestValue?.duration ?? Duration.zero;

    return Text(
      '${BetterPlayerUtils.formatDuration(position)} / ${BetterPlayerUtils.formatDuration(duration)}',
      style: TextStyle(
        color: _controlsConfiguration.textColor,
        fontSize: 14,
      ),
    );
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();
    changePlayerControlsNotVisible(false);
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);
    _updateState();

    if (_controller!.value.isPlaying || _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }

    _controlsVisibilityStreamSubscription = _betterPlayerController!.controlsVisibilityStream.listen((state) {
      if (controlsNotVisible == !state) {
        return;
      }
      changePlayerControlsNotVisible(!state);
      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _betterPlayerController!.toggleFullScreen();
  }

  void _onPlayPause() {
    bool isFinished = false;
    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();
      if (_controller!.value.initialized) {
        if (isFinished) {
          _betterPlayerController!.seekTo(Duration.zero);
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 5000), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible || isVideoFinished(_controller!.value) || _wasLoading || isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue) && _betterPlayerController?.isLiveStream() == false) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    _betterPlayerController!.setControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return ColoredBox(
        color: _controlsConfiguration.controlBarColor,
        child: _controlsConfiguration.loadingWidget,
      );
    }

    return SizedBox(
      width: 64,
      height: 64,
      child: CircularProgressIndicator(
        strokeWidth: 4,
        valueColor: AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
      ),
    );
  }
}
