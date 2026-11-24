import 'package:flutter/material.dart';

import '../../domain/vehicle.dart';

IconData vehicleIcon(VehicleType type) => switch (type) {
      VehicleType.motorcycle => Icons.two_wheeler,
      VehicleType.bike => Icons.pedal_bike,
    };
