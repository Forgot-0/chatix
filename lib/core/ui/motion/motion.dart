/// The app's motion system: how long things take, how they get there, and
/// what any of it becomes when the reader has asked for less movement.
///
/// The durations and curves themselves are tokens ([AppMotion]); this
/// library is what widgets reach for. Nothing under `lib/` should write a
/// `Duration(milliseconds: …)` of its own for an animation.
library;

export 'package:chatix/core/ui/motion/app_transitions.dart';
export 'package:chatix/core/ui/motion/hero_flight.dart';
export 'package:chatix/core/ui/motion/motion_spring.dart';
export 'package:chatix/core/ui/motion/reduced_motion.dart';
