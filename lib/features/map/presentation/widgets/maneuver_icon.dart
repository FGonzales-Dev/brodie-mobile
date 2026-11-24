import 'package:flutter/material.dart';

import '../../domain/map_models.dart';

/// Arrow for a Mapbox maneuver type/modifier.
IconData maneuverIcon(RouteManeuver maneuver) {
  final modifier = maneuver.modifier ?? '';
  final towardLeft = modifier.contains('left');
  return switch (maneuver.type) {
    'arrive' => Icons.sports_score,
    'depart' => Icons.navigation,
    'roundabout' ||
    'rotary' ||
    'roundabout turn' ||
    'exit roundabout' ||
    'exit rotary' => towardLeft ? Icons.roundabout_left : Icons.roundabout_right,
    'merge' => Icons.merge,
    'fork' => towardLeft ? Icons.fork_left : Icons.fork_right,
    'on ramp' || 'off ramp' => towardLeft ? Icons.ramp_left : Icons.ramp_right,
    _ => switch (modifier) {
      'uturn' => Icons.u_turn_left,
      'sharp left' => Icons.turn_sharp_left,
      'left' => Icons.turn_left,
      'slight left' => Icons.turn_slight_left,
      'sharp right' => Icons.turn_sharp_right,
      'right' => Icons.turn_right,
      'slight right' => Icons.turn_slight_right,
      _ => Icons.straight,
    },
  };
}
