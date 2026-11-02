import 'package:flutter/material.dart';

/// Themed [TextFormField] with the options screens actually use.
class BrodieTextField extends StatelessWidget {
  const BrodieTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.icon,
    this.suffix,
    this.helperText,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final Widget? suffix;
  final String? helperText;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: suffix,
        helperText: helperText,
        errorText: errorText,
      ),
    );
  }
}

/// Password field with a show/hide toggle; shared by sign-in and sign-up.
class BrodiePasswordField extends StatefulWidget {
  const BrodiePasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<BrodiePasswordField> createState() => _BrodiePasswordFieldState();
}

class _BrodiePasswordFieldState extends State<BrodiePasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return BrodieTextField(
      controller: widget.controller,
      label: widget.label,
      icon: Icons.lock_outline,
      obscureText: _obscured,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      // Kept out of focus traversal so the keyboard's "next" action moves to
      // the following field instead of landing on this toggle.
      suffix: ExcludeFocus(
        child: IconButton(
          tooltip: _obscured ? 'Show password' : 'Hide password',
          icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
