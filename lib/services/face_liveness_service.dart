import 'package:face_plugin/face_plugin.dart';

enum LivenessStage {
  neutralStart,
  turnFirst,
  neutralMiddle,
  turnOpposite,
  neutralFinish,
  complete,
}

class LivenessState {
  final LivenessStage stage;
  final String instruction;
  final double progress;

  const LivenessState({
    required this.stage,
    required this.instruction,
    required this.progress,
  });

  bool get isComplete => stage == LivenessStage.complete;
}

class FaceLivenessService {
  static const double neutralYaw = 9;
  static const double turnYaw = 10;
  static const double maxTurnYaw = 38;

  LivenessStage _stage = LivenessStage.neutralStart;
  int _stableCount = 0;
  int? _firstTurnSign;

  LivenessState get state => _stateFor(_stage);

  void reset() {
    _stage = LivenessStage.neutralStart;
    _stableCount = 0;
    _firstTurnSign = null;
  }

  LivenessState update(Face face) {
    if (_stage == LivenessStage.complete) return state;

    final yaw = face.headEulerAngleY;
    final pitch = face.headEulerAngleX.abs();
    final roll = face.headEulerAngleZ.abs();

    if (pitch > 28 || roll > 26) {
      _stableCount = 0;
      return state;
    }

    switch (_stage) {
      case LivenessStage.neutralStart:
      case LivenessStage.neutralMiddle:
      case LivenessStage.neutralFinish:
        if (yaw.abs() <= neutralYaw) {
          _stableCount++;
          if (_stableCount >= 2) _advance();
        } else {
          _stableCount = 0;
        }
        break;
      case LivenessStage.turnFirst:
        if (yaw.abs() >= turnYaw && yaw.abs() <= maxTurnYaw) {
          _firstTurnSign = yaw >= 0 ? 1 : -1;
          _advance();
        }
        break;
      case LivenessStage.turnOpposite:
        final first = _firstTurnSign;
        if (first != null &&
            yaw.abs() >= turnYaw &&
            yaw.abs() <= maxTurnYaw &&
            (yaw >= 0 ? 1 : -1) != first) {
          _advance();
        }
        break;
      case LivenessStage.complete:
        break;
    }
    return state;
  }

  void _advance() {
    _stableCount = 0;
    switch (_stage) {
      case LivenessStage.neutralStart:
        _stage = LivenessStage.turnFirst;
        break;
      case LivenessStage.turnFirst:
        _stage = LivenessStage.neutralMiddle;
        break;
      case LivenessStage.neutralMiddle:
        _stage = LivenessStage.turnOpposite;
        break;
      case LivenessStage.turnOpposite:
        _stage = LivenessStage.neutralFinish;
        break;
      case LivenessStage.neutralFinish:
        _stage = LivenessStage.complete;
        break;
      case LivenessStage.complete:
        break;
    }
  }

  LivenessState _stateFor(LivenessStage stage) {
    switch (stage) {
      case LivenessStage.neutralStart:
        return const LivenessState(
          stage: LivenessStage.neutralStart,
          instruction: 'Step 1 of 5 • Look straight at the camera',
          progress: 0.10,
        );
      case LivenessStage.turnFirst:
        return const LivenessState(
          stage: LivenessStage.turnFirst,
          instruction:
              'Step 2 of 5 • Turn your FACE to either side — do not tilt your head',
          progress: 0.30,
        );
      case LivenessStage.neutralMiddle:
        return const LivenessState(
          stage: LivenessStage.neutralMiddle,
          instruction: 'Step 3 of 5 • Return to the center',
          progress: 0.50,
        );
      case LivenessStage.turnOpposite:
        return const LivenessState(
          stage: LivenessStage.turnOpposite,
          instruction: 'Step 4 of 5 • Turn your FACE to the opposite side',
          progress: 0.70,
        );
      case LivenessStage.neutralFinish:
        return const LivenessState(
          stage: LivenessStage.neutralFinish,
          instruction: 'Step 5 of 5 • Return to the center and hold still',
          progress: 0.90,
        );
      case LivenessStage.complete:
        return const LivenessState(
          stage: LivenessStage.complete,
          instruction: 'Live face confirmed',
          progress: 1.0,
        );
    }
  }
}
