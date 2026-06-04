import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

class Common {
  Common._();

  static void dismissKeyboard() => Get.focusScope!.unfocus();

  static void quickToast({
    ToastificationType type = ToastificationType.success,
    ToastificationStyle style = ToastificationStyle.flat,
    required String title,
    String? description,
    Icon? icon,
    Color? primaryColor,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    toastification.show(
      type: type,
      style: style,
      autoCloseDuration: const Duration(seconds: 5),
      title: Text(title),
      description: description != null ? Text(description) : null,
      alignment: Alignment.topRight,
      animationDuration: const Duration(milliseconds: 300),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// Parse error message from PocketBase ClientException for user-friendly display
  static String parsePocketBaseError(ClientException e) {
    if (e.response.containsKey('data')) {
      final data = e.response['data'] as Map<String, dynamic>?;
      if (data != null) {
        // Handle field-specific errors
        final errors = <String>[];
        data.forEach((field, error) {
          if (error is Map && error.containsKey('message')) {
            errors.add('$field: ${error['message']}');
          } else if (error is String) {
            errors.add('$field: $error');
          }
        });
        if (errors.isNotEmpty) {
          return errors.join('\n');
        }
      }
    }
    
    if (e.response.containsKey('message')) {
      return e.response['message'].toString();
    }
    
    return 'An error occurred. Please try again.';
  }

  /// Make a phone call
  static Future<void> makeCall(String phoneNumber, {String? contactName}) async {
    try {
      final Uri phoneUri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );
      
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        quickToast(
          type: ToastificationType.error,
          title: 'Unable to make call',
          description: 'Phone app is not available on this device',
        );
      }
    } catch (e) {
      quickToast(
        type: ToastificationType.error,
        title: 'Call failed',
        description: 'Failed to initiate call: $e',
      );
    }
  }

  /// Send an email
  static Future<void> sendEmail(
    String email, {
    String? subject,
    String? body,
    String? contactName,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (subject != null) queryParams['subject'] = subject;
      if (body != null) queryParams['body'] = body;
      
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: queryParams.isNotEmpty 
          ? queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')
          : null,
      );
      
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        quickToast(
          type: ToastificationType.error,
          title: 'Unable to send email',
          description: 'Email app is not available on this device',
        );
      }
    } catch (e) {
      quickToast(
        type: ToastificationType.error,
        title: 'Email failed',
        description: 'Failed to open email app: $e',
      );
    }
  }
}
