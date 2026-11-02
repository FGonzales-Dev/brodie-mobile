import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/utils/validators.dart';

class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.controller, this.textInputAction, this.autofocus = false});

  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return BrodieTextField(
      controller: controller,
      label: 'Email',
      icon: Icons.mail_outline,
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction,
      autofocus: autofocus,
      validator: Validators.email,
    );
  }
}
