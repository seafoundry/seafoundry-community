import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/cards.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, required this.message, this.stackTrace, this.json});

  final String message;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? json;

  @override
  Widget build(BuildContext context) {
    // print('ErrorScreen: $message');
    return Scaffold(
      backgroundColor: UI.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: UI.screenPaddingAll,
          child: Column(
            children: [
              UI.spacingVerticalXl,
              // Error icon
              UI.roundedIcon(
                Icons.error_outline,
                size: UI.iconSizeXl,
                backgroundColor: UI.errorColor.withValues(alpha: 0.1),
                iconColor: UI.errorColor,
              ),
              UI.spacingVerticalLg,
              // Error title
              UIText.h2('Something went wrong', textAlign: TextAlign.center),
              UI.spacingVerticalMd,
              // Error message
              UIText.bodyMedium(message, textAlign: TextAlign.center, color: UI.textSecondaryColor),
              UI.spacingVerticalXl,
              // Error details in cards
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (stackTrace != null) ...[
                        _buildDetailCard(title: 'Stack Trace', content: stackTrace.toString(), icon: Icons.code),
                        UI.spacingVerticalMd,
                      ],
                      if (json != null) ...[
                        _buildDetailCard(title: 'Error Details', content: _formatJson(json!), icon: Icons.data_object),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    try {
      // Try to format the JSON nicely
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      // Fallback to toString if JSON encoding fails
      return json.toString();
    }
  }

  Widget _buildDetailCard({required String title, required String content, required IconData icon}) {
    return AppCards.basic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UI.iconSmall(icon, color: UI.textSecondaryColor),
              UI.spacingHorizontalSm,
              UIText.h6(title),
            ],
          ),
          UI.spacingVerticalSm,
          Container(
            width: double.infinity,
            padding: UI.paddingMd,
            decoration: UI.roundedBox(color: UI.backgroundColor, borderRadius: UI.borderRadiusSm),
            child: UIText.bodyXSmall(content, color: UI.textSecondaryColor),
          ),
        ],
      ),
    );
  }
}
