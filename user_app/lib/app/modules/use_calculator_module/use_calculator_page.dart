import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/modules/use_calculator_module/use_calculator_controller.dart';
import '../../utils/loading.dart';
import '../../widgets/app_button.dart';

class UseCalculatorPage extends GetWidget<UseCalculatorController> {
  const UseCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.calculator?.name ?? 'Calculator'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: controller.refreshWebView,
          ),
        ],
      ),
      body: Obx(() {
        // Show error state
        if (controller.hasError.value) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.triangleAlert,
                    size: 64,
                    color: context.theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to Load Calculator',
                    style: context.textTheme.headlineSmall?.copyWith(
                      color: context.theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.errorMessage ?? 'Unknown error occurred',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'Retry',
                    icon: LucideIcons.refreshCw,
                    onPressed: controller.retry,
                    width: 200,
                  ),
                ],
              ),
            ),
          );
        }

        // Show loading state
        if (controller.isLoading.value || controller.fileUrl == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Loading.large(),
                SizedBox(height: 16),
                Text('Loading calculator...'),
              ],
            ),
          );
        }

        // Show WebView
        return Stack(
          children: [
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                isInspectable: true,
              ),
              onWebViewCreated: controller.onWebViewCreated,
              onLoadStart: controller.onLoadStart,
              onLoadStop: controller.onLoadStop,
              onConsoleMessage: (webController, consoleMessage) {
                print(
                  'WebView Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}',
                );
              },
              onReceivedError: (webController, request, error) =>
                  controller.onLoadError(
                    webController,
                    request.url,
                    error.type.toNativeValue() ?? 0,
                    error.description,
                  ),
            ),
            // Loading overlay for WebView
            if (!controller.isWebViewReady.value && !controller.hasError.value)
              Container(
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.8),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Loading.large(),
                      SizedBox(height: 16),
                      Text('Loading calculator page...'),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
